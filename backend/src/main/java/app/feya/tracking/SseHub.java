package app.feya.tracking;

import java.io.IOException;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

/** Fan-out of tracking updates to open server-sent-event streams, keyed by order. Clients also poll as a fallback. */
@Component
public class SseHub {
    private static final long TIMEOUT_MS = 30 * 60_000L;
    private final Map<UUID, List<SseEmitter>> emitters = new ConcurrentHashMap<>();

    public SseEmitter subscribe(UUID orderId, Object initial) {
        SseEmitter emitter = new SseEmitter(TIMEOUT_MS);
        emitters.computeIfAbsent(orderId, k -> new CopyOnWriteArrayList<>()).add(emitter);
        Runnable cleanup = () -> remove(orderId, emitter);
        emitter.onCompletion(cleanup);
        emitter.onTimeout(cleanup);
        emitter.onError(e -> cleanup.run());
        try {
            emitter.send(SseEmitter.event().name("tracking").data(initial));
        } catch (IOException | IllegalStateException e) {
            cleanup.run();
        }
        return emitter;
    }

    public void publish(UUID orderId, Object payload) {
        List<SseEmitter> list = emitters.get(orderId);
        if (list == null) {
            return;
        }
        for (SseEmitter e : list) {
            try {
                e.send(SseEmitter.event().name("tracking").data(payload));
            } catch (IOException | IllegalStateException ex) {
                remove(orderId, e);
            }
        }
    }

    public int subscribers(UUID orderId) {
        List<SseEmitter> l = emitters.get(orderId);
        return l == null ? 0 : l.size();
    }

    private void remove(UUID orderId, SseEmitter e) {
        emitters.computeIfPresent(orderId, (k, v) -> {
            v.remove(e);
            return v.isEmpty() ? null : v;
        });
    }
}
