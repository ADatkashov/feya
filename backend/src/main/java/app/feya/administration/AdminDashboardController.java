package app.feya.administration;

import app.feya.florist.InventoryRepository;
import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Map;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/admin/dashboard")
public class AdminDashboardController {
    public record TopProduct(String name, long quantity, BigDecimal revenue) {}

    public record Dashboard(long ordersToday, BigDecimal revenueToday, long orders7d, BigDecimal revenue7d,
                            long newCustomers7d, long openOrders, long lowStockRows, Map<String, Long> ordersByStatus,
                            List<TopProduct> topProducts, String currency) {}

    private final JdbcTemplate jdbc;
    private final InventoryRepository inventory;
    private final Clock clock;
    private final ZoneId zone;

    public AdminDashboardController(JdbcTemplate jdbc, InventoryRepository inventory, Clock clock, ZoneId zone) {
        this.jdbc = jdbc;
        this.inventory = inventory;
        this.clock = clock;
        this.zone = zone;
    }

    @GetMapping
    public Dashboard get() {
        Instant startToday = LocalDate.now(clock.withZone(zone)).atStartOfDay(zone).toInstant();
        Instant start7d = startToday.minusSeconds(6 * 86400L);
        // Revenue counts orders that are paid and not reversed.
        String paid = "status in ('PAID','CONFIRMED','PREPARING','READY_FOR_PICKUP','COURIER_ASSIGNED','PICKED_UP','ON_THE_WAY','DELIVERED')";
        long ordersToday = count("select count(*) from orders where created_at >= ?", startToday);
        BigDecimal revToday = sum("select coalesce(sum(total),0) from orders where " + paid + " and created_at >= ?", startToday);
        long orders7d = count("select count(*) from orders where created_at >= ?", start7d);
        BigDecimal rev7d = sum("select coalesce(sum(total),0) from orders where " + paid + " and created_at >= ?", start7d);
        long customers = count("select count(*) from users where created_at >= ?", start7d);
        long open = jdbc.queryForObject("select count(*) from orders where status in "
                + "('PAID','CONFIRMED','PREPARING','READY_FOR_PICKUP','COURIER_ASSIGNED','PICKED_UP','ON_THE_WAY')", Long.class);
        Map<String, Long> byStatus = new java.util.LinkedHashMap<>();
        jdbc.query("select status, count(*) c from orders group by status order by status",
                rs -> { byStatus.put(rs.getString(1), rs.getLong(2)); });
        List<TopProduct> top = jdbc.query("""
                select i.product_name, sum(i.quantity) q, sum(i.line_total) r from order_items i
                join orders o on o.id = i.order_id where o.status = 'DELIVERED'
                group by i.product_name order by q desc limit 5""",
                (rs, n) -> new TopProduct(rs.getString(1), rs.getLong(2), rs.getBigDecimal(3)));
        return new Dashboard(ordersToday, revToday, orders7d, rev7d, customers, open, inventory.countLowStock(2, null),
                byStatus, top, "KZT");
    }

    private long count(String sql, Instant arg) {
        Long v = jdbc.queryForObject(sql, Long.class, java.sql.Timestamp.from(arg));
        return v == null ? 0 : v;
    }

    private BigDecimal sum(String sql, Instant arg) {
        BigDecimal v = jdbc.queryForObject(sql, BigDecimal.class, java.sql.Timestamp.from(arg));
        return v == null ? BigDecimal.ZERO : v;
    }
}
