package app.feya;

import static org.assertj.core.api.Assertions.assertThat;

import app.feya.support.IntegrationTest;
import java.util.stream.StreamSupport;
import org.junit.jupiter.api.Test;

class CatalogIT extends IntegrationTest {

    @Test
    void listsOnlyAvailableProductsPaginated() {
        Resp page1 = GET("/products?size=5&page=0", null);
        assertThat(page1.status()).isEqualTo(200);
        assertThat(page1.body().get("content")).hasSize(5);
        assertThat(page1.body().get("hasNext").asBoolean()).isTrue();
        // "Осенняя симфония" has no stock anywhere, so it is hidden from the default (available-only) listing.
        Resp all = GET("/products?size=50", null);
        assertThat(names(all)).doesNotContain("Осенняя симфония").contains("Магия чувств");
        Resp withUnavailable = GET("/products?size=50&availableOnly=false", null);
        assertThat(names(withUnavailable)).contains("Осенняя симфония");
    }

    @Test
    void searchFindsProductsInAnyLanguageAndIsCaseInsensitive() {
        assertThat(names(GET("/products?q=ПИОН", null))).contains("Пионовое облако", "Королевский пион");
        assertThat(names(GET("/products?q=tulip&lang=en", null))).contains("Spring Tulips");
        assertThat(names(GET("/products?q=қызғалдақ", null))).contains("Тюльпаны весенние");
        assertThat(GET("/products?q=%25%25", null).body().get("content")).isEmpty(); // wildcard is escaped
    }

    @Test
    void filtersByCategoryAndSortsByPrice() {
        Resp roses = GET("/products?category=roses&size=50", null);
        assertThat(names(roses)).containsExactlyInAnyOrder("Романтика", "Белая классика", "Розы «Эквадор» 25");
        Resp asc = GET("/products?sort=price_asc&size=50", null);
        double prev = 0;
        for (var p : asc.body().get("content")) {
            assertThat(p.get("priceFrom").asDouble()).isGreaterThanOrEqualTo(prev);
            prev = p.get("priceFrom").asDouble();
        }
        assertThat(GET("/products?sort=nonsense", null).status()).isEqualTo(400);
    }

    @Test
    void detailReturnsServerSidePricesAndPerVariantAvailability() {
        Resp d = GET("/products/alyj-barhat", null);
        assertThat(d.status()).isEqualTo(200);
        var variants = StreamSupport.stream(d.body().get("variants").spliterator(), false).toList();
        assertThat(variants).extracting(v -> v.get("code").asText()).containsExactly("STANDARD", "LARGE", "PREMIUM");
        assertThat(variants.get(0).get("price").decimalValue()).isEqualByComparingTo("54900");
        // The premium variant is stocked in a single shop only, with 2 units.
        assertThat(variants.get(2).get("available").asBoolean()).isTrue();
        assertThat(variants.get(2).get("maxQuantity").asInt()).isEqualTo(2);
        assertThat(d.body().get("images")).isNotEmpty();
    }

    @Test
    void unavailableProductDetailIsMarkedUnavailable() {
        Resp d = GET("/products/osennyaya-simfoniya", null);
        assertThat(d.status()).isEqualTo(200);
        assertThat(d.body().get("available").asBoolean()).isFalse();
        d.body().get("variants").forEach(v -> assertThat(v.get("available").asBoolean()).isFalse());
    }

    @Test
    void availabilityDependsOnTheFloristServingTheZone() {
        // Royal peony is stocked only by the Dostyk florist, which serves both zones; the whole-city zone is served by
        // Dostyk alone, while "Белая классика" is also Dostyk-only. Both stay available in both zones.
        String cityZone = one("select id::text from delivery_zones where code='almaty-city'", String.class);
        assertThat(names(GET("/products?size=50&zoneId=" + cityZone, null))).contains("Королевский пион");
        // Make the Dostyk florist inactive: nothing is deliverable to the whole-city zone any more.
        sql("update florists set active=false where name like '%Достык%'");
        assertThat(GET("/products?size=50&zoneId=" + cityZone, null).body().get("content")).isEmpty();
    }

    @Test
    void homeContainsBannersAndSections() {
        Resp home = GET("/home", null);
        assertThat(home.status()).isEqualTo(200);
        assertThat(home.body().get("banners")).hasSize(3);
        assertThat(home.body().get("categories")).hasSize(7);
        assertThat(home.body().get("featured")).isNotEmpty();
        assertThat(home.body().get("newArrivals")).isNotEmpty();
    }

    @Test
    void localizedFieldsFollowLanguageWithRussianFallback() {
        assertThat(GET("/products/romantika?lang=kk", null).text("name")).isEqualTo("Романтика");
        assertThat(GET("/products/magiya-chuvstv?lang=kk", null).text("name")).isEqualTo("Сезім сиқыры");
        assertThat(GET("/products/magiya-chuvstv?lang=en", null).text("name")).isEqualTo("Magic of Feelings");
        assertThat(GET("/categories?lang=en", null).body().get(0).get("name").asText()).isEqualTo("Roses");
    }

    @Test
    void unknownProductIs404() {
        assertThat(GET("/products/does-not-exist", null).status()).isEqualTo(404);
    }

    private static java.util.List<String> names(Resp r) {
        return StreamSupport.stream(r.body().get("content").spliterator(), false).map(p -> p.get("name").asText()).toList();
    }
}
