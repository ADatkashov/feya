package app.feya.payments;

import app.feya.common.ApiException;
import app.feya.common.AuditService;
import app.feya.common.FeyaProperties;
import app.feya.orders.Actor;
import app.feya.orders.OrderEntity;
import app.feya.orders.OrderRepository;
import app.feya.orders.OrderService;
import app.feya.orders.OrderStatus;
import app.feya.payments.PaymentEventRepository;
import app.feya.payments.PaymentRepository;
import app.feya.payments.RefundRepository;
import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PaymentService {
    private static final Logger log = LoggerFactory.getLogger(PaymentService.class);

    private final PaymentProviders providers;
    private final PaymentRepository payments;
    private final PaymentEventRepository events;
    private final RefundRepository refunds;
    private final OrderRepository orders;
    private final OrderService orderService;
    private final AuditService audit;
    private final FeyaProperties props;

    public PaymentService(PaymentProviders providers, PaymentRepository payments, PaymentEventRepository events,
                          RefundRepository refunds, OrderRepository orders, OrderService orderService,
                          AuditService audit, FeyaProperties props) {
        this.providers = providers;
        this.payments = payments;
        this.events = events;
        this.refunds = refunds;
        this.orders = orders;
        this.orderService = orderService;
        this.audit = audit;
        this.props = props;
    }

    public List<String> methods() {
        return providers.configured() ? props.payments().methods() : List.of();
    }

    /**
     * Starts (or resumes) a payment attempt. Only one PENDING attempt exists per order (unique index), so repeated
     * client calls return the same attempt instead of creating duplicates.
     */
    @Transactional
    public Payment start(UUID userId, UUID orderId, String method) {
        PaymentProvider provider = providers.active();
        if (!props.payments().methods().contains(method)) {
            throw ApiException.badRequest("UNSUPPORTED_PAYMENT_METHOD", "Payment method is not supported");
        }
        OrderEntity order = orders.lockById(orderId).filter(o -> o.getUserId().equals(userId))
                .orElseThrow(() -> ApiException.notFound("Order"));
        if (order.getStatus() != OrderStatus.PENDING_PAYMENT && order.getStatus() != OrderStatus.PAYMENT_FAILED) {
            throw ApiException.conflict("ORDER_NOT_PAYABLE", "This order cannot be paid");
        }
        var pending = payments.findFirstByOrderIdAndStatus(orderId, Payment.Status.PENDING);
        if (pending.isPresent()) {
            return pending.get();
        }
        if (order.getStatus() == OrderStatus.PAYMENT_FAILED) {
            orderService.transition(order, OrderStatus.PENDING_PAYMENT, Actor.SYSTEM, null, "payment retry");
        }
        Payment p = new Payment();
        p.setOrderId(orderId);
        p.setProvider(provider.id());
        p.setMethod(method);
        p.setAmount(order.getTotal());
        p.setCurrency(order.getCurrency());
        p.setSandbox(provider.sandbox());
        PaymentProvider.Session session = provider.createSession(p, "FEYA " + order.getNumber());
        p.setProviderPaymentId(session.providerPaymentId());
        p.setCheckoutUrl(session.checkoutUrl());
        return payments.save(p);
    }

    @Transactional(readOnly = true)
    public Payment getForUser(UUID userId, UUID paymentId) {
        Payment p = payments.findById(paymentId).orElseThrow(() -> ApiException.notFound("Payment"));
        orders.findByIdAndUserId(p.getOrderId(), userId).orElseThrow(() -> ApiException.notFound("Payment"));
        return p;
    }

    /**
     * Entry point for provider callbacks. The signature is verified over the raw body BEFORE anything is parsed or
     * trusted. Events are deduplicated by (provider, eventId), so redelivery is harmless.
     * Payment success is only ever derived from here, never from a client response.
     */
    @Transactional
    public void handleWebhook(String providerId, String rawBody, String signature) {
        PaymentProvider provider = providers.byId(providerId)
                .orElseThrow(() -> ApiException.notFound("Provider"));
        if (!provider.verifySignature(rawBody, signature)) {
            log.warn("Rejected webhook with invalid signature for provider {}", providerId);
            throw ApiException.unauthorized("INVALID_SIGNATURE", "Invalid webhook signature");
        }
        PaymentProvider.ProviderEvent ev = provider.parseEvent(rawBody);
        if (events.existsByProviderAndEventId(provider.id(), ev.eventId())) {
            return; // already processed
        }
        Payment payment = payments.findByProviderAndProviderPaymentId(provider.id(), ev.providerPaymentId()).orElse(null);
        PaymentEvent record = new PaymentEvent();
        record.setProvider(provider.id());
        record.setEventId(ev.eventId());
        record.setType(ev.type().name());
        record.setPayload(rawBody.length() > 4000 ? rawBody.substring(0, 4000) : rawBody);
        record.setPaymentId(payment == null ? null : payment.getId());
        try {
            events.saveAndFlush(record);
        } catch (DataIntegrityViolationException duplicate) {
            return; // concurrent delivery of the same event
        }
        if (payment == null) {
            log.warn("Webhook {} references unknown payment {}", ev.eventId(), ev.providerPaymentId());
            return;
        }
        apply(payment, ev);
    }

    private void apply(Payment payment, PaymentProvider.ProviderEvent ev) {
        OrderEntity order = orders.lockById(payment.getOrderId()).orElseThrow();
        switch (ev.type()) {
            case PAYMENT_SUCCEEDED -> {
                if (payment.getStatus() == Payment.Status.SUCCEEDED) {
                    return;
                }
                if (ev.amount() != null && ev.amount().compareTo(payment.getAmount()) != 0
                        || ev.currency() != null && !ev.currency().equalsIgnoreCase(payment.getCurrency())) {
                    payment.setStatus(Payment.Status.FAILED);
                    payment.setFailureReason("AMOUNT_MISMATCH");
                    audit.record(null, "SYSTEM", "PAYMENT_AMOUNT_MISMATCH", "PAYMENT", payment.getId(), null);
                    markOrderFailed(order);
                    return;
                }
                payment.setStatus(Payment.Status.SUCCEEDED);
                if (order.getStatus() == OrderStatus.PENDING_PAYMENT || order.getStatus() == OrderStatus.PAYMENT_FAILED) {
                    orderService.transition(order, OrderStatus.PAID, Actor.SYSTEM, null, null);
                } else if (order.getStatus() == OrderStatus.CANCELLED) {
                    // Money arrived after the order was cancelled/expired: give it back.
                    requestRefund(payment, payment.getAmount(), "payment received after cancellation", null);
                }
            }
            case PAYMENT_FAILED -> {
                if (payment.getStatus() != Payment.Status.PENDING) {
                    return;
                }
                payment.setStatus(Payment.Status.FAILED);
                payment.setFailureReason(ev.failureReason());
                markOrderFailed(order);
            }
            case REFUND_SUCCEEDED -> refunds.findFirstByPaymentIdAndStatus(payment.getId(), Refund.Status.REQUESTED)
                    .ifPresent(r -> completeRefund(payment, order, r));
            case REFUND_FAILED -> refunds.findFirstByPaymentIdAndStatus(payment.getId(), Refund.Status.REQUESTED)
                    .ifPresent(r -> r.setStatus(Refund.Status.FAILED));
        }
    }

    private void markOrderFailed(OrderEntity order) {
        if (order.getStatus() == OrderStatus.PENDING_PAYMENT) {
            orderService.transition(order, OrderStatus.PAYMENT_FAILED, Actor.SYSTEM, null, null);
        }
    }

    // ---------------------------------------------------------------------------------------------
    // Refunds
    // ---------------------------------------------------------------------------------------------

    @Transactional
    public Refund requestRefund(Payment payment, BigDecimal amount, String reason, UUID requestedBy) {
        if (payment.getStatus() != Payment.Status.SUCCEEDED && payment.getStatus() != Payment.Status.PARTIALLY_REFUNDED) {
            throw ApiException.conflict("PAYMENT_NOT_REFUNDABLE", "Payment cannot be refunded");
        }
        BigDecimal refundable = payment.getAmount().subtract(payment.getRefundedAmount());
        if (amount.signum() <= 0 || amount.compareTo(refundable) > 0) {
            throw ApiException.badRequest("INVALID_REFUND_AMOUNT", "Refund amount exceeds the refundable balance");
        }
        if (refunds.findFirstByPaymentIdAndStatus(payment.getId(), Refund.Status.REQUESTED).isPresent()) {
            throw ApiException.conflict("REFUND_IN_PROGRESS", "A refund is already in progress");
        }
        PaymentProvider provider = providers.byId(payment.getProvider())
                .orElseThrow(() -> ApiException.conflict("PROVIDER_UNAVAILABLE", "Payment provider is unavailable"));
        Refund r = new Refund();
        r.setPaymentId(payment.getId());
        r.setOrderId(payment.getOrderId());
        r.setAmount(amount);
        r.setReason(reason);
        r.setRequestedBy(requestedBy);
        r = refunds.save(r);
        PaymentProvider.RefundOutcome out = provider.refund(payment, amount, reason);
        if (!out.accepted()) {
            r.setStatus(Refund.Status.FAILED);
            throw ApiException.conflict("REFUND_REJECTED", "The payment provider rejected the refund");
        }
        if (out.completedImmediately()) {
            completeRefund(payment, orders.lockById(payment.getOrderId()).orElseThrow(), r);
        }
        audit.record("REFUND_REQUESTED", "PAYMENT", payment.getId(), "amount=" + amount);
        return r;
    }

    private void completeRefund(Payment payment, OrderEntity order, Refund refund) {
        refund.setStatus(Refund.Status.COMPLETED);
        refund.setProcessedAt(java.time.Instant.now());
        payment.setRefundedAmount(payment.getRefundedAmount().add(refund.getAmount()));
        boolean full = payment.getRefundedAmount().compareTo(payment.getAmount()) >= 0;
        payment.setStatus(full ? Payment.Status.REFUNDED : Payment.Status.PARTIALLY_REFUNDED);
        if (full && (order.getStatus() == OrderStatus.CANCELLED || order.getStatus() == OrderStatus.DELIVERED)) {
            orderService.transition(order, OrderStatus.REFUNDED, Actor.SYSTEM, null, null);
        }
    }

    /** Full refund of the latest successful payment of an order (used on cancellation and by the admin workflow). */
    @Transactional
    public Refund refundOrder(UUID orderId, String reason, UUID requestedBy) {
        Payment p = payments.findByOrderIdOrderByCreatedAtDesc(orderId).stream()
                .filter(x -> x.getStatus() == Payment.Status.SUCCEEDED || x.getStatus() == Payment.Status.PARTIALLY_REFUNDED)
                .findFirst().orElseThrow(() -> ApiException.conflict("PAYMENT_NOT_REFUNDABLE", "No refundable payment"));
        return requestRefund(p, p.getAmount().subtract(p.getRefundedAmount()), reason, requestedBy);
    }

    @Transactional(readOnly = true)
    public List<Payment> forOrder(UUID orderId) {
        return payments.findByOrderIdOrderByCreatedAtDesc(orderId);
    }

    @Transactional(readOnly = true)
    public List<Refund> refundsForOrder(UUID orderId) {
        return refunds.findByOrderId(orderId);
    }
}
