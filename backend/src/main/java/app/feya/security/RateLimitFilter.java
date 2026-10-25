package app.feya.security;

import app.feya.common.ErrorResponse;
import app.feya.common.FeyaProperties;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.Clock;
import java.util.List;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Fixed-window, per-client-IP limiter for sensitive endpoints. In-memory: sufficient for a single instance;
 * put a shared limiter (gateway / Redis) in front when scaling horizontally (see docs/DEPLOYMENT.md).
 */
@Component
public class RateLimitFilter extends OncePerRequestFilter {
    private record Rule(String pathPrefix, String method, int limit, long windowMs) {}

    private static final List<Rule> RULES = List.of(
            new Rule("/api/v1/auth/otp/request", "POST", 10, 10 * 60_000L),
            new Rule("/api/v1/auth/otp/verify", "POST", 20, 10 * 60_000L),
            new Rule("/api/v1/auth/refresh", "POST", 60, 10 * 60_000L),
            new Rule("/api/v1/payments/webhook", "POST", 600, 60_000L),
            new Rule("/api/v1/orders", "POST", 30, 10 * 60_000L),
            new Rule("/api/v1/cart/quote", "POST", 240, 60_000L));

    private record Window(long start, int count) {}

    private final ConcurrentHashMap<String, Window> windows = new ConcurrentHashMap<>();
    private final FeyaProperties props;
    private final Clock clock;
    private final ObjectMapper mapper;

    public RateLimitFilter(FeyaProperties props, Clock clock, ObjectMapper mapper) {
        this.props = props;
        this.clock = clock;
        this.mapper = mapper;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return !props.rateLimit().enabled() || matchRule(request) == null;
    }

    private Rule matchRule(HttpServletRequest request) {
        String path = request.getRequestURI();
        for (Rule r : RULES) {
            if (path.startsWith(r.pathPrefix) && r.method.equalsIgnoreCase(request.getMethod())) {
                return r;
            }
        }
        return null;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        Rule rule = matchRule(req);
        long now = clock.millis();
        String key = rule.pathPrefix + "|" + req.getRemoteAddr();
        Window w = windows.compute(key, (k, old) -> {
            if (old == null || now - old.start >= rule.windowMs) {
                return new Window(now, 1);
            }
            return new Window(old.start, old.count + 1);
        });
        if (w.count > rule.limit) {
            long retryAfter = Math.max(1, (rule.windowMs - (now - w.start)) / 1000);
            res.setStatus(429);
            res.setHeader("Retry-After", String.valueOf(retryAfter));
            res.setContentType(MediaType.APPLICATION_JSON_VALUE);
            mapper.writeValue(res.getOutputStream(), ErrorResponse.of("RATE_LIMITED", "Too many requests"));
            return;
        }
        if (windows.size() > 10_000) {
            windows.entrySet().removeIf(e -> now - e.getValue().start > 15 * 60_000L);
        }
        chain.doFilter(req, res);
    }
}
