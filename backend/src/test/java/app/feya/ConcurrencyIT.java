package app.feya;

import static org.assertj.core.api.Assertions.assertThat;

import app.feya.cart.CartDtos;
import app.feya.common.ApiException;
import app.feya.orders.OrderDtos;
import app.feya.orders.OrderService;
import app.feya.support.TestClockConfig;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

/**
 * Real concurrent transactions (not rolled back), so it cleans up after itself. Proves that the last unit of stock and
 * the last slot place cannot be sold twice.
 */
@SpringBootTest
@ActiveProfiles("test")
@Import(TestClockConfig.class)
class ConcurrencyIT {
    @Autowired OrderService orders;
    @Autowired JdbcTemplate jdbc;

    private UUID u1, u2, variant, template, florist;

    @BeforeEach
    void setUp() {
        u1 = user("+77030000001");
        u2 = user("+77030000002");
        variant = jdbc.queryForObject("select v.id from product_variants v join products p on p.id=v.product_id where p.slug='podarochnyj-mini' and v.code='SMALL'", UUID.class);
        template = jdbc.queryForObject("select t.id from delivery_slot_templates t join delivery_zones z on z.id=t.zone_id where z.code='almaty-center' and t.start_time='14:00'::time", UUID.class);
        florist = jdbc.queryForObject("select id from florists where name like '%Достык%'", UUID.class);
        // Only one bouquet in stock at the florist that has priority; the other florist has none of this variant.
        jdbc.update("update inventory set quantity = 1 where florist_id = ? and variant_id = ?", florist, variant);
        jdbc.update("delete from inventory where variant_id = ? and florist_id <> ?", variant, florist);
    }

    @AfterEach
    void cleanUp() {
        jdbc.update("delete from promo_redemptions where user_id in (?, ?)", u1, u2);
        jdbc.update("delete from order_status_history where order_id in (select id from orders where user_id in (?, ?))", u1, u2);
        jdbc.update("delete from order_items where order_id in (select id from orders where user_id in (?, ?))", u1, u2);
        jdbc.update("delete from orders where user_id in (?, ?)", u1, u2);
        jdbc.update("delete from notifications where user_id in (?, ?)", u1, u2);
        jdbc.update("delete from user_roles where user_id in (?, ?)", u1, u2);
        jdbc.update("delete from users where id in (?, ?)", u1, u2);
        jdbc.update("update delivery_slot_templates set capacity = 6 where id = ?", template);
        jdbc.update("update inventory set quantity = 15 where florist_id = ? and variant_id = ?", florist, variant);
    }

    private UUID user(String phone) {
        UUID id = UUID.randomUUID();
        jdbc.update("insert into users (id, phone) values (?, ?)", id, phone);
        jdbc.update("insert into user_roles (user_id, role) values (?, 'CUSTOMER')", id);
        return id;
    }

    private OrderDtos.CreateOrderRequest request(UUID variantId) {
        return new OrderDtos.CreateOrderRequest(List.of(new CartDtos.Line(variantId, 1)), null, null,
                new OrderDtos.InlineAddress("Алматы", "Абая", "10", null, null, null, null, null, null, false),
                new OrderDtos.Recipient("Мария", "87011234567"), new CartDtos.SlotChoice(template, java.time.LocalDate.of(2026, 11, 3)),
                false, null, false, false, null, true);
    }

    private List<Throwable> race(UUID a, UUID b) throws Exception {
        ExecutorService pool = Executors.newFixedThreadPool(2);
        CountDownLatch start = new CountDownLatch(1);
        List<Callable<Throwable>> tasks = List.of(() -> attempt(a, start), () -> attempt(b, start));
        List<Future<Throwable>> futures = tasks.stream().map(pool::submit).toList();
        start.countDown();
        List<Throwable> results = new java.util.ArrayList<>();
        for (Future<Throwable> f : futures) results.add(f.get());
        pool.shutdown();
        return results;
    }

    private Throwable attempt(UUID user, CountDownLatch start) throws Exception {
        start.await();
        try {
            orders.create(user, request(variant), null);
            return null;
        } catch (Throwable t) {
            return t;
        }
    }

    @Test
    void lastUnitOfStockCanOnlyBeSoldOnce() throws Exception {
        List<Throwable> r = race(u1, u2);
        long ok = r.stream().filter(t -> t == null).count();
        assertThat(ok).as("exactly one order may win the last bouquet: %s", r).isEqualTo(1);
        Throwable loser = r.stream().filter(t -> t != null).findFirst().orElseThrow();
        assertThat(loser).isInstanceOf(ApiException.class);
        assertThat(((ApiException) loser).code()).isIn("ITEMS_UNAVAILABLE", "OUT_OF_STOCK");
        assertThat(jdbc.queryForObject("select quantity from inventory where florist_id=? and variant_id=?", Integer.class, florist, variant)).isZero();
    }

    @Test
    void lastSlotPlaceCanOnlyBeBookedOnce() throws Exception {
        jdbc.update("update inventory set quantity = 10 where florist_id = ? and variant_id = ?", florist, variant);
        jdbc.update("update delivery_slot_templates set capacity = 1 where id = ?", template);
        List<Throwable> r = race(u1, u2);
        assertThat(r.stream().filter(t -> t == null).count()).as("%s", r).isEqualTo(1);
        Throwable loser = r.stream().filter(t -> t != null).findFirst().orElseThrow();
        assertThat(((ApiException) loser).code()).isEqualTo("SLOT_FULL");
    }
}
