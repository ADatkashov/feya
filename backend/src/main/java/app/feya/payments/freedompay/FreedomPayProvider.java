package app.feya.payments.freedompay;

import app.feya.common.ApiException;
import app.feya.payments.Payment;
import app.feya.payments.PaymentProvider;
import java.math.BigDecimal;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;

/**
 * FreedomPay (Kazakhstan) through the classic {@code pg_*} form-POST/XML API with a hosted checkout page: card data
 * goes to FreedomPay, never to FEYA. Ported from the ZAIRO integration and adapted to {@link PaymentProvider}.
 *
 * <p>The outcome of a payment is only ever taken from the signed Result-notify webhook ({@link #verifySignature} +
 * {@link #parseEvent}), never from the browser returning to the success/failure URL.
 *
 * <p>Open points that need the merchant panel or FreedomPay support (listed in docs/INTEGRATIONS.md): the exact
 * script name the Result-notify callback is signed with ({@code resultNotifyScriptName}), whether an unsigned
 * {@code pg_status=ok} acknowledgement stops their retries, and fiscal receipt data for refunds.
 */
public class FreedomPayProvider implements PaymentProvider {
    public static final String ID = "freedompay";
    private static final Logger log = LoggerFactory.getLogger(FreedomPayProvider.class);
    private static final String XML_HEADER = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>";
    private static final SecureRandom RANDOM = new SecureRandom();

    private final FreedomPayProperties props;
    private final FreedomPayHttpClient http;

    public FreedomPayProvider(FreedomPayProperties props) {
        if (isBlank(props.apiUrl()) || isBlank(props.merchantId()) || isBlank(props.secretKey())) {
            throw new IllegalStateException("FEYA_PAYMENTS_PROVIDER=freedompay requires FEYA_FREEDOMPAY_API_URL, "
                    + "FEYA_FREEDOMPAY_MERCHANT_ID and FEYA_FREEDOMPAY_SECRET_KEY");
        }
        this.props = props;
        this.http = new FreedomPayHttpClient(props.apiUrl());
    }

    @Override
    public String id() {
        return ID;
    }

    @Override
    public boolean sandbox() {
        return false;
    }

    @Override
    public Session createSession(Payment payment, String description) {
        // The payment row has no id yet, so each attempt gets its own order id: the order plus a random token.
        // The same token is the idempotency key, so a retried HTTP call cannot mint a second charge.
        String attempt = Long.toHexString(RANDOM.nextLong());
        Map<String, String> fields = new HashMap<>();
        fields.put("pg_merchant_id", props.merchantId());
        fields.put("pg_amount", payment.getAmount().toPlainString());
        fields.put("pg_currency", payment.getCurrency());
        fields.put("pg_description", description);
        fields.put("pg_order_id", payment.getOrderId() + "-" + attempt);
        fields.put("pg_idempotency_key", payment.getOrderId() + "-" + attempt);
        if (!isBlank(props.successUrl())) {
            fields.put("pg_success_url", props.successUrl());
        }
        if (!isBlank(props.failureUrl())) {
            fields.put("pg_failure_url", props.failureUrl());
        }
        fields.put("pg_salt", salt());
        sign("init_payment.php", fields);

        Map<String, String> response;
        try {
            response = http.post("init_payment.php", fields);
        } catch (FreedomPayException e) {
            log.warn("FreedomPay init_payment failed: {}", e.getMessage());
            throw unavailable();
        }
        if (!"ok".equalsIgnoreCase(response.get("pg_status")) || isBlank(response.get("pg_payment_id"))) {
            log.warn("FreedomPay init_payment rejected: {}", errorMessage(response));
            throw unavailable();
        }
        return new Session(response.get("pg_payment_id"), response.get("pg_redirect_url"));
    }

    @Override
    public boolean verifySignature(String rawBody, String signatureHeader) {
        Map<String, String> fields = parseForm(rawBody);
        String received = fields.remove("pg_sig");
        return received != null
                && FreedomPaySignature.matches(props.resultNotifyScriptName(), fields, props.secretKey(), received);
    }

    @Override
    public ProviderEvent parseEvent(String rawBody) {
        Map<String, String> f = parseForm(rawBody);
        String providerPaymentId = f.get("pg_payment_id");
        if (isBlank(providerPaymentId)) {
            throw ApiException.badRequest("INVALID_WEBHOOK", "Malformed webhook payload");
        }
        // pg_result: 1 = paid, 0 = failed, 2 = not finished yet (docs.freedompay.kz). A callback carries no unique
        // event id (their retries repeat the same payment id), so the outcome is part of the dedup key.
        String result = f.getOrDefault("pg_result", "");
        EventType type = switch (result) {
            case "1" -> EventType.PAYMENT_SUCCEEDED;
            case "0" -> EventType.PAYMENT_FAILED;
            default -> EventType.PAYMENT_PENDING;
        };
        String reason = type == EventType.PAYMENT_FAILED
                ? firstNonBlank(f.get("pg_failure_description"), f.get("pg_error_description"), "DECLINED") : null;
        return new ProviderEvent(providerPaymentId + ":" + result, type, providerPaymentId,
                parseAmount(f.get("pg_amount")), blankToNull(f.get("pg_currency")), reason);
    }

    @Override
    public RefundOutcome refund(Payment payment, BigDecimal amount, String reason) {
        // revoke.php is synchronous: the answer says whether the refund was accepted. Receipt positions (Kazakhstan
        // fiscal data) are not sent: if FreedomPay requires them, it surfaces as a failed refund, never as invented data.
        Map<String, String> fields = new HashMap<>();
        fields.put("pg_merchant_id", props.merchantId());
        fields.put("pg_payment_id", payment.getProviderPaymentId());
        fields.put("pg_refund_amount", amount.toPlainString());
        fields.put("pg_salt", salt());
        sign("revoke.php", fields);
        try {
            Map<String, String> response = http.post("revoke.php", fields);
            boolean ok = "ok".equalsIgnoreCase(response.get("pg_status"));
            return new RefundOutcome(ok, ok, ok ? null : errorMessage(response));
        } catch (FreedomPayException e) {
            log.warn("FreedomPay refund failed: {}", e.getMessage());
            return new RefundOutcome(false, false, e.getMessage());
        }
    }

    /** FreedomPay expects an XML answer to Result-notify; any other body makes it retry for hours. */
    @Override
    public String webhookAck() {
        return XML_HEADER + "<response><pg_status>ok</pg_status><pg_description>accepted</pg_description></response>";
    }

    private void sign(String scriptName, Map<String, String> fields) {
        fields.put("pg_sig", FreedomPaySignature.compute(scriptName, fields, props.secretKey()));
    }

    /** Decodes {@code application/x-www-form-urlencoded}; values keep their order of arrival. */
    static Map<String, String> parseForm(String body) {
        Map<String, String> out = new LinkedHashMap<>();
        if (body == null || body.isBlank()) {
            return out;
        }
        for (String pair : body.split("&")) {
            if (pair.isEmpty()) {
                continue;
            }
            int eq = pair.indexOf('=');
            String key = URLDecoder.decode(eq < 0 ? pair : pair.substring(0, eq), StandardCharsets.UTF_8);
            String value = eq < 0 ? "" : URLDecoder.decode(pair.substring(eq + 1), StandardCharsets.UTF_8);
            out.put(key, value);
        }
        return out;
    }

    private static ApiException unavailable() {
        return new ApiException(HttpStatus.BAD_GATEWAY, "PAYMENT_PROVIDER_ERROR",
                "The payment could not be started, please try again later");
    }

    private static String errorMessage(Map<String, String> response) {
        String description = response.get("pg_error_description");
        return isBlank(description) ? "FreedomPay returned pg_status=" + response.get("pg_status") : description;
    }

    private static BigDecimal parseAmount(String raw) {
        try {
            return isBlank(raw) ? null : new BigDecimal(raw.trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private static String firstNonBlank(String... values) {
        for (String v : values) {
            if (!isBlank(v)) {
                return v;
            }
        }
        return null;
    }

    private static String blankToNull(String s) {
        return isBlank(s) ? null : s.trim();
    }

    private static boolean isBlank(String s) {
        return s == null || s.isBlank();
    }

    private static String salt() {
        return Long.toUnsignedString(RANDOM.nextLong());
    }
}
