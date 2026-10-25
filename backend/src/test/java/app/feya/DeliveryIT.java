package app.feya;

import static org.assertj.core.api.Assertions.assertThat;

import app.feya.support.IntegrationTest;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class DeliveryIT extends IntegrationTest {

    @Test
    void zoneResolvesByCityNameAndByCoordinates() {
        assertThat(GET("/delivery/zones/resolve?city=Алматы", null).text("code")).isEqualTo("almaty-center");
        assertThat(GET("/delivery/zones/resolve?city=%D0%B3.%20Almaty", null).status()).isEqualTo(200);
        // Coordinates inside the 7 km centre radius pick the central zone, farther out the city-wide zone.
        assertThat(GET("/delivery/zones/resolve?lat=43.2389&lng=76.9455", null).text("code")).isEqualTo("almaty-center");
        assertThat(GET("/delivery/zones/resolve?lat=43.35&lng=77.1", null).text("code")).isEqualTo("almaty-city");
    }

    @Test
    void undeliverableLocationsAreRejected() {
        assertThat(GET("/delivery/zones/resolve?city=Астана", null).status()).isEqualTo(422);
        Resp far = GET("/delivery/zones/resolve?lat=51.1694&lng=71.4491", null); // Astana
        assertThat(far.status()).isEqualTo(422);
        assertThat(far.text("code")).isEqualTo("NOT_DELIVERABLE");
        assertThat(GET("/delivery/zones/resolve?lat=95&lng=10", null).status()).isEqualTo(400);
        assertThat(GET("/delivery/zones/resolve?lat=43.2", null).status()).isEqualTo(400);
    }

    @Test
    void slotsRespectCutoffAndOnlyAvailableOnesAreOffered() {
        // Now is Monday 11:00 Almaty. 10:00 started; 12:00 is inside the 2h cutoff; 14:00 and later are bookable.
        Resp r = GET("/delivery/slots?days=2", null);
        var today = r.body().get("days").get(0).get("slots");
        assertThat(today.get(0).get("unavailableReason").asText()).isEqualTo("PAST_CUTOFF");
        assertThat(today.get(1).get("unavailableReason").asText()).isEqualTo("PAST_CUTOFF");
        assertThat(today.get(2).get("available").asBoolean()).isTrue();
        assertThat(r.body().get("days").get(1).get("slots").get(0).get("available").asBoolean()).isTrue();
        assertThat(r.body().get("timezone").asText()).isEqualTo("Asia/Almaty");
    }

    @Test
    void asapIsOnlyOfferedInsideWorkingHours() {
        assertThat(GET("/delivery/slots?days=1", null).body().get("asapAvailable").asBoolean()).isTrue(); // 11:00
        clock.set(Instant.parse("2026-11-02T15:30:00Z")); // 20:30 Almaty: +90 min exceeds the 21:00 close
        assertThat(GET("/delivery/slots?days=1", null).body().get("asapAvailable").asBoolean()).isFalse();
        clock.set(Instant.parse("2026-11-02T02:00:00Z")); // 07:00 Almaty: before opening
        assertThat(GET("/delivery/slots?days=1", null).body().get("asapAvailable").asBoolean()).isFalse();
    }

    @Test
    void orderingAsapOutsideWorkingHoursFails() {
        String token = login(CUSTOMER);
        clock.set(Instant.parse("2026-11-02T15:30:00Z"));
        Map<String, Object> req = new java.util.LinkedHashMap<>(orderRequest(List.of(line(variantId("romantika", "SMALL"), 1))));
        req.remove("slot");
        req.put("asap", true);
        Resp r = createOrder(token, req);
        assertThat(r.status()).isEqualTo(422);
        assertThat(r.text("code")).isEqualTo("ASAP_UNAVAILABLE");
    }

    @Test
    void pastAndTooDistantAndCutoffSlotsAreRejected() {
        String token = login(CUSTOMER);
        UUID tpl = templateId("almaty-center", "12:00");
        UUID v = variantId("romantika", "SMALL");
        assertThat(orderWithSlot(token, v, tpl, "2026-11-01").text("code")).isEqualTo("SLOT_INVALID_DATE"); // yesterday
        assertThat(orderWithSlot(token, v, tpl, "2026-12-30").text("code")).isEqualTo("SLOT_INVALID_DATE"); // > 14 days
        assertThat(orderWithSlot(token, v, tpl, "2026-11-02").text("code")).isEqualTo("SLOT_PAST_CUTOFF"); // today 12:00
        assertThat(orderWithSlot(token, v, UUID.randomUUID(), "2026-11-03").text("code")).isEqualTo("SLOT_UNAVAILABLE");
    }

    @Test
    void slotCapacityIsEnforced() {
        UUID tpl = templateId("almaty-center", "12:00");
        sql("update delivery_slot_templates set capacity = 1 where id = ?", tpl);
        UUID v = variantId("romantika", "SMALL");
        String a = login(CUSTOMER);
        String b = login(OTHER_CUSTOMER);
        assertThat(orderWithSlot(a, v, tpl, "2026-11-03").status()).isEqualTo(201);
        Resp full = orderWithSlot(b, v, tpl, "2026-11-03");
        assertThat(full.status()).isEqualTo(422);
        assertThat(full.text("code")).isEqualTo("SLOT_FULL");
        // The slot shows as full to everybody.
        var slots = GET("/delivery/slots?days=2", null).body().get("days").get(1).get("slots");
        assertThat(slots.get(1).get("available").asBoolean()).isFalse();
        assertThat(slots.get(1).get("unavailableReason").asText()).isEqualTo("FULL");
        // A cancelled order frees the slot again.
        String id = one("select id::text from orders order by created_at desc limit 1", String.class);
        assertThat(POST("/orders/" + id + "/cancel", Map.of(), a).status()).isEqualTo(200);
        assertThat(orderWithSlot(b, v, tpl, "2026-11-03").status()).isEqualTo(201);
    }

    @Test
    void deliveryOutsideServedAreaIsRejectedAtCheckout() {
        String token = login(CUSTOMER);
        Map<String, Object> req = new java.util.LinkedHashMap<>(orderRequest(List.of(line(variantId("romantika", "SMALL"), 1))));
        req.put("address", Map.of("city", "Астана", "street", "Кенесары", "building", "1"));
        Resp r = createOrder(token, req);
        assertThat(r.status()).isEqualTo(422);
        assertThat(r.text("code")).isEqualTo("NOT_DELIVERABLE");
    }

    private Resp orderWithSlot(String token, UUID variant, UUID tpl, String date) {
        Map<String, Object> req = new java.util.LinkedHashMap<>(orderRequest(List.of(line(variant, 1))));
        req.put("slot", Map.of("templateId", tpl, "date", date));
        return createOrder(token, req);
    }
}
