package app.feya;

import static org.assertj.core.api.Assertions.assertThat;

import app.feya.orders.OrderService;
import app.feya.support.IntegrationTest;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

class OrderIT extends IntegrationTest {
    @Autowired OrderService orderService;

    @Test
    void checkoutCreatesOrderWithServerSidePricesAndReservesStock() {
        String token = login(CUSTOMER);
        int before = stock("Достык", "romantika", "STANDARD");
        Resp r = createOrder(token, List.of(line(variantId("romantika", "STANDARD"), 2)));
        assertThat(r.status()).isEqualTo(201);
        assertThat(r.text("status")).isEqualTo("PENDING_PAYMENT");
        assertThat(r.text("number")).startsWith("FEYA-");
        assertThat(r.body().get("subtotal").decimalValue()).isEqualByComparingTo("43800");
        assertThat(r.body().get("total").decimalValue()).isEqualByComparingTo("43800");
        assertThat(r.body().get("items").get(0).get("unitPrice").decimalValue()).isEqualByComparingTo("21900");
        assertThat(r.body().get("canPay").asBoolean()).isTrue();
        assertThat(stock("Достык", "romantika", "STANDARD")).isEqualTo(before - 2);
        assertThat(r.body().get("timeline")).hasSize(2); // CREATED, PENDING_PAYMENT
    }

    @Test
    void termsMustBeAcceptedAndDeliveryChoiceIsRequired() {
        String token = login(CUSTOMER);
        Map<String, Object> req = new LinkedHashMap<>(orderRequest(List.of(line(variantId("romantika", "SMALL"), 1))));
        req.put("acceptTerms", false);
        assertThat(createOrder(token, req).status()).isEqualTo(400);
        req.put("acceptTerms", true);
        req.remove("slot");
        assertThat(createOrder(token, req).text("code")).isEqualTo("DELIVERY_TIME_REQUIRED");
    }

    @Test
    void idempotencyKeyReturnsTheSameOrderWithoutDoubleReservation() {
        String token = login(CUSTOMER);
        int before = stock("Достык", "romantika", "SMALL");
        Map<String, Object> req = orderRequest(List.of(line(variantId("romantika", "SMALL"), 1)));
        Resp first = POST("/orders", req, token, Map.of("Idempotency-Key", "abc-1"));
        Resp second = POST("/orders", req, token, Map.of("Idempotency-Key", "abc-1"));
        assertThat(first.status()).isEqualTo(201);
        assertThat(second.status()).isEqualTo(200);
        assertThat(second.text("id")).isEqualTo(first.text("id"));
        assertThat(stock("Достык", "romantika", "SMALL")).isEqualTo(before - 1);
    }

    @Test
    void cannotOrderMoreThanStockOrUnavailableItems() {
        String token = login(CUSTOMER);
        Resp tooMany = createOrder(token, List.of(line(variantId("alyj-barhat", "PREMIUM"), 3)));
        assertThat(tooMany.status()).isEqualTo(409);
        assertThat(tooMany.text("code")).isEqualTo("ITEMS_UNAVAILABLE");
        Resp none = createOrder(token, List.of(line(variantId("osennyaya-simfoniya", "STANDARD"), 1)));
        assertThat(none.status()).isEqualTo(409);
    }

    @Test
    void promoCodeIsRedeemedOnceAndReleasedOnCancel() {
        String token = login(CUSTOMER);
        UUID v = variantId("alyj-barhat", "STANDARD");
        Map<String, Object> req = new LinkedHashMap<>(orderRequest(List.of(line(v, 1))));
        req.put("promoCode", "FEYA10");
        Resp o = createOrder(token, req);
        assertThat(o.status()).isEqualTo(201);
        assertThat(o.body().get("discount").decimalValue()).isEqualByComparingTo("5000");
        assertThat(one("select used_count from promo_codes where code='FEYA10'", Integer.class)).isEqualTo(1);
        POST("/orders/" + o.text("id") + "/cancel", Map.of(), token);
        assertThat(one("select used_count from promo_codes where code='FEYA10'", Integer.class)).isEqualTo(0);

        // Per-user limit: WELCOME2000 can be used once per customer.
        Map<String, Object> w = new LinkedHashMap<>(orderRequest(List.of(line(v, 1))));
        w.put("promoCode", "WELCOME2000");
        assertThat(createOrder(token, w).status()).isEqualTo(201);
        Resp again = createOrder(token, w);
        assertThat(again.status()).isEqualTo(422);
        assertThat(again.text("code")).isEqualTo("PROMO_ALREADY_USED");
    }

    @Test
    void invalidPromoAtCheckoutFailsTheOrder() {
        String token = login(CUSTOMER);
        Map<String, Object> req = new LinkedHashMap<>(orderRequest(List.of(line(variantId("romantika", "STANDARD"), 1))));
        req.put("promoCode", "EXPIRED");
        Resp r = createOrder(token, req);
        assertThat(r.status()).isEqualTo(422);
        assertThat(r.text("code")).isEqualTo("PROMO_EXPIRED");
    }

    @Test
    void cancellingReturnsStock() {
        String token = login(CUSTOMER);
        int before = stock("Достык", "romantika", "STANDARD");
        Resp o = createOrder(token, List.of(line(variantId("romantika", "STANDARD"), 3)));
        assertThat(stock("Достык", "romantika", "STANDARD")).isEqualTo(before - 3);
        Resp c = POST("/orders/" + o.text("id") + "/cancel", Map.of("reason", "передумал"), token);
        assertThat(c.status()).isEqualTo(200);
        assertThat(c.text("status")).isEqualTo("CANCELLED");
        assertThat(stock("Достык", "romantika", "STANDARD")).isEqualTo(before);
        assertThat(POST("/orders/" + o.text("id") + "/cancel", Map.of(), token).status()).isEqualTo(409); // already final
    }

    @Test
    void customerMayStillCancelAConfirmedOrder() {
        String token = login(CUSTOMER);
        String id = paidOrder(token, List.of(line(variantId("romantika", "SMALL"), 1)));
        String florist = login(FLORIST_DOSTYK);
        POST("/florist/orders/" + id + "/accept", null, florist);
        Resp cancel = POST("/orders/" + id + "/cancel", Map.of(), token);
        assertThat(cancel.status()).isEqualTo(200);
        // A paid order is refunded immediately by the sandbox provider, which completes the cancellation flow.
        assertThat(cancel.text("status")).isEqualTo("REFUNDED");
        assertThat(cancel.text("paymentStatus")).isEqualTo("REFUNDED");
    }

    @Test
    void customerCannotCancelDuringPreparation() {
        String token = login(CUSTOMER);
        String id = paidOrder(token, List.of(line(variantId("romantika", "SMALL"), 1)));
        String florist = login(FLORIST_DOSTYK);
        POST("/florist/orders/" + id + "/accept", null, florist);
        POST("/florist/orders/" + id + "/preparing", null, florist);
        Resp r = POST("/orders/" + id + "/cancel", Map.of(), token);
        assertThat(r.status()).isEqualTo(403);
        assertThat(GET("/orders/" + id, token).text("status")).isEqualTo("PREPARING");
    }

    @Test
    void customersSeeOnlyTheirOwnOrders() {
        String owner = login(CUSTOMER);
        String other = login(OTHER_CUSTOMER);
        String id = createOrder(owner, List.of(line(variantId("romantika", "SMALL"), 1))).text("id");
        assertThat(GET("/orders/" + id, owner).status()).isEqualTo(200);
        assertThat(GET("/orders/" + id, other).status()).isEqualTo(404);
        assertThat(GET("/orders/" + id + "/tracking", other).status()).isEqualTo(404);
        assertThat(POST("/orders/" + id + "/cancel", Map.of(), other).status()).isEqualTo(404);
        assertThat(pay(other, id).status()).isEqualTo(404);
        assertThat(GET("/orders", other).body().get("content")).isEmpty();
        assertThat(GET("/orders", owner).body().get("content")).hasSize(1);
        assertThat(GET("/orders/" + id, null).status()).isEqualTo(401);
    }

    @Test
    void savedAddressOfAnotherCustomerCannotBeUsed() {
        String owner = login(CUSTOMER);
        String other = login(OTHER_CUSTOMER);
        String addressId = POST("/addresses", Map.of("city", "Алматы", "street", "Абая", "building", "1"), owner).text("id");
        Map<String, Object> req = new LinkedHashMap<>(orderRequest(List.of(line(variantId("romantika", "SMALL"), 1))));
        req.remove("address");
        req.put("addressId", addressId);
        assertThat(createOrder(other, req).status()).isEqualTo(404);
        assertThat(createOrder(owner, req).status()).isEqualTo(201);
    }

    @Test
    void unpaidOrdersExpireAndReleaseStock() {
        String token = login(CUSTOMER);
        int before = stock("Достык", "romantika", "SMALL");
        String id = createOrder(token, List.of(line(variantId("romantika", "SMALL"), 2))).text("id");
        assertThat(stock("Достык", "romantika", "SMALL")).isEqualTo(before - 2);
        clock.advance(Duration.ofMinutes(31));
        assertThat(orderService.expireUnpaidBefore(clock.instant().minus(Duration.ofMinutes(30)))).isEqualTo(1);
        assertThat(GET("/orders/" + id, token).text("status")).isEqualTo("CANCELLED");
        assertThat(stock("Достык", "romantika", "SMALL")).isEqualTo(before);
    }

    @Test
    void limitsConcurrentUnpaidOrders() {
        String token = login(CUSTOMER);
        UUID v = variantId("podarochnyj-mini", "SMALL");
        for (int i = 0; i < 3; i++) assertThat(createOrder(token, List.of(line(v, 1))).status()).isEqualTo(201);
        Resp r = createOrder(token, List.of(line(v, 1)));
        assertThat(r.status()).isEqualTo(409);
        assertThat(r.text("code")).isEqualTo("TOO_MANY_UNPAID_ORDERS");
    }

    @Test
    void checkoutSavesAddressWhenRequested() {
        String token = login(CUSTOMER);
        Map<String, Object> req = new LinkedHashMap<>(orderRequest(List.of(line(variantId("romantika", "SMALL"), 1))));
        req.put("address", Map.of("city", "Алматы", "street", "Сатпаева", "building", "22", "saveAddress", true));
        assertThat(createOrder(token, req).status()).isEqualTo(201);
        Resp list = GET("/addresses", token);
        assertThat(list.body()).hasSize(1);
        assertThat(list.body().get(0).get("street").asText()).isEqualTo("Сатпаева");
        assertThat(list.body().get(0).get("isDefault").asBoolean()).isTrue();
    }
}
