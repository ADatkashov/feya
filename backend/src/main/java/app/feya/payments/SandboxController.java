package app.feya.payments;

import app.feya.common.ApiException;
import app.feya.security.Auth;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import java.util.UUID;
import org.springframework.boot.autoconfigure.condition.ConditionalOnBean;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Simulates the gateway side of a sandbox payment: it signs an event and delivers it through the same verified
 * webhook handler used by real providers. Exists only when the sandbox provider bean exists (never in production).
 */
@RestController
@RequestMapping("/api/v1/payments/sandbox")
@ConditionalOnBean(SandboxPaymentProvider.class)
public class SandboxController {
    public enum Outcome { SUCCESS, FAILURE }

    public record CompleteRequest(@NotNull Outcome outcome) {}

    private final SandboxPaymentProvider provider;
    private final PaymentService payments;
    private final ObjectMapper mapper;

    public SandboxController(SandboxPaymentProvider provider, PaymentService payments, ObjectMapper mapper) {
        this.provider = provider;
        this.payments = payments;
        this.mapper = mapper;
    }

    @PostMapping("/{paymentId}/complete")
    public PaymentController.PaymentDto complete(@PathVariable UUID paymentId, @Valid @RequestBody CompleteRequest req)
            throws Exception {
        Payment p = payments.getForUser(Auth.userId(), paymentId);
        if (!p.isSandbox()) {
            throw ApiException.badRequest("NOT_SANDBOX", "Not a sandbox payment");
        }
        ObjectNode body = mapper.createObjectNode();
        body.put("eventId", "evt_" + UUID.randomUUID());
        body.put("type", req.outcome() == Outcome.SUCCESS ? "PAYMENT_SUCCEEDED" : "PAYMENT_FAILED");
        body.put("providerPaymentId", p.getProviderPaymentId());
        body.put("amount", p.getAmount().toPlainString());
        body.put("currency", p.getCurrency());
        if (req.outcome() == Outcome.FAILURE) {
            body.put("failureReason", "SANDBOX_DECLINED");
        }
        String raw = mapper.writeValueAsString(body);
        payments.handleWebhook("sandbox", raw, provider.sign(raw));
        return PaymentController.PaymentDto.of(payments.getForUser(Auth.userId(), paymentId));
    }
}
