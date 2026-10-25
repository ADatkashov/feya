package app.feya.payments;

import java.math.BigDecimal;

/**
 * Integration boundary for a payment gateway. The ordering module only talks to {@link PaymentService}; adding a
 * gateway means implementing this interface and registering it as a bean (see docs/INTEGRATIONS.md).
 *
 * Cards are never handled by FEYA: gateways must use a hosted checkout page or a native SDK that tokenizes on device.
 */
public interface PaymentProvider {
    String id();

    boolean sandbox();

    /** Creates a payment session at the gateway. */
    Session createSession(Payment payment, String description);

    /** Constant-time verification of the webhook signature over the raw request body. */
    boolean verifySignature(String rawBody, String signatureHeader);

    /** Parses a verified webhook body. */
    ProviderEvent parseEvent(String rawBody);

    /** Requests a (full or partial) refund. */
    RefundOutcome refund(Payment payment, BigDecimal amount, String reason);

    record Session(String providerPaymentId, String checkoutUrl) {}

    enum EventType { PAYMENT_SUCCEEDED, PAYMENT_FAILED, REFUND_SUCCEEDED, REFUND_FAILED }

    record ProviderEvent(String eventId, EventType type, String providerPaymentId, BigDecimal amount, String currency,
                         String failureReason) {}

    /** {@code completedImmediately} is false when the gateway confirms the refund later through a webhook. */
    record RefundOutcome(boolean accepted, boolean completedImmediately, String failureReason) {}
}
