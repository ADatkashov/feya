package app.feya;

import static org.assertj.core.api.Assertions.assertThat;

import app.feya.support.IntegrationTest;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

class TrackingIT extends IntegrationTest {

    private String readyForPickupOrder(String customer) {
        String id = paidOrder(customer, List.of(line(variantId("romantika", "SMALL"), 1)));
        String florist = login(FLORIST_DOSTYK);
        POST("/florist/orders/" + id + "/accept", null, florist);
        POST("/florist/orders/" + id + "/preparing", null, florist);
        POST("/florist/orders/" + id + "/ready", null, florist);
        return id;
    }

    @Test
    void noCourierMeansNoCourierAndNoInventedLocation() {
        String customer = login(CUSTOMER);
        String id = paidOrder(customer, List.of(line(variantId("romantika", "SMALL"), 1)));
        Resp t = GET("/orders/" + id + "/tracking", customer);
        assertThat(t.status()).isEqualTo(200);
        assertThat(t.text("status")).isEqualTo("PAID");
        assertThat(t.body().has("courier")).isFalse();
        assertThat(t.body().has("courierLocation")).isFalse();
        assertThat(t.body().get("liveTracking").asBoolean()).isFalse();
        assertThat(t.body().get("timeline")).hasSizeGreaterThanOrEqualTo(3);
    }

    @Test
    void liveLocationAppearsOnlyWhileSharingIsOnAndFresh() {
        String customer = login(CUSTOMER);
        String id = readyForPickupOrder(customer);
        String courier = login(COURIER);
        // Location posts are refused until the courier is on shift and sharing.
        assertThat(POST("/courier/location", Map.of("latitude", 43.2, "longitude", 76.9), courier).status()).isEqualTo(409);
        PUT("/courier/shift", Map.of("onShift", true, "locationSharing", true), courier);
        assertThat(POST("/courier/orders/" + id + "/claim", null, courier).status()).isEqualTo(200);

        Resp assigned = GET("/orders/" + id + "/tracking", customer);
        assertThat(assigned.body().get("courier").get("name").asText()).isEqualTo("Алексей К.");
        assertThat(assigned.body().get("liveTracking").asBoolean()).isFalse(); // not picked up yet

        POST("/courier/orders/" + id + "/status", Map.of("status", "PICKED_UP"), courier);
        POST("/courier/orders/" + id + "/status", Map.of("status", "ON_THE_WAY"), courier);
        assertThat(POST("/courier/location", Map.of("latitude", 43.25, "longitude", 76.95, "orderId", id,
                "recordedAt", clock.instant().toString()), courier).status()).isEqualTo(200);
        Resp live = GET("/orders/" + id + "/tracking", customer);
        assertThat(live.body().get("liveTracking").asBoolean()).isTrue();
        assertThat(live.body().get("courierLocation").get("latitude").decimalValue()).isEqualByComparingTo("43.25");

        // A stale position is not shown as live.
        clock.advance(Duration.ofMinutes(6));
        assertThat(GET("/orders/" + id + "/tracking", customer).body().get("liveTracking").asBoolean()).isFalse();

        // Fresh again, but the courier turns sharing off: nothing is shown.
        POST("/courier/location", Map.of("latitude", 43.26, "longitude", 76.96, "orderId", id), courier);
        assertThat(GET("/orders/" + id + "/tracking", customer).body().get("liveTracking").asBoolean()).isTrue();
        PUT("/courier/shift", Map.of("onShift", true, "locationSharing", false), courier);
        assertThat(GET("/orders/" + id + "/tracking", customer).body().get("liveTracking").asBoolean()).isFalse();
    }

    @Test
    void invalidLocationPayloadsAreRejected() {
        String courier = login(COURIER);
        PUT("/courier/shift", Map.of("onShift", true, "locationSharing", true), courier);
        assertThat(POST("/courier/location", Map.of("latitude", 200, "longitude", 10), courier).status()).isEqualTo(400);
        assertThat(POST("/courier/location", Map.of("latitude", 10), courier).status()).isEqualTo(400);
        assertThat(POST("/courier/location", Map.of("latitude", 43.2, "longitude", 76.9,
                "recordedAt", clock.instant().plus(Duration.ofHours(1)).toString()), courier).status()).isEqualTo(400);
        assertThat(POST("/courier/location", Map.of("latitude", 43.2, "longitude", 76.9,
                "recordedAt", clock.instant().minus(Duration.ofMinutes(30)).toString()), courier).status()).isEqualTo(400);
    }

    @Test
    void courierLocationForSomeoneElsesOrderIsRejected() {
        String customer = login(CUSTOMER);
        String id = readyForPickupOrder(customer);
        String courier = login(COURIER);
        PUT("/courier/shift", Map.of("onShift", true, "locationSharing", true), courier);
        // Not assigned to this courier.
        assertThat(POST("/courier/location", Map.of("latitude", 43.2, "longitude", 76.9, "orderId", id), courier).status()).isEqualTo(404);
    }

    @Test
    void recipientDetailsAreOnlyReleasedToTheAssignedCourier() {
        String customer = login(CUSTOMER);
        String id = readyForPickupOrder(customer);
        String courier = login(COURIER);
        PUT("/courier/shift", Map.of("onShift", true, "locationSharing", false), courier);
        var available = GET("/courier/orders?scope=available", courier).body().get("content");
        assertThat(available).hasSize(1);
        assertThat(available.get(0).has("recipientPhone")).isFalse();
        POST("/courier/orders/" + id + "/claim", null, courier);
        var mine = GET("/courier/orders?scope=mine", courier).body().get("content");
        assertThat(mine.get(0).get("recipientPhone").asText()).isEqualTo("+77011234567");
    }

    @Test
    void courierGoingOffShiftStopsSharing() {
        String courier = login(COURIER);
        PUT("/courier/shift", Map.of("onShift", true, "locationSharing", true), courier);
        Resp off = PUT("/courier/shift", Map.of("onShift", false, "locationSharing", true), courier);
        assertThat(off.body().get("locationSharing").asBoolean()).isFalse();
    }
}
