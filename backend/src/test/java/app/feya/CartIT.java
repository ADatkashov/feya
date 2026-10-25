package app.feya;

import static org.assertj.core.api.Assertions.assertThat;

import app.feya.support.IntegrationTest;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class CartIT extends IntegrationTest {

    private Resp quote(Map<String, Object> body) {
        return POST("/cart/quote", body, null);
    }

    @Test
    void pricesComeFromTheDatabaseAndTotalsAddUp() {
        UUID v = variantId("magiya-chuvstv", "STANDARD"); // 23 900
        Resp r = quote(Map.of("items", List.of(line(v, 2)), "slot", tomorrowSlot()));
        assertThat(r.status()).isEqualTo(200);
        assertThat(r.body().get("subtotal").decimalValue()).isEqualByComparingTo("47800");
        assertThat(r.body().get("discount").decimalValue()).isEqualByComparingTo("0");
        // 47 800 is above the 25 000 free-delivery threshold of the central zone.
        assertThat(r.body().get("deliveryFee").decimalValue()).isEqualByComparingTo("0");
        assertThat(r.body().get("total").decimalValue()).isEqualByComparingTo("47800");
        assertThat(r.body().get("valid").asBoolean()).isTrue();
    }

    @Test
    void deliveryFeeAppliesBelowFreeThresholdAndSlotSurchargeIsAdded() {
        UUID v = variantId("podarochnyj-mini", "SMALL"); // 7 900
        Resp r = quote(Map.of("items", List.of(line(v, 1)), "slot", tomorrowSlot()));
        assertThat(r.body().get("deliveryFee").decimalValue()).isEqualByComparingTo("1500");
        assertThat(r.body().get("total").decimalValue()).isEqualByComparingTo("9400");
        Resp evening = quote(Map.of("items", List.of(line(v, 1)),
                "slot", Map.of("templateId", templateId("almaty-center", "18:00"), "date", "2026-11-03")));
        assertThat(evening.body().get("deliveryFee").decimalValue()).isEqualByComparingTo("2000"); // 1500 + 500 surcharge
    }

    @Test
    void percentPromoIsCappedAndFixedPromoRespectsMinimum() {
        UUID big = variantId("alyj-barhat", "LARGE"); // 89 900 -> 10% = 8 990 capped at 5 000
        Resp r = quote(Map.of("items", List.of(line(big, 1)), "promoCode", "feya10"));
        assertThat(r.body().get("promo").get("applied").asBoolean()).isTrue();
        assertThat(r.body().get("discount").decimalValue()).isEqualByComparingTo("5000");

        UUID small = variantId("podarochnyj-mini", "SMALL"); // 7 900 < 15 000 minimum for WELCOME2000
        Resp low = quote(Map.of("items", List.of(line(small, 1)), "promoCode", "WELCOME2000"));
        assertThat(low.body().get("promo").get("applied").asBoolean()).isFalse();
        assertThat(low.body().get("promo").get("error").asText()).isEqualTo("PROMO_MIN_ORDER");
        assertThat(low.body().get("discount").decimalValue()).isEqualByComparingTo("0");
    }

    @Test
    void invalidAndExpiredPromosAreReportedWithoutFailingTheQuote() {
        UUID v = variantId("romantika", "STANDARD");
        Resp expired = quote(Map.of("items", List.of(line(v, 1)), "promoCode", "EXPIRED"));
        assertThat(expired.status()).isEqualTo(200);
        assertThat(expired.body().get("promo").get("error").asText()).isEqualTo("PROMO_EXPIRED");
        Resp unknown = quote(Map.of("items", List.of(line(v, 1)), "promoCode", "NOPE"));
        assertThat(unknown.body().get("promo").get("error").asText()).isEqualTo("PROMO_NOT_FOUND");
    }

    @Test
    void giftWrapAddsConfiguredFee() {
        UUID v = variantId("romantika", "STANDARD"); // 21 900
        Resp r = quote(Map.of("items", List.of(line(v, 1)), "giftWrap", true));
        assertThat(r.body().get("giftWrapFee").decimalValue()).isEqualByComparingTo("1500");
        // 21 900 + 1 500 delivery (below 25 000) + 1 500 gift wrap
        assertThat(r.body().get("total").decimalValue()).isEqualByComparingTo("24900");
    }

    @Test
    void duplicateLinesAreMergedAndQuantityIsValidatedAgainstStock() {
        UUID premium = variantId("alyj-barhat", "PREMIUM"); // only 2 in stock
        Resp r = quote(Map.of("items", List.of(line(premium, 1), line(premium, 2))));
        assertThat(r.status()).isEqualTo(200);
        assertThat(r.body().get("lines")).hasSize(1);
        assertThat(r.body().get("lines").get(0).get("quantity").asInt()).isEqualTo(3);
        assertThat(r.body().get("valid").asBoolean()).isFalse();
        assertThat(r.body().get("lines").get(0).get("issue").asText()).isEqualTo("INSUFFICIENT_STOCK");
        assertThat(r.body().get("lines").get(0).get("maxQuantity").asInt()).isEqualTo(2);
    }

    @Test
    void unavailableItemIsFlagged() {
        UUID v = variantId("osennyaya-simfoniya", "STANDARD");
        Resp r = quote(Map.of("items", List.of(line(v, 1))));
        assertThat(r.body().get("valid").asBoolean()).isFalse();
        assertThat(r.body().get("lines").get(0).get("issue").asText()).isEqualTo("UNAVAILABLE");
        assertThat(r.body().get("lines").get(0).get("available").asBoolean()).isFalse();
    }

    @Test
    void rejectsInvalidQuantitiesAndUnknownVariantsAndAmbiguousDelivery() {
        UUID v = variantId("romantika", "STANDARD");
        assertThat(quote(Map.of("items", List.of(line(v, 0)))).status()).isEqualTo(400);
        assertThat(quote(Map.of("items", List.of(line(v, 100)))).status()).isEqualTo(400);
        assertThat(quote(Map.of("items", List.of())).status()).isEqualTo(400);
        assertThat(quote(Map.of("items", List.of(line(v, 21)))).body().get("valid").asBoolean()).isFalse(); // over line limit
        assertThat(quote(Map.of("items", List.of(line(UUID.randomUUID(), 1)))).status()).isEqualTo(422);
        assertThat(quote(Map.of("items", List.of(line(v, 1)), "asap", true, "slot", tomorrowSlot())).status()).isEqualTo(400);
    }

    @Test
    void clientCannotInjectPrices() {
        UUID v = variantId("romantika", "STANDARD");
        Resp r = quote(Map.of("items", List.of(Map.of("variantId", v, "quantity", 1, "price", 1, "unitPrice", 1)), "total", 1));
        assertThat(r.body().get("lines").get(0).get("unitPrice").decimalValue()).isEqualByComparingTo("21900");
        assertThat(r.body().get("subtotal").decimalValue()).isEqualByComparingTo("21900");
    }
}
