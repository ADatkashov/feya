package app.feya.support;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.transaction.annotation.Transactional;

/** Base for API integration tests. Every test runs in a transaction that is rolled back afterwards. */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Import(TestClockConfig.class)
@Transactional
public abstract class IntegrationTest {
    public static final String CUSTOMER = "+77010000000";
    public static final String OTHER_CUSTOMER = "+77010000099";
    public static final String ADMIN = "+77000000001";
    public static final String FLORIST_DOSTYK = "+77000000002";
    public static final String COURIER = "+77000000003";
    public static final String SUPPORT = "+77000000004";
    public static final String FLORIST_SAMAL = "+77000000005";

    @Autowired protected MockMvc mvc;
    @Autowired protected ObjectMapper om;
    @Autowired protected JdbcTemplate jdbc;
    @Autowired protected MutableClock clock;
    @jakarta.persistence.PersistenceContext protected jakarta.persistence.EntityManager em;

    /** Raw SQL write that keeps the JPA session coherent: flush pending changes first, clear stale entities after. */
    protected int sql(String statement, Object... args) {
        em.flush();
        int n = jdbc.update(statement, args);
        em.clear();
        return n;
    }

    @BeforeEach
    void resetClock() {
        clock.set(TestClockConfig.DEFAULT_NOW);
    }

    // ------------------------------------------------------------------------------------------
    public record Resp(int status, JsonNode body, String raw) {
        public String text(String field) {
            return body.path(field).asText();
        }
    }

    /** Single-value query that first flushes pending JPA changes so it sees the current transaction's writes. */
    protected <T> T one(String statement, Class<T> type, Object... args) {
        em.flush();
        return jdbc.queryForObject(statement, type, args);
    }

    protected Resp send(MockHttpServletRequestBuilder b, String token, Object body, Map<String, String> headers) {
        try {
            if (token != null) b.header("Authorization", "Bearer " + token);
            if (headers != null) headers.forEach(b::header);
            if (body != null) b.contentType(MediaType.APPLICATION_JSON).content(om.writeValueAsString(body));
            MvcResult r = mvc.perform(b).andReturn();
            String raw = r.getResponse().getContentAsString();
            JsonNode node = raw == null || raw.isBlank() ? om.nullNode() : om.readTree(raw);
            return new Resp(r.getResponse().getStatus(), node, raw);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    protected Resp GET(String path, String token) { return send(get("/api/v1" + path), token, null, null); }
    protected Resp POST(String path, Object body, String token) { return send(post("/api/v1" + path), token, body, null); }
    protected Resp POST(String path, Object body, String token, Map<String, String> headers) { return send(post("/api/v1" + path), token, body, headers); }
    protected Resp PUT(String path, Object body, String token) { return send(put("/api/v1" + path), token, body, null); }
    protected Resp PATCH(String path, Object body, String token) { return send(patch("/api/v1" + path), token, body, null); }
    protected Resp DELETE(String path, String token) { return send(delete("/api/v1" + path), token, null, null); }

    protected String login(String phone) {
        return loginFull(phone).body().path("accessToken").asText();
    }

    protected Resp loginFull(String phone) {
        Resp otp = POST("/auth/otp/request", Map.of("phone", phone), null);
        if (otp.status() != 200) throw new IllegalStateException("otp request failed " + otp.raw());
        Resp verify = POST("/auth/otp/verify", Map.of("phone", phone, "code", otp.text("devCode")), null);
        if (verify.status() != 200) throw new IllegalStateException("otp verify failed " + verify.raw());
        return verify;
    }

    // ------------------------------------------------------------------------------------------
    // Domain helpers
    // ------------------------------------------------------------------------------------------

    protected UUID variantId(String productSlug, String code) {
        return jdbc.queryForObject("select v.id from product_variants v join products p on p.id=v.product_id where p.slug=? and v.code=?",
                UUID.class, productSlug, code);
    }

    protected UUID productId(String slug) {
        return jdbc.queryForObject("select id from products where slug=?", UUID.class, slug);
    }

    protected UUID templateId(String zoneCode, String startTime) {
        return jdbc.queryForObject("select t.id from delivery_slot_templates t join delivery_zones z on z.id=t.zone_id where z.code=? and t.start_time=?::time",
                UUID.class, zoneCode, startTime);
    }

    protected int stock(String florist, String productSlug, String code) {
        Integer q = jdbc.queryForObject("""
                select coalesce(sum(i.quantity),0) from inventory i join florists f on f.id=i.florist_id
                where f.name like ? and i.variant_id = ?""", Integer.class, "%" + florist + "%", variantId(productSlug, code));
        return q == null ? 0 : q;
    }

    protected Map<String, Object> line(UUID variantId, int qty) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("variantId", variantId);
        m.put("quantity", qty);
        return m;
    }

    /** Tomorrow (Tue 2026-11-03) 12:00-14:00 slot in the central zone. */
    protected Map<String, Object> tomorrowSlot() {
        return Map.of("templateId", templateId("almaty-center", "12:00"), "date", "2026-11-03");
    }

    protected Map<String, Object> orderRequest(List<Map<String, Object>> items) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("items", items);
        m.put("slot", tomorrowSlot());
        m.put("address", Map.of("city", "Алматы", "street", "Абая", "building", "10", "apartment", "5"));
        m.put("recipient", Map.of("name", "Мария", "phone", "87011234567"));
        m.put("acceptTerms", true);
        return m;
    }

    protected Resp createOrder(String token, List<Map<String, Object>> items) {
        return POST("/orders", orderRequest(items), token);
    }

    protected Resp createOrder(String token, Map<String, Object> request) {
        return POST("/orders", request, token);
    }

    /** Signs and delivers a sandbox webhook exactly like a provider would. */
    @Autowired protected app.feya.payments.SandboxPaymentProvider sandbox;
    @Autowired protected app.feya.payments.PaymentService paymentService;

    protected void deliverWebhook(String eventId, String type, String providerPaymentId, String amount) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("eventId", eventId);
        body.put("type", type);
        body.put("providerPaymentId", providerPaymentId);
        if (amount != null) body.put("amount", amount);
        body.put("currency", "KZT");
        try {
            String raw = om.writeValueAsString(body);
            paymentService.handleWebhook("sandbox", raw, sandbox.sign(raw));
        } catch (com.fasterxml.jackson.core.JsonProcessingException e) {
            throw new RuntimeException(e);
        }
    }

    protected Resp pay(String token, String orderId) {
        return POST("/orders/" + orderId + "/payments", Map.of("method", "CARD"), token);
    }

    /** Creates, pays (sandbox success) and returns the order id. */
    protected String paidOrder(String token, List<Map<String, Object>> items) {
        Resp o = createOrder(token, items);
        if (o.status() != 201) throw new IllegalStateException("order failed " + o.raw());
        Resp p = pay(token, o.text("id"));
        POST("/payments/sandbox/" + p.text("id") + "/complete", Map.of("outcome", "SUCCESS"), token);
        return o.text("id");
    }
}
