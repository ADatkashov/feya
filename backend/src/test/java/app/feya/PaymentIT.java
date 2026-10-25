package app.feya;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import app.feya.common.ApiException;
import app.feya.support.IntegrationTest;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class PaymentIT extends IntegrationTest {

    private String newOrder(String token) {
        return createOrder(token, List.of(line(variantId("romantika", "STANDARD"), 1))).text("id");
    }

    @Test
    void methodsAreReportedAndMarkedSandbox() {
        Resp m = GET("/payments/methods", null);
        assertThat(m.body().get("configured").asBoolean()).isTrue();
        assertThat(m.body().get("sandbox").asBoolean()).isTrue();
        assertThat(m.body().get("methods")).hasSize(3);
    }

    @Test
    void orderIsOnlyPaidAfterAVerifiedWebhook() {
        String token = login(CUSTOMER);
        String id = newOrder(token);
        Resp p = pay(token, id);
        assertThat(p.status()).isEqualTo(200);
        assertThat(p.text("status")).isEqualTo("PENDING");
        // Merely creating a payment attempt must not change the order.
        assertThat(GET("/orders/" + id, token).text("status")).isEqualTo("PENDING_PAYMENT");
        String providerId = one("select provider_payment_id from payments where id=?::uuid", String.class, p.text("id"));
        deliverWebhook("evt-1", "PAYMENT_SUCCEEDED", providerId, p.body().get("amount").asText());
        Resp o = GET("/orders/" + id, token);
        assertThat(o.text("status")).isEqualTo("PAID");
        assertThat(o.text("paymentStatus")).isEqualTo("PAID");
        assertThat(GET("/payments/" + p.text("id"), token).text("status")).isEqualTo("SUCCEEDED");
    }

    @Test
    void webhookWithInvalidSignatureIsRejectedAndChangesNothing() throws Exception {
        String token = login(CUSTOMER);
        String id = newOrder(token);
        Resp p = pay(token, id);
        String providerId = one("select provider_payment_id from payments where id=?::uuid", String.class, p.text("id"));
        String body = om.writeValueAsString(Map.of("eventId", "forged", "type", "PAYMENT_SUCCEEDED",
                "providerPaymentId", providerId, "amount", "21900.00", "currency", "KZT"));
        Resp r = send(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post("/api/v1/payments/webhook/sandbox")
                .header("X-Webhook-Signature", "deadbeef").contentType("application/json").content(body), null, null, null);
        assertThat(r.status()).isEqualTo(401);
        Resp missing = send(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post("/api/v1/payments/webhook/sandbox")
                .contentType("application/json").content(body), null, null, null);
        assertThat(missing.status()).isEqualTo(401);
        assertThat(GET("/orders/" + id, token).text("status")).isEqualTo("PENDING_PAYMENT");
        assertThat(one("select count(*) from payment_events where event_id='forged'", Integer.class)).isZero();
    }

    @Test
    void redeliveredWebhookIsIdempotent() {
        String token = login(CUSTOMER);
        String id = newOrder(token);
        Resp p = pay(token, id);
        String providerId = one("select provider_payment_id from payments where id=?::uuid", String.class, p.text("id"));
        deliverWebhook("evt-dup", "PAYMENT_SUCCEEDED", providerId, p.body().get("amount").asText());
        deliverWebhook("evt-dup", "PAYMENT_SUCCEEDED", providerId, p.body().get("amount").asText());
        deliverWebhook("evt-dup-2", "PAYMENT_SUCCEEDED", providerId, p.body().get("amount").asText()); // new event id, same outcome
        assertThat(one("select count(*) from order_status_history where order_id=?::uuid and to_status='PAID'",
                Integer.class, id)).isEqualTo(1);
        assertThat(one("select count(*) from payment_events where event_id like 'evt-dup%'", Integer.class)).isEqualTo(2);
    }

    @Test
    void amountMismatchNeverMarksOrderPaid() {
        String token = login(CUSTOMER);
        String id = newOrder(token);
        Resp p = pay(token, id);
        String providerId = one("select provider_payment_id from payments where id=?::uuid", String.class, p.text("id"));
        deliverWebhook("evt-bad-amt", "PAYMENT_SUCCEEDED", providerId, "1.00");
        Resp o = GET("/orders/" + id, token);
        assertThat(o.text("status")).isEqualTo("PAYMENT_FAILED");
        assertThat(GET("/payments/" + p.text("id"), token).text("failureReason")).isEqualTo("AMOUNT_MISMATCH");
    }

    @Test
    void failedPaymentCanBeRetried() {
        String token = login(CUSTOMER);
        String id = newOrder(token);
        Resp p = pay(token, id);
        assertThat(POST("/payments/sandbox/" + p.text("id") + "/complete", Map.of("outcome", "FAILURE"), token).text("status")).isEqualTo("FAILED");
        assertThat(GET("/orders/" + id, token).text("status")).isEqualTo("PAYMENT_FAILED");
        assertThat(GET("/orders/" + id, token).body().get("canPay").asBoolean()).isTrue();
        Resp retry = pay(token, id);
        assertThat(retry.status()).isEqualTo(200);
        assertThat(retry.text("id")).isNotEqualTo(p.text("id"));
        assertThat(GET("/orders/" + id, token).text("status")).isEqualTo("PENDING_PAYMENT");
        POST("/payments/sandbox/" + retry.text("id") + "/complete", Map.of("outcome", "SUCCESS"), token);
        assertThat(GET("/orders/" + id, token).text("status")).isEqualTo("PAID");
    }

    @Test
    void startingPaymentTwiceReusesThePendingAttempt() {
        String token = login(CUSTOMER);
        String id = newOrder(token);
        assertThat(pay(token, id).text("id")).isEqualTo(pay(token, id).text("id"));
        assertThat(one("select count(*) from payments where order_id=?::uuid", Integer.class, id)).isEqualTo(1);
    }

    @Test
    void paidOrderCannotBePaidAgainAndUnknownMethodsAreRejected() {
        String token = login(CUSTOMER);
        String id = paidOrder(token, List.of(line(variantId("romantika", "SMALL"), 1)));
        assertThat(pay(token, id).status()).isEqualTo(409);
        String id2 = newOrder(token);
        assertThat(POST("/orders/" + id2 + "/payments", Map.of("method", "BITCOIN"), token).status()).isEqualTo(400);
    }

    @Test
    void customersCannotTouchOthersPayments() {
        String owner = login(CUSTOMER);
        String other = login(OTHER_CUSTOMER);
        String id = newOrder(owner);
        Resp p = pay(owner, id);
        assertThat(GET("/payments/" + p.text("id"), other).status()).isEqualTo(404);
        assertThat(POST("/payments/sandbox/" + p.text("id") + "/complete", Map.of("outcome", "SUCCESS"), other).status()).isEqualTo(404);
        assertThat(GET("/orders/" + id, owner).text("status")).isEqualTo("PENDING_PAYMENT");
    }

    @Test
    void cancellingAPaidOrderRefundsItAutomatically() {
        String token = login(CUSTOMER);
        String id = paidOrder(token, List.of(line(variantId("romantika", "SMALL"), 1)));
        Resp c = POST("/orders/" + id + "/cancel", Map.of("reason", "test"), token);
        assertThat(c.status()).isEqualTo(200);
        Resp o = GET("/orders/" + id, token);
        assertThat(o.text("status")).isEqualTo("REFUNDED");
        assertThat(o.text("paymentStatus")).isEqualTo("REFUNDED");
        assertThat(one("select status from payments where order_id=?::uuid", String.class, id)).isEqualTo("REFUNDED");
        assertThat(one("select status from refunds where order_id=?::uuid", String.class, id)).isEqualTo("COMPLETED");
    }

    @Test
    void lateSuccessAfterCancellationIsRefunded() {
        String token = login(CUSTOMER);
        String id = newOrder(token);
        Resp p = pay(token, id);
        String providerId = one("select provider_payment_id from payments where id=?::uuid", String.class, p.text("id"));
        POST("/orders/" + id + "/cancel", Map.of(), token); // customer gives up while a payment is in flight
        deliverWebhook("evt-late", "PAYMENT_SUCCEEDED", providerId, p.body().get("amount").asText());
        // The order stays cancelled and the money goes straight back (cancelled -> refunded).
        assertThat(GET("/orders/" + id, token).text("status")).isEqualTo("REFUNDED");
        assertThat(one("select count(*) from refunds where order_id=?::uuid and status='COMPLETED'", Integer.class, id)).isEqualTo(1);
    }

    @Test
    void webhookForUnknownPaymentOrProviderDoesNotFail() {
        deliverWebhook("evt-unknown", "PAYMENT_SUCCEEDED", "sbx_does_not_exist", "10.00");
        assertThatThrownBy(() -> paymentService.handleWebhook("nope", "{}", "x")).isInstanceOf(ApiException.class);
    }

    @Test
    void adminRefundWorkflowForDeliveredOrders() {
        String token = login(CUSTOMER);
        String id = paidOrder(token, List.of(line(variantId("romantika", "SMALL"), 1)));
        sql("update orders set status='DELIVERED', delivered_at=now() where id=?::uuid", id);
        String admin = login(ADMIN);
        String support = login(SUPPORT);
        assertThat(POST("/admin/orders/" + id + "/refund", Map.of("reason", "quality"), support).status()).isEqualTo(403);
        Resp r = POST("/admin/orders/" + id + "/refund", Map.of("reason", "quality"), admin);
        assertThat(r.status()).isEqualTo(200);
        assertThat(GET("/orders/" + id, token).text("status")).isEqualTo("REFUNDED");
        assertThat(one("select count(*) from audit_events where action='REFUND_REQUESTED'", Integer.class)).isEqualTo(1);
    }

    @Test
    void sandboxEndpointsRequireAuthentication() {
        assertThat(POST("/payments/sandbox/" + UUID.randomUUID() + "/complete", Map.of("outcome", "SUCCESS"), null).status()).isEqualTo(401);
    }
}
