package app.feya;

import static org.assertj.core.api.Assertions.assertThat;

import app.feya.support.IntegrationTest;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class ReviewFavoriteIT extends IntegrationTest {

    private String deliveredOrderFor(String token, String slug) {
        String id = paidOrder(token, List.of(line(variantId(slug, "STANDARD"), 1)));
        sql("update orders set status='DELIVERED', delivered_at=now() where id=?::uuid", id);
        return id;
    }

    @Test
    void favoritesCanBeAddedListedAndRemoved() {
        String token = login(CUSTOMER);
        UUID p = productId("romantika");
        assertThat(PUT("/favorites/" + p, null, token).status()).isEqualTo(204);
        assertThat(PUT("/favorites/" + p, null, token).status()).isEqualTo(204); // idempotent
        assertThat(GET("/favorites", token).body()).hasSize(1);
        assertThat(GET("/products/romantika", token).body().get("favorite").asBoolean()).isTrue();
        assertThat(GET("/products/romantika", null).body().get("favorite").asBoolean()).isFalse();
        var summary = GET("/products?category=roses", token).body().get("content");
        boolean flagged = false;
        for (var s : summary) if (s.get("slug").asText().equals("romantika")) flagged = s.get("favorite").asBoolean();
        assertThat(flagged).isTrue();
        assertThat(DELETE("/favorites/" + p, token).status()).isEqualTo(204);
        assertThat(GET("/favorites", token).body()).isEmpty();
        assertThat(PUT("/favorites/" + UUID.randomUUID(), null, token).status()).isEqualTo(404);
        assertThat(GET("/favorites", null).status()).isEqualTo(401);
    }

    @Test
    void favoritesStayVisibleWhenOutOfStockButMarkedUnavailable() {
        String token = login(CUSTOMER);
        PUT("/favorites/" + productId("osennyaya-simfoniya"), null, token);
        var list = GET("/favorites", token).body();
        assertThat(list).hasSize(1);
        assertThat(list.get(0).get("available").asBoolean()).isFalse();
    }

    @Test
    void onlyCustomersWhoReceivedTheProductCanReview() {
        String token = login(CUSTOMER);
        UUID p = productId("romantika");
        Resp denied = POST("/products/" + p + "/reviews", Map.of("rating", 5, "text", "Класс"), token);
        assertThat(denied.status()).isEqualTo(403);
        // An order that is merely paid (not delivered) is not enough.
        paidOrder(token, List.of(line(variantId("romantika", "STANDARD"), 1)));
        assertThat(POST("/products/" + p + "/reviews", Map.of("rating", 5), token).status()).isEqualTo(403);
    }

    @Test
    void verifiedReviewUpdatesAggregateRatingOnce() {
        String token = login(CUSTOMER);
        deliveredOrderFor(token, "romantika");
        UUID p = productId("romantika");
        Resp r = POST("/products/" + p + "/reviews", Map.of("rating", 4, "text", "Красивые"), token);
        assertThat(r.status()).isEqualTo(201);
        assertThat(r.body().get("verified").asBoolean()).isTrue();
        assertThat(POST("/products/" + p + "/reviews", Map.of("rating", 5), token).status()).isEqualTo(409);
        Resp d = GET("/products/romantika", null);
        assertThat(d.body().get("ratingCount").asInt()).isEqualTo(1);
        assertThat(d.body().get("ratingAvg").decimalValue()).isEqualByComparingTo("4.00");
        Resp list = GET("/products/" + p + "/reviews", null);
        assertThat(list.body().get("content")).hasSize(1);
        assertThat(list.body().get("content").get(0).get("author").asText()).doesNotContain("+7");
    }

    @Test
    void ratingMustBeBetweenOneAndFive() {
        String token = login(CUSTOMER);
        deliveredOrderFor(token, "romantika");
        UUID p = productId("romantika");
        assertThat(POST("/products/" + p + "/reviews", Map.of("rating", 0), token).status()).isEqualTo(400);
        assertThat(POST("/products/" + p + "/reviews", Map.of("rating", 6), token).status()).isEqualTo(400);
        assertThat(POST("/products/" + p + "/reviews", Map.of("rating", 5, "text", "x".repeat(2001)), token).status()).isEqualTo(400);
    }

    @Test
    void reviewsArePaginatedAndHiddenOnesDisappearFromRatings() {
        // Seed three published reviews directly (users, orders not required for pagination logic).
        UUID p = productId("belaya-klassika");
        for (int i = 0; i < 3; i++) {
            String phone = "+7702000000" + i;
            sql("insert into users (id, phone) values (gen_random_uuid(), ?)", phone);
            sql("insert into reviews (id, product_id, user_id, rating, text, verified) select gen_random_uuid(), ?, id, ?, 'ok', true from users where phone=?",
                    p, 3 + i, phone);
        }
        Resp page = GET("/products/" + p + "/reviews?size=2&page=0", null);
        assertThat(page.body().get("content")).hasSize(2);
        assertThat(page.body().get("totalElements").asInt()).isEqualTo(3);
        assertThat(page.body().get("hasNext").asBoolean()).isTrue();

        String admin = login(ADMIN);
        String reviewId = one("select id::text from reviews where product_id=? and rating=5", String.class, p);
        assertThat(POST("/admin/reviews/" + reviewId + "/hide", null, admin).status()).isEqualTo(200);
        assertThat(GET("/products/" + p + "/reviews", null).body().get("totalElements").asInt()).isEqualTo(2);
        Resp d = GET("/products/belaya-klassika", null);
        assertThat(d.body().get("ratingCount").asInt()).isEqualTo(2);
        assertThat(d.body().get("ratingAvg").decimalValue()).isEqualByComparingTo("3.50");
    }
}
