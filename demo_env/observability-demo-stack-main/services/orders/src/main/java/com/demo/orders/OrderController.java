package com.demo.orders;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.math.BigDecimal;
import java.util.*;

@RestController
@RequestMapping("/api")
public class OrderController {

    private static final Logger log = LoggerFactory.getLogger(OrderController.class);
    private static final String HOT_SKU = "WEL-SKN-0001";

    private final JdbcTemplate jdbc;
    private final DataSource dataSource;
    private final ChaosFlags chaos;

    public OrderController(JdbcTemplate jdbc, DataSource dataSource, ChaosFlags chaos) {
        this.jdbc = jdbc;
        this.dataSource = dataSource;
        this.chaos = chaos;
    }

    @GetMapping("/health")
    public Map<String, Object> health() {
        jdbc.queryForObject("SELECT 1", Integer.class);
        return Map.of("status", "ok", "service", "__DEMO_NAME__-orders");
    }

    // -----------------------------------------------------------------------
    // Recent orders.  Scenario: N+1 query explosion.
    // -----------------------------------------------------------------------
    @GetMapping("/orders/recent")
    public Map<String, Object> recentOrders(@RequestParam(defaultValue = "20") int limit) {
        List<Map<String, Object>> orders = jdbc.queryForList(
                "SELECT id, customer_id, customer_email, status, channel, total_amount, " +
                "       payment_method, shipping_city, placed_at " +
                "FROM orders ORDER BY placed_at DESC LIMIT ?", limit);

        boolean nPlusOne = chaos.on("n_plus_one");

        if (nPlusOne) {
            // One query per order, then one more per line item. This is the
            // classic ORM lazy-loading pattern -- fast in dev, brutal in prod.
            for (Map<String, Object> order : orders) {
                List<Map<String, Object>> items = jdbc.queryForList(
                        "SELECT id, sku, product_name, qty, unit_price " +
                        "FROM order_items WHERE order_id = ?", order.get("id"));
                for (Map<String, Object> item : items) {
                    List<Map<String, Object>> stock = jdbc.queryForList(
                            "SELECT on_hand, reserved, warehouse FROM inventory WHERE sku = ?",
                            item.get("sku"));
                    if (!stock.isEmpty()) {
                        item.put("warehouse", stock.get(0).get("warehouse"));
                        item.put("on_hand", stock.get(0).get("on_hand"));
                    }
                }
                order.put("items", items);
            }
        } else {
            List<Object> ids = new ArrayList<>();
            for (Map<String, Object> o : orders) ids.add(o.get("id"));
            if (!ids.isEmpty()) {
                String placeholders = String.join(",", Collections.nCopies(ids.size(), "?"));
                List<Map<String, Object>> allItems = jdbc.queryForList(
                        "SELECT oi.order_id, oi.id, oi.sku, oi.product_name, oi.qty, oi.unit_price, " +
                        "       i.warehouse, i.on_hand " +
                        "FROM order_items oi LEFT JOIN inventory i ON i.sku = oi.sku " +
                        "WHERE oi.order_id IN (" + placeholders + ")", ids.toArray());
                Map<Object, List<Map<String, Object>>> byOrder = new HashMap<>();
                for (Map<String, Object> it : allItems) {
                    byOrder.computeIfAbsent(it.get("order_id"), k -> new ArrayList<>()).add(it);
                }
                for (Map<String, Object> o : orders) {
                    o.put("items", byOrder.getOrDefault(o.get("id"), List.of()));
                }
            }
        }

        return Map.of("mode", nPlusOne ? "n_plus_one" : "batched",
                      "count", orders.size(),
                      "orders", orders);
    }

    // -----------------------------------------------------------------------
    // Order search.  Scenario: missing index -> full table scan.
    // -----------------------------------------------------------------------
    @GetMapping("/orders/search")
    public Map<String, Object> searchOrders(@RequestParam String email) {
        boolean slow = chaos.on("slow_query");
        long start = System.currentTimeMillis();
        List<Map<String, Object>> rows;

        if (slow) {
            // customer_email has no index, so this equality predicate still
            // costs a full table scan -- until you create the index live.
            rows = jdbc.queryForList(
                    "SELECT id, customer_email, status, channel, total_amount, placed_at " +
                    "FROM orders WHERE customer_email = ? " +
                    "ORDER BY placed_at DESC LIMIT 50", email);
        } else {
            // Identical result set, resolved through the indexed customer_id path.
            rows = jdbc.queryForList(
                    "SELECT o.id, o.customer_email, o.status, o.channel, o.total_amount, o.placed_at " +
                    "FROM orders o JOIN customers c ON c.id = o.customer_id " +
                    "WHERE c.email = ? ORDER BY o.placed_at DESC LIMIT 50", email);
        }

        long tookMs = System.currentTimeMillis() - start;
        if (tookMs > 150) log.warn("Slow order search for {} took {}ms", email, tookMs);

        return Map.of("mode", slow ? "full_table_scan" : "indexed",
                      "took_ms", tookMs,
                      "count", rows.size(),
                      "orders", rows);
    }

    @GetMapping("/orders/{id}")
    public Map<String, Object> orderDetail(@PathVariable long id) {
        List<Map<String, Object>> order = jdbc.queryForList(
                "SELECT id, customer_id, customer_email, status, channel, total_amount, " +
                "       payment_method, shipping_city, placed_at FROM orders WHERE id = ?", id);
        if (order.isEmpty()) return Map.of("error", "order not found", "id", id);

        List<Map<String, Object>> items = jdbc.queryForList(
                "SELECT id, sku, product_name, qty, unit_price FROM order_items WHERE order_id = ?", id);

        Map<String, Object> out = new HashMap<>(order.get(0));
        out.put("items", items);
        return out;
    }

    // -----------------------------------------------------------------------
    // Revenue analytics.  Always heavy; much heavier with slow_query enabled.
    // -----------------------------------------------------------------------
    @GetMapping("/analytics/top-products")
    public Map<String, Object> topProducts() {
        boolean slow = chaos.on("slow_query");
        long start = System.currentTimeMillis();

        String sql = slow
                // DATE() around the column makes the placed_at index unusable.
                ? "SELECT oi.sku, oi.product_name, SUM(oi.qty) AS units, " +
                  "       SUM(oi.qty * oi.unit_price) AS revenue, COUNT(DISTINCT o.customer_id) AS buyers " +
                  "FROM order_items oi JOIN orders o ON o.id = oi.order_id " +
                  "WHERE DATE(o.placed_at) >= DATE(NOW() - INTERVAL 7 DAY) AND o.status <> 'CANCELLED' " +
                  "GROUP BY oi.sku, oi.product_name ORDER BY revenue DESC LIMIT 10"
                : "SELECT oi.sku, oi.product_name, SUM(oi.qty) AS units, " +
                  "       SUM(oi.qty * oi.unit_price) AS revenue, COUNT(DISTINCT o.customer_id) AS buyers " +
                  "FROM order_items oi JOIN orders o ON o.id = oi.order_id " +
                  "WHERE o.placed_at >= NOW() - INTERVAL 7 DAY AND o.status <> 'CANCELLED' " +
                  "GROUP BY oi.sku, oi.product_name ORDER BY revenue DESC LIMIT 10";

        List<Map<String, Object>> rows = jdbc.queryForList(sql);
        long tookMs = System.currentTimeMillis() - start;
        if (tookMs > 500) log.warn("Top-products aggregation took {}ms", tookMs);

        return Map.of("mode", slow ? "unsargable_date_filter" : "index_range_scan",
                      "took_ms", tookMs,
                      "products", rows);
    }

    @GetMapping("/inventory")
    public List<Map<String, Object>> inventory() {
        return jdbc.queryForList(
                "SELECT sku, product_name, warehouse, unit_price, on_hand, reserved " +
                "FROM inventory ORDER BY slot");
    }

    // -----------------------------------------------------------------------
    // Checkout.  Scenarios: row-lock contention and connection-pool exhaustion.
    // -----------------------------------------------------------------------
    @PostMapping("/checkout")
    public Map<String, Object> checkout(@RequestBody Map<String, Object> body) {
        boolean lockContention = chaos.on("lock_contention");
        boolean poolExhaustion = chaos.on("pool_exhaustion");
        int holdSeconds = Math.max(1, chaos.intFlag("hold_seconds", 4));

        String sku = lockContention ? HOT_SKU : String.valueOf(body.getOrDefault("sku", HOT_SKU));
        int qty = body.get("qty") instanceof Number n ? Math.max(1, n.intValue()) : 1;
        String email = String.valueOf(body.getOrDefault("email", "customer1@demo.example"));

        long start = System.currentTimeMillis();
        long orderId;

        try (Connection conn = dataSource.getConnection()) {
            conn.setAutoCommit(false);
            try {
                // Reserve stock. FOR UPDATE takes a row lock for the whole txn.
                int onHand;
                BigDecimal unitPrice;
                String productName;
                try (PreparedStatement ps = conn.prepareStatement(
                        "SELECT on_hand, unit_price, product_name FROM inventory WHERE sku = ? FOR UPDATE")) {
                    ps.setString(1, sku);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (!rs.next()) {
                            conn.rollback();
                            return Map.of("error", "unknown sku", "sku", sku);
                        }
                        onHand = rs.getInt("on_hand");
                        unitPrice = rs.getBigDecimal("unit_price");
                        productName = rs.getString("product_name");
                    }
                }

                if (lockContention || poolExhaustion) {
                    // Hold the transaction open -- and therefore the row lock and
                    // the pooled connection -- by doing real analytical work, not
                    // by sleeping. Query Activity shows a genuine statement with a
                    // real execution plan and real rows examined, which is what a
                    // DBA would expect to find behind a blocked session.
                    int batches = burnDatabaseWork(conn, holdSeconds);
                    log.warn("Held txn for sku={} across {} analytical batches", sku, batches);
                }

                if (onHand < qty) {
                    conn.rollback();
                    return Map.of("error", "out of stock", "sku", sku, "on_hand", onHand);
                }

                try (PreparedStatement ps = conn.prepareStatement(
                        "UPDATE inventory SET on_hand = on_hand - ?, reserved = reserved + ?, " +
                        "updated_at = NOW() WHERE sku = ?")) {
                    ps.setInt(1, qty);
                    ps.setInt(2, qty);
                    ps.setString(3, sku);
                    ps.executeUpdate();
                }

                try (PreparedStatement ps = conn.prepareStatement(
                        "INSERT INTO orders (customer_id, customer_email, status, channel, total_amount, " +
                        "payment_method, shipping_city, placed_at) " +
                        "SELECT c.id, c.email, 'PLACED', 'web', ?, 'UPI', c.city, NOW() " +
                        "FROM customers c WHERE c.email = ? LIMIT 1",
                        Statement.RETURN_GENERATED_KEYS)) {
                    ps.setBigDecimal(1, unitPrice.multiply(BigDecimal.valueOf(qty)));
                    ps.setString(2, email);
                    ps.executeUpdate();
                    try (ResultSet keys = ps.getGeneratedKeys()) {
                        orderId = keys.next() ? keys.getLong(1) : -1L;
                    }
                }

                if (orderId <= 0) {
                    // No customer matched, so no order was created. Rolling back
                    // is essential: the inventory decrement above must not stand.
                    conn.rollback();
                    return Map.of("error", "unknown customer email", "email", email);
                }

                {
                    try (PreparedStatement ps = conn.prepareStatement(
                            "INSERT INTO order_items (order_id, sku, product_name, qty, unit_price) " +
                            "VALUES (?, ?, ?, ?, ?)")) {
                        ps.setLong(1, orderId);
                        ps.setString(2, sku);
                        ps.setString(3, productName);
                        ps.setInt(4, qty);
                        ps.setBigDecimal(5, unitPrice);
                        ps.executeUpdate();
                    }
                }

                conn.commit();
            } catch (Exception e) {
                try {
                    conn.rollback();
                } catch (Exception rollbackFailure) {
                    e.addSuppressed(rollbackFailure);
                }
                throw e;
            }
        } catch (Exception e) {
            log.error("Checkout failed for sku={} email={}", sku, email, e);
            throw new RuntimeException("checkout failed: " + e.getMessage(), e);
        }

        long tookMs = System.currentTimeMillis() - start;
        if (tookMs > 1000) log.warn("Checkout for sku={} took {}ms", sku, tookMs);

        return Map.of("order_id", orderId, "sku", sku, "qty", qty, "took_ms", tookMs,
                      "held_lock", lockContention, "held_connection", poolExhaustion);
    }

    /**
     * Runs genuinely expensive aggregates on the given connection until the
     * requested duration has elapsed, holding whatever locks the surrounding
     * transaction owns.
     *
     * Each iteration is a real range scan over a 200k-row slice of order_items
     * joined to orders, so it lands in Database Monitoring as a legitimate slow
     * query rather than an obviously synthetic SLEEP.
     */
    private int burnDatabaseWork(Connection conn, int seconds) throws SQLException {
        long deadline = System.currentTimeMillis() + (seconds * 1000L);
        int batches = 0;
        try (PreparedStatement ps = conn.prepareStatement(
                "SELECT COUNT(DISTINCT oi.sku) AS skus, " +
                "       SUM(oi.qty * oi.unit_price) AS revenue, " +
                "       AVG(oi.unit_price) AS avg_price " +
                "FROM order_items oi JOIN orders o ON o.id = oi.order_id " +
                "WHERE oi.id BETWEEN ? AND ? AND o.status <> 'CANCELLED'")) {
            while (System.currentTimeMillis() < deadline) {
                long lo = 1 + ((batches * 200_000L) % 1_000_000L);
                ps.setLong(1, lo);
                ps.setLong(2, lo + 200_000L);
                try (ResultSet rs = ps.executeQuery()) {
                    rs.next();
                }
                batches++;
            }
        }
        return batches;
    }

    // -----------------------------------------------------------------------
    // Live remediation: add or drop the index DBM tells you is missing.
    // -----------------------------------------------------------------------
    @PostMapping("/admin/index/{action}")
    public Map<String, Object> toggleIndex(@PathVariable String action) {
        String index = "idx_orders_customer_email";
        try {
            // MySQL supports neither CREATE INDEX IF NOT EXISTS nor DROP INDEX
            // IF EXISTS, so check first -- a double click must not throw.
            Integer present = jdbc.queryForObject(
                    "SELECT COUNT(*) FROM information_schema.statistics " +
                    "WHERE table_schema = DATABASE() AND table_name = 'orders' AND index_name = ?",
                    Integer.class, index);
            boolean exists = present != null && present > 0;

            if ("create".equalsIgnoreCase(action)) {
                if (exists) return Map.of("status", "already present", "index", index);
                jdbc.execute("CREATE INDEX " + index + " ON orders (customer_email)");
                return Map.of("status", "created", "index", index);
            } else if ("drop".equalsIgnoreCase(action)) {
                if (!exists) return Map.of("status", "already absent", "index", index);
                jdbc.execute("DROP INDEX " + index + " ON orders");
                return Map.of("status", "dropped", "index", index);
            }
            return Map.of("error", "action must be 'create' or 'drop'");
        } catch (Exception e) {
            return Map.of("error", String.valueOf(e.getMessage()));
        }
    }

    @GetMapping("/admin/pool")
    public Map<String, Object> poolStats() {
        if (!(dataSource instanceof com.zaxxer.hikari.HikariDataSource)) {
            return Map.of("error", "pool stats unavailable: datasource is not HikariCP");
        }
        com.zaxxer.hikari.HikariDataSource hds = (com.zaxxer.hikari.HikariDataSource) dataSource;
        com.zaxxer.hikari.HikariPoolMXBean mx = hds.getHikariPoolMXBean();
        if (mx == null) {
            return Map.of("error", "pool not initialised yet -- send one request first");
        }
        return Map.of(
                "active", mx.getActiveConnections(),
                "idle", mx.getIdleConnections(),
                "waiting", mx.getThreadsAwaitingConnection(),
                "max", hds.getMaximumPoolSize());
    }
}
