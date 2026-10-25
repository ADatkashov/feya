package app.feya.payments;

import app.feya.common.FeyaProperties;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.util.UUID;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

/**
 * DEVELOPMENT-ONLY provider. It never moves money. The "gateway" side is simulated by
 * {@code SandboxController}, which signs an event with the shared webhook secret and delivers it through the very
 * same verified webhook path used by real providers. Refused at startup in production by ProductionGuard.
 */
public class SandboxPaymentProvider implements PaymentProvider {
    private final String secret;
    private final ObjectMapper mapper;

    public SandboxPaymentProvider(FeyaProperties props, ObjectMapper mapper) {
        this.secret = props.payments().webhookSecret();
        this.mapper = mapper;
    }

    @Override
    public String id() {
        return "sandbox";
    }

    @Override
    public boolean sandbox() {
        return true;
    }

    @Override
    public Session createSession(Payment payment, String description) {
        return new Session("sbx_" + UUID.randomUUID().toString().replace("-", ""), null);
    }

    @Override
    public boolean verifySignature(String rawBody, String signatureHeader) {
        if (signatureHeader == null || secret == null || secret.isBlank()) {
            return false;
        }
        return MessageDigest.isEqual(sign(rawBody).getBytes(StandardCharsets.UTF_8),
                signatureHeader.trim().getBytes(StandardCharsets.UTF_8));
    }

    public String sign(String rawBody) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            return HexFormat.of().formatHex(mac.doFinal(rawBody.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    @Override
    public ProviderEvent parseEvent(String rawBody) {
        try {
            JsonNode n = mapper.readTree(rawBody);
            return new ProviderEvent(n.get("eventId").asText(), EventType.valueOf(n.get("type").asText()),
                    n.get("providerPaymentId").asText(), n.hasNonNull("amount") ? new BigDecimal(n.get("amount").asText()) : null,
                    n.hasNonNull("currency") ? n.get("currency").asText() : null,
                    n.hasNonNull("failureReason") ? n.get("failureReason").asText() : null);
        } catch (Exception e) {
            throw app.feya.common.ApiException.badRequest("INVALID_WEBHOOK", "Malformed webhook payload");
        }
    }

    @Override
    public RefundOutcome refund(Payment payment, BigDecimal amount, String reason) {
        return new RefundOutcome(true, true, null);
    }
}
