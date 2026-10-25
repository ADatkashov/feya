package app.feya.administration;

import app.feya.common.ApiException;
import app.feya.common.AuditService;
import app.feya.common.PageResponse;
import app.feya.courier.Courier;
import app.feya.courier.CourierRepository;
import app.feya.orders.Actor;
import app.feya.orders.OrderDtos;
import app.feya.orders.OrderEntity;
import app.feya.orders.OrderRepository;
import app.feya.orders.OrderService;
import app.feya.orders.OrderStateMachine;
import app.feya.orders.OrderStatus;
import app.feya.payments.Payment;
import app.feya.payments.PaymentService;
import app.feya.payments.Refund;
import app.feya.security.Auth;
import jakarta.persistence.criteria.Predicate;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/admin/orders")
public class AdminOrderController {
    public record AdminOrderRow(UUID id, String number, OrderStatus status, OrderEntity.PaymentState paymentStatus,
                                BigDecimal total, String currency, String recipientName, String city, UUID floristId,
                                UUID courierId, java.time.LocalDate deliveryDate, Instant createdAt) {}

    public record PaymentRow(UUID id, String provider, String method, Payment.Status status, BigDecimal amount,
                             BigDecimal refunded, boolean sandbox, String failureReason, Instant createdAt) {}

    public record RefundRow(UUID id, BigDecimal amount, Refund.Status status, String reason, Instant createdAt) {}

    public record AdminOrderDetail(OrderDtos.OrderDetail order, UUID floristId, UUID courierId,
                                   List<PaymentRow> payments, List<RefundRow> refunds, List<OrderStatus> allowedNext) {}

    public record StatusRequest(@NotNull OrderStatus status, @Size(max = 255) String note) {}

    public record AssignRequest(@NotNull UUID courierId) {}

    public record RefundRequest(@DecimalMin("1") BigDecimal amount, @Size(max = 255) String reason) {}

    private final OrderRepository orders;
    private final OrderService orderService;
    private final PaymentService payments;
    private final CourierRepository couriers;
    private final AuditService audit;

    public AdminOrderController(OrderRepository orders, OrderService orderService, PaymentService payments,
                                CourierRepository couriers, AuditService audit) {
        this.orders = orders;
        this.orderService = orderService;
        this.payments = payments;
        this.couriers = couriers;
        this.audit = audit;
    }

    @GetMapping
    @Transactional(readOnly = true)
    public PageResponse<AdminOrderRow> list(@RequestParam(required = false) List<OrderStatus> status,
                                            @RequestParam(required = false) String q,
                                            @RequestParam(required = false) UUID floristId,
                                            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
                                            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to,
                                            @RequestParam(defaultValue = "createdAt") String sort,
                                            @RequestParam(defaultValue = "desc") String dir,
                                            @RequestParam(defaultValue = "0") int page,
                                            @RequestParam(defaultValue = "20") int size) {
        if (!List.of("createdAt", "total", "deliveryDate", "status", "number").contains(sort)) {
            throw ApiException.badRequest("INVALID_SORT", "Unsupported sort field");
        }
        Specification<OrderEntity> spec = (r, cq, cb) -> {
            List<Predicate> ps = new ArrayList<>();
            if (status != null && !status.isEmpty()) ps.add(r.get("status").in(status));
            if (floristId != null) ps.add(cb.equal(r.get("floristId"), floristId));
            if (from != null) ps.add(cb.greaterThanOrEqualTo(r.get("createdAt"), from));
            if (to != null) ps.add(cb.lessThan(r.get("createdAt"), to));
            if (q != null && !q.isBlank()) {
                String like = "%" + q.trim().toLowerCase().replace("%", "\\%").replace("_", "\\_") + "%";
                ps.add(cb.or(cb.like(cb.lower(r.get("number")), like, '\\'),
                        cb.like(cb.lower(r.get("recipientName")), like, '\\'),
                        cb.like(r.get("recipientPhone"), like, '\\')));
            }
            return cb.and(ps.toArray(Predicate[]::new));
        };
        Sort s = Sort.by("asc".equalsIgnoreCase(dir) ? Sort.Direction.ASC : Sort.Direction.DESC, sort);
        return PageResponse.of(orders.findAll(spec, PageRequest.of(Math.max(0, page), Math.max(1, Math.min(size, 100)), s)),
                o -> new AdminOrderRow(o.getId(), o.getNumber(), o.getStatus(), o.getPaymentStatus(), o.getTotal(),
                        o.getCurrency(), o.getRecipientName(), o.getAddrCity(), o.getFloristId(), o.getCourierId(),
                        o.getDeliveryDate(), o.getCreatedAt()));
    }

    @GetMapping("/{id}")
    @Transactional(readOnly = true)
    public AdminOrderDetail get(@PathVariable UUID id) {
        return detail(orderService.require(id));
    }

    @PostMapping("/{id}/status")
    @Transactional
    public AdminOrderDetail setStatus(@PathVariable UUID id, @Valid @RequestBody StatusRequest req) {
        OrderEntity o = orders.lockById(id).orElseThrow(() -> ApiException.notFound("Order"));
        // Money moves only through the refund workflow, never by editing a status.
        if (req.status() == OrderStatus.REFUNDED || req.status() == OrderStatus.PAID) {
            throw ApiException.forbidden("This status can only be set by the payment/refund workflow");
        }
        orderService.transition(o, req.status(), actor(), Auth.userId(), req.note());
        audit.record("ORDER_STATUS_SET", "ORDER", o.getId(), o.getStatus() + (req.note() == null ? "" : " / " + req.note()));
        return detail(o);
    }

    @PostMapping("/{id}/assign-courier")
    @Transactional
    public AdminOrderDetail assignCourier(@PathVariable UUID id, @Valid @RequestBody AssignRequest req) {
        OrderEntity o = orders.lockById(id).orElseThrow(() -> ApiException.notFound("Order"));
        Courier c = couriers.findById(req.courierId()).filter(Courier::isActive)
                .orElseThrow(() -> ApiException.badRequest("INVALID_COURIER", "Unknown or inactive courier"));
        if (o.getStatus() != OrderStatus.READY_FOR_PICKUP) {
            throw ApiException.conflict("INVALID_TRANSITION", "Order must be ready for pickup");
        }
        orderService.transition(o, OrderStatus.COURIER_ASSIGNED, actor(), Auth.userId(), "assigned by staff");
        o.setCourierId(c.getUserId());
        audit.record("ORDER_COURIER_ASSIGNED", "ORDER", o.getId(), c.getUserId().toString());
        return detail(o);
    }

    /** Refund of a delivered/cancelled paid order; ADMIN only. Full refund when amount is omitted. */
    @PostMapping("/{id}/refund")
    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public AdminOrderDetail refund(@PathVariable UUID id, @Valid @RequestBody RefundRequest req) {
        OrderEntity o = orders.lockById(id).orElseThrow(() -> ApiException.notFound("Order"));
        if (o.getPaymentStatus() != OrderEntity.PaymentState.PAID) {
            throw ApiException.conflict("NOT_PAID", "Order has no refundable payment");
        }
        if (o.getStatus() == OrderStatus.DELIVERED && req.amount() == null) {
            payments.refundOrder(o.getId(), req.reason(), Auth.userId());
        } else if (req.amount() == null) {
            // Paid orders still in progress must be cancelled first, which refunds automatically.
            orderService.transition(o, OrderStatus.CANCELLED, actor(), Auth.userId(), req.reason());
        } else {
            Payment p = payments.forOrder(o.getId()).stream()
                    .filter(x -> x.getStatus() == Payment.Status.SUCCEEDED || x.getStatus() == Payment.Status.PARTIALLY_REFUNDED)
                    .findFirst().orElseThrow(() -> ApiException.conflict("NOT_PAID", "No refundable payment"));
            payments.requestRefund(p, req.amount(), req.reason(), Auth.userId());
        }
        return detail(o);
    }

    private Actor actor() {
        return Auth.hasRole("ADMIN") ? Actor.ADMIN : Actor.SUPPORT;
    }

    private AdminOrderDetail detail(OrderEntity o) {
        List<PaymentRow> pays = payments.forOrder(o.getId()).stream().map(p -> new PaymentRow(p.getId(), p.getProvider(),
                p.getMethod(), p.getStatus(), p.getAmount(), p.getRefundedAmount(), p.isSandbox(), p.getFailureReason(),
                p.getCreatedAt())).toList();
        List<RefundRow> refs = payments.refundsForOrder(o.getId()).stream().map(r -> new RefundRow(r.getId(),
                r.getAmount(), r.getStatus(), r.getReason(), r.getCreatedAt())).toList();
        List<OrderStatus> next = OrderStateMachine.allowedTargets(o.getStatus(), actor()).stream()
                .filter(s -> s != OrderStatus.REFUNDED && s != OrderStatus.PAID).sorted().toList();
        return new AdminOrderDetail(orderService.detail(o), o.getFloristId(), o.getCourierId(), pays, refs, next);
    }
}
