package app.feya.notifications;

import app.feya.common.ApiException;
import app.feya.common.PageResponse;
import app.feya.security.Auth;
import java.time.Instant;
import java.util.UUID;
import org.springframework.data.domain.PageRequest;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/notifications")
public class NotificationController {
    public record NotificationDto(UUID id, String type, String title, String body, String data, boolean read,
                                  Instant createdAt) {}

    public record UnreadCount(long count) {}

    private final NotificationRepository notifications;

    public NotificationController(NotificationRepository notifications) {
        this.notifications = notifications;
    }

    @GetMapping
    public PageResponse<NotificationDto> list(@RequestParam(defaultValue = "0") int page,
                                              @RequestParam(defaultValue = "30") int size) {
        return PageResponse.of(notifications.findByUserIdOrderByCreatedAtDesc(Auth.userId(),
                        PageRequest.of(Math.max(0, page), Math.max(1, Math.min(size, 100)))),
                n -> new NotificationDto(n.getId(), n.getType(), n.getTitle(), n.getBody(), n.getData(),
                        n.getReadAt() != null, n.getCreatedAt()));
    }

    @GetMapping("/unread-count")
    public UnreadCount unread() {
        return new UnreadCount(notifications.countByUserIdAndReadAtIsNull(Auth.userId()));
    }

    @PostMapping("/{id}/read")
    @Transactional
    public void read(@PathVariable UUID id) {
        Notification n = notifications.findById(id).filter(x -> x.getUserId().equals(Auth.userId()))
                .orElseThrow(() -> ApiException.notFound("Notification"));
        if (n.getReadAt() == null) {
            n.setReadAt(Instant.now());
        }
    }

    @PostMapping("/read-all")
    @Transactional
    public void readAll() {
        notifications.markAllRead(Auth.userId(), Instant.now());
    }
}
