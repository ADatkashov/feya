package app.feya.tracking;

import app.feya.security.Auth;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

@RestController
@RequestMapping("/api/v1/orders/{orderId}")
public class TrackingController {
    private final TrackingService tracking;
    private final SseHub hub;

    public TrackingController(TrackingService tracking, SseHub hub) {
        this.tracking = tracking;
        this.hub = hub;
    }

    @GetMapping("/tracking")
    public TrackingDtos.Tracking get(@PathVariable UUID orderId) {
        return tracking.forCustomer(Auth.userId(), orderId);
    }

    /** Server-sent events stream; clients must fall back to polling /tracking if the stream drops. */
    @GetMapping(value = "/tracking/stream", produces = "text/event-stream")
    public SseEmitter stream(@PathVariable UUID orderId) {
        return hub.subscribe(orderId, tracking.forCustomer(Auth.userId(), orderId));
    }
}
