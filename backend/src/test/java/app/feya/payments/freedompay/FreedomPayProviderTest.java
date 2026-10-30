package app.feya.payments.freedompay;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import app.feya.common.ApiException;
import app.feya.payments.Payment;
import app.feya.payments.PaymentProvider;
import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.math.BigDecimal;
import java.net.InetSocketAddress;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class FreedomPayProviderTest {
    private static final String SECRET = "test-secret";
    private HttpServer server;
    private final AtomicReference<String> lastPath = new AtomicReference<>();
    private final AtomicReference<String> lastBody = new AtomicReference<>();
    private volatile int status = 200;
    private volatile String responseXml = "";
    private FreedomPayProvider provider;

    @BeforeEach
    void start() throws IOException {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/", ex -> {
            lastPath.set(ex.getRequestURI().getPath());
            lastBody.set(new String(ex.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
            byte[] out = responseXml.getBytes(StandardCharsets.UTF_8);
            ex.sendResponseHeaders(status, out.length);
            ex.getResponseBody().write(out);
            ex.close();
        });
        server.start();
        provider = new FreedomPayProvider(new FreedomPayProperties("http://127.0.0.1:" + server.getAddress().getPort(),
                "merchant-1", SECRET, "result.php", "https://feya.kz/paid", "https://feya.kz/failed"));
    }

    @AfterEach
    void stop() {
        server.stop(0);
    }

    private static Payment payment() {
        Payment p = new Payment();
        p.setOrderId(UUID.randomUUID());
        p.setAmount(new BigDecimal("27900.00"));
        p.setCurrency("KZT");
        p.setProviderPaymentId("fp-77");
        return p;
    }

    private static String xml(String... kv) {
        StringBuilder b = new StringBuilder("<?xml version=\"1.0\" encoding=\"utf-8\"?><response>");
        for (int i = 0; i < kv.length; i += 2) {
            b.append('<').append(kv[i]).append('>').append(kv[i + 1]).append("</").append(kv[i]).append('>');
        }
        return b.append("</response>").toString();
    }

    private static String form(Map<String, String> fields) {
        StringBuilder b = new StringBuilder();
        fields.forEach((k, v) -> b.append(b.length() == 0 ? "" : "&").append(URLEncoder.encode(k, StandardCharsets.UTF_8))
                .append('=').append(URLEncoder.encode(v, StandardCharsets.UTF_8)));
        return b.toString();
    }

    private static String signedCallback(String script, String secret, String... kv) {
        Map<String, String> f = new LinkedHashMap<>();
        for (int i = 0; i < kv.length; i += 2) {
            f.put(kv[i], kv[i + 1]);
        }
        f.put("pg_sig", FreedomPaySignature.compute(script, f, secret));
        return form(f);
    }

    @Test
    void createSessionSendsASignedRequestAndReturnsTheCheckoutUrl() {
        responseXml = xml("pg_status", "ok", "pg_payment_id", "fp-1", "pg_redirect_url", "https://pay.example/x");
        PaymentProvider.Session s = provider.createSession(payment(), "FEYA FY-1");
        assertThat(s.providerPaymentId()).isEqualTo("fp-1");
        assertThat(s.checkoutUrl()).isEqualTo("https://pay.example/x");
        assertThat(lastPath.get()).isEqualTo("/init_payment.php");

        Map<String, String> sent = FreedomPayProvider.parseForm(lastBody.get());
        assertThat(sent).containsEntry("pg_merchant_id", "merchant-1").containsEntry("pg_amount", "27900.00")
                .containsEntry("pg_currency", "KZT").containsEntry("pg_description", "FEYA FY-1")
                .containsEntry("pg_success_url", "https://feya.kz/paid").containsKey("pg_idempotency_key");
        String sig = sent.remove("pg_sig");
        assertThat(FreedomPaySignature.matches("init_payment.php", sent, SECRET, sig)).isTrue();
    }

    @Test
    void eachAttemptGetsItsOwnOrderId() {
        responseXml = xml("pg_status", "ok", "pg_payment_id", "fp-1", "pg_redirect_url", "https://pay.example/x");
        Payment p = payment();
        provider.createSession(p, "d");
        String first = FreedomPayProvider.parseForm(lastBody.get()).get("pg_order_id");
        provider.createSession(p, "d");
        String second = FreedomPayProvider.parseForm(lastBody.get()).get("pg_order_id");
        assertThat(first).startsWith(p.getOrderId().toString()).isNotEqualTo(second);
    }

    @Test
    void aRejectedOrUnreachableGatewayBecomesBadGatewayWithoutLeakingDetails() {
        responseXml = xml("pg_status", "error", "pg_error_description", "Merchant is blocked");
        assertThatThrownBy(() -> provider.createSession(payment(), "d")).isInstanceOfSatisfying(ApiException.class,
                e -> {
                    assertThat(e.status().value()).isEqualTo(502);
                    assertThat(e.getMessage()).doesNotContain("blocked");
                });
        status = 500;
        assertThatThrownBy(() -> provider.createSession(payment(), "d")).isInstanceOf(ApiException.class);
        responseXml = "not xml";
        status = 200;
        assertThatThrownBy(() -> provider.createSession(payment(), "d")).isInstanceOf(ApiException.class);
    }

    @Test
    void webhookSignatureIsVerifiedWithTheResultNotifyScriptName() {
        String body = signedCallback("result.php", SECRET, "pg_payment_id", "fp-77", "pg_result", "1");
        assertThat(provider.verifySignature(body, null)).isTrue();
        assertThat(provider.verifySignature(signedCallback("other.php", SECRET, "pg_payment_id", "fp-77", "pg_result", "1"),
                null)).isFalse();
        assertThat(provider.verifySignature(signedCallback("result.php", "wrong", "pg_payment_id", "fp-77", "pg_result", "1"),
                null)).isFalse();
        assertThat(provider.verifySignature("pg_payment_id=fp-77&pg_result=1", null)).isFalse(); // unsigned
        assertThat(provider.verifySignature("", null)).isFalse();
        // tampering with a signed field invalidates it
        assertThat(provider.verifySignature(body.replace("pg_result=1", "pg_result=0"), null)).isFalse();
    }

    @Test
    void successFailureAndUnfinishedCallbacksMapToEvents() {
        PaymentProvider.ProviderEvent ok = provider.parseEvent(form(Map.of("pg_payment_id", "fp-77", "pg_result", "1",
                "pg_amount", "27900.00", "pg_currency", "KZT")));
        assertThat(ok.type()).isEqualTo(PaymentProvider.EventType.PAYMENT_SUCCEEDED);
        assertThat(ok.providerPaymentId()).isEqualTo("fp-77");
        assertThat(ok.amount()).isEqualByComparingTo("27900");
        assertThat(ok.currency()).isEqualTo("KZT");
        assertThat(ok.eventId()).isEqualTo("fp-77:1");

        PaymentProvider.ProviderEvent failed = provider.parseEvent(form(Map.of("pg_payment_id", "fp-77", "pg_result", "0",
                "pg_failure_description", "Insufficient funds")));
        assertThat(failed.type()).isEqualTo(PaymentProvider.EventType.PAYMENT_FAILED);
        assertThat(failed.failureReason()).isEqualTo("Insufficient funds");
        assertThat(failed.eventId()).isNotEqualTo(ok.eventId());

        assertThat(provider.parseEvent(form(Map.of("pg_payment_id", "fp-77", "pg_result", "2"))).type())
                .isEqualTo(PaymentProvider.EventType.PAYMENT_PENDING);
        assertThatThrownBy(() -> provider.parseEvent("pg_result=1")).isInstanceOf(ApiException.class);
    }

    @Test
    void refundIsSignedAndReportsTheGatewayAnswer() {
        responseXml = xml("pg_status", "ok");
        PaymentProvider.RefundOutcome ok = provider.refund(payment(), new BigDecimal("1000.00"), "cancelled");
        assertThat(ok.accepted()).isTrue();
        assertThat(ok.completedImmediately()).isTrue();
        assertThat(lastPath.get()).isEqualTo("/revoke.php");
        Map<String, String> sent = FreedomPayProvider.parseForm(lastBody.get());
        assertThat(sent).containsEntry("pg_payment_id", "fp-77").containsEntry("pg_refund_amount", "1000.00");
        String sig = sent.remove("pg_sig");
        assertThat(FreedomPaySignature.matches("revoke.php", sent, SECRET, sig)).isTrue();

        responseXml = xml("pg_status", "error", "pg_error_description", "Too late");
        PaymentProvider.RefundOutcome rejected = provider.refund(payment(), new BigDecimal("1000.00"), "x");
        assertThat(rejected.accepted()).isFalse();
        assertThat(rejected.failureReason()).isEqualTo("Too late");

        status = 503;
        assertThat(provider.refund(payment(), new BigDecimal("1.00"), "x").accepted()).isFalse();
    }

    @Test
    void theWebhookAcknowledgementIsXml() {
        assertThat(provider.webhookAck()).contains("<pg_status>ok</pg_status>").startsWith("<?xml");
        assertThat(provider.id()).isEqualTo("freedompay");
        assertThat(provider.sandbox()).isFalse();
    }

    @Test
    void misconfigurationFailsAtStartup() {
        assertThatThrownBy(() -> new FreedomPayProvider(new FreedomPayProperties("", "m", "s", "result.php", null, null)))
                .isInstanceOf(IllegalStateException.class);
        assertThatThrownBy(() -> new FreedomPayProvider(new FreedomPayProperties("http://x", "m", "", "result.php", null, null)))
                .isInstanceOf(IllegalStateException.class);
    }
}
