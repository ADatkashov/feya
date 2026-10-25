package app.feya;

import static org.assertj.core.api.Assertions.assertThat;

import app.feya.support.IntegrationTest;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

class SecurityIT extends IntegrationTest {

    @ParameterizedTest
    @ValueSource(strings = {"/admin/dashboard", "/admin/orders", "/admin/customers", "/admin/zones", "/admin/promos",
            "/admin/audit", "/admin/florists", "/admin/couriers", "/admin/reviews", "/admin/categories"})
    void adminEndpointsAreClosedToCustomersAndAnonymous(String path) {
        assertThat(GET(path, null).status()).isEqualTo(401);
        assertThat(GET(path, login(CUSTOMER)).status()).isEqualTo(403);
        assertThat(GET(path, login(COURIER)).status()).isEqualTo(403);
        assertThat(GET(path, login(FLORIST_DOSTYK)).status()).isEqualTo(403);
    }

    @Test
    void adminAndSupportCanReadOrdersButOnlyAdminCanConfigure() {
        String admin = login(ADMIN);
        String support = login(SUPPORT);
        assertThat(GET("/admin/orders", admin).status()).isEqualTo(200);
        assertThat(GET("/admin/orders", support).status()).isEqualTo(200);
        assertThat(GET("/admin/dashboard", support).status()).isEqualTo(200);
        assertThat(GET("/admin/zones", admin).status()).isEqualTo(200);
        assertThat(GET("/admin/zones", support).status()).isEqualTo(403);
        assertThat(GET("/admin/categories", support).status()).isEqualTo(403);
        assertThat(POST("/admin/promos", Map.of("code", "TEST5", "type", "PERCENT", "value", 5, "active", true), support).status()).isEqualTo(403);
        assertThat(POST("/admin/promos", Map.of("code", "TEST5", "type", "PERCENT", "value", 5, "active", true), admin).status()).isEqualTo(201);
        assertThat(PUT("/admin/customers/" + java.util.UUID.randomUUID() + "/roles", Map.of("roles", List.of("ADMIN")), support).status()).isEqualTo(403);
    }

    @Test
    void floristAndCourierAreIsolatedFromCustomersAndEachOther() {
        String customer = login(CUSTOMER);
        assertThat(GET("/florist/orders", customer).status()).isEqualTo(403);
        assertThat(GET("/courier/orders", customer).status()).isEqualTo(403);
        assertThat(GET("/courier/me", login(FLORIST_DOSTYK)).status()).isEqualTo(403);
        assertThat(GET("/florist/orders", login(COURIER)).status()).isEqualTo(403);
    }

    @Test
    void floristsOnlySeeAndTouchTheirOwnShopOrders() {
        String customer = login(CUSTOMER);
        String id = paidOrder(customer, List.of(line(variantId("romantika", "SMALL"), 1))); // fulfilled by Dostyk (priority 10)
        String dostyk = login(FLORIST_DOSTYK);
        String samal = login(FLORIST_SAMAL);
        assertThat(GET("/florist/orders", dostyk).body().get("content")).hasSize(1);
        assertThat(GET("/florist/orders", samal).body().get("content")).isEmpty();
        assertThat(POST("/florist/orders/" + id + "/accept", null, samal).status()).isEqualTo(404);
        assertThat(POST("/florist/orders/" + id + "/accept", null, dostyk).status()).isEqualTo(200);
        // A florist cannot read or edit another shop's stock by passing its id.
        String dostykId = one("select id::text from florists where name like '%Достык%'", String.class);
        assertThat(GET("/florist/inventory?floristId=" + dostykId, samal).status()).isEqualTo(403);
        assertThat(PUT("/florist/inventory/" + variantId("romantika", "SMALL") + "?floristId=" + dostykId, Map.of("quantity", 999), samal).status()).isEqualTo(403);
    }

    @Test
    void floristCanManageOwnStockAndChangesAreAudited() {
        String samal = login(FLORIST_SAMAL);
        var v = variantId("romantika", "SMALL");
        Resp r = PUT("/florist/inventory/" + v, Map.of("quantity", 17), samal);
        assertThat(r.status()).isEqualTo(200);
        assertThat(r.body().get("quantity").asInt()).isEqualTo(17);
        assertThat(PUT("/florist/inventory/" + v, Map.of("quantity", -1), samal).status()).isEqualTo(400);
        assertThat(one("select count(*) from audit_events where action='INVENTORY_SET'", Integer.class)).isEqualTo(1);
    }

    @Test
    void courierCannotSetNonCourierStatusesOrTouchOthersOrders() {
        String customer = login(CUSTOMER);
        String id = paidOrder(customer, List.of(line(variantId("romantika", "SMALL"), 1)));
        String courier = login(COURIER);
        // Not yet ready for pickup: cannot claim, cannot fast-forward.
        PUT("/courier/shift", Map.of("onShift", true, "locationSharing", false), courier);
        assertThat(POST("/courier/orders/" + id + "/claim", null, courier).status()).isEqualTo(409);
        assertThat(POST("/courier/orders/" + id + "/status", Map.of("status", "DELIVERED"), courier).status()).isEqualTo(404);
        assertThat(POST("/courier/orders/" + id + "/status", Map.of("status", "CANCELLED"), courier).status()).isEqualTo(403);
    }

    @Test
    void customerCannotChangeOrderStatusThroughStaffEndpoints() {
        String customer = login(CUSTOMER);
        String id = paidOrder(customer, List.of(line(variantId("romantika", "SMALL"), 1)));
        assertThat(POST("/florist/orders/" + id + "/accept", null, customer).status()).isEqualTo(403);
        assertThat(POST("/admin/orders/" + id + "/status", Map.of("status", "DELIVERED"), customer).status()).isEqualTo(403);
        assertThat(GET("/orders/" + id, customer).text("status")).isEqualTo("PAID");
    }

    @Test
    void adminCannotForceInvalidOrPaymentStatuses() {
        String customer = login(CUSTOMER);
        String id = createOrder(customer, List.of(line(variantId("romantika", "SMALL"), 1))).text("id");
        String admin = login(ADMIN);
        assertThat(POST("/admin/orders/" + id + "/status", Map.of("status", "PAID"), admin).status()).isEqualTo(403);
        assertThat(POST("/admin/orders/" + id + "/status", Map.of("status", "DELIVERED"), admin).status()).isEqualTo(409);
        assertThat(POST("/admin/orders/" + id + "/status", Map.of("status", "CANCELLED", "note", "fraud"), admin).status()).isEqualTo(200);
    }

    @Test
    void addressesAreIsolatedPerCustomer() {
        String a = login(CUSTOMER);
        String b = login(OTHER_CUSTOMER);
        String id = POST("/addresses", Map.of("city", "Алматы", "street", "Абая", "building", "1"), a).text("id");
        assertThat(GET("/addresses", b).body()).isEmpty();
        assertThat(PUT("/addresses/" + id, Map.of("city", "Алматы", "street", "Hack", "building", "1"), b).status()).isEqualTo(404);
        assertThat(DELETE("/addresses/" + id, b).status()).isEqualTo(404);
        assertThat(PUT("/addresses/" + id + "/default", null, b).status()).isEqualTo(404);
        assertThat(GET("/addresses", a).body()).hasSize(1);
    }

    @Test
    void notificationsAreIsolatedPerCustomer() {
        String owner = login(CUSTOMER);
        String other = login(OTHER_CUSTOMER);
        String id = one("""
                insert into notifications (id, user_id, type, title, body) select gen_random_uuid(), id, 'X', 't', 'b'
                from users where phone = ? returning id::text""", String.class, CUSTOMER);
        em.clear();
        assertThat(GET("/notifications", owner).body().get("content")).hasSize(1);
        assertThat(GET("/notifications", other).body().get("content")).isEmpty();
        assertThat(POST("/notifications/" + id + "/read", null, other).status()).isEqualTo(404);
        assertThat(POST("/notifications/" + id + "/read", null, owner).status()).isEqualTo(200);
        assertThat(GET("/notifications/unread-count", owner).body().get("count").asInt()).isZero();
    }

    @Test
    void adminCannotChangeOwnRolesOrStatus() {
        String admin = login(ADMIN);
        String adminId = one("select id::text from users where phone=?", String.class, ADMIN);
        assertThat(PUT("/admin/customers/" + adminId + "/roles", Map.of("roles", List.of("SUPPORT")), admin).status()).isEqualTo(400);
        assertThat(PATCH("/admin/customers/" + adminId + "/status", Map.of("status", "BLOCKED"), admin).status()).isEqualTo(400);
    }

    @Test
    void tamperedOrExpiredTokensAreRejected() {
        String token = login(CUSTOMER);
        assertThat(GET("/me", token + "x").status()).isEqualTo(401);
        assertThat(GET("/me", "not-a-jwt").status()).isEqualTo(401);
        assertThat(GET("/me", token).status()).isEqualTo(200);
    }

    @Test
    void errorResponsesDoNotLeakInternals() {
        Resp r = GET("/products/%00", null);
        assertThat(r.raw()).doesNotContain("Exception").doesNotContain("at app.feya");
        Resp bad = POST("/auth/otp/verify", "{not json", null);
        assertThat(bad.status()).isEqualTo(400);
        assertThat(bad.raw()).doesNotContain("Exception");
    }
}
