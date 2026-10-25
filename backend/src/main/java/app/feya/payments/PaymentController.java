package app.feya.payments;

import app.feya.common.ApiException;
import app.feya.security.Auth;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class PaymentController {
    public record StartPaymentRequest(@NotBlank String method) {}

    public record PaymentDto(UUID id, UUID orderId, String provider, String method, Payment.Status status,
                             BigDecimal amount, String currency, boolean sandbox, String checkoutUrl,
                             String failureReason, Instant createdAt) {
        static PaymentDto of(Payment p) {
            return new PaymentDto(p.getId(), p.getOrderId(), p.getProvider(), p.getMethod(), p.getStatus(),
                    p.getAmount(), p.getCurrency(), p.isSandbox(), p.getCheckoutUrl(), p.getFailureReason(),
                    p.getCreatedAt());
        }
    }

    public record MethodsResponse(boolean configured, boolean sandbox, List<String> methods) {}

    private final PaymentService payments;
    private final PaymentProviders providers;

    public PaymentController(PaymentService payments, PaymentProviders providers) {
        this.payments = payments;
        this.providers = providers;
    }

    @GetMapping("/payments/methods")
    public MethodsResponse methods() {
        boolean configured = providers.configured();
        return new MethodsResponse(configured, configured && providers.active().sandbox(), payments.methods());
    }

    @PostMapping("/orders/{orderId}/payments")
    public PaymentDto start(@PathVariable UUID orderId, @Valid @RequestBody StartPaymentRequest req) {
        return PaymentDto.of(payments.start(Auth.userId(), orderId, req.method()));
    }

    /** Status is read from our database, which only changes through verified webhooks. */
    @GetMapping("/payments/{id}")
    public PaymentDto get(@PathVariable UUID id) {
        return PaymentDto.of(payments.getForUser(Auth.userId(), id));
    }

    @PostMapping("/payments/webhook/{provider}")
    public void webhook(@PathVariable String provider, @RequestBody String rawBody,
                        @RequestHeader(value = "X-Webhook-Signature", required = false) String signature) {
        if (rawBody == null || rawBody.length() > 64_000) {
            throw ApiException.badRequest("INVALID_WEBHOOK", "Invalid payload");
        }
        payments.handleWebhook(provider, rawBody, signature);
    }
}
