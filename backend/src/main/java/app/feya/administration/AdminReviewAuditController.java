package app.feya.administration;

import app.feya.common.AuditEvent;
import app.feya.common.AuditEventRepository;
import app.feya.common.AuditService;
import app.feya.common.PageResponse;
import app.feya.reviews.Review;
import app.feya.reviews.ReviewRepository;
import app.feya.reviews.ReviewService;
import jakarta.persistence.criteria.Predicate;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/admin")
public class AdminReviewAuditController {
    public record ReviewRow(UUID id, UUID productId, UUID userId, int rating, String text, boolean verified,
                            String status, Instant createdAt) {}

    public record AuditRow(UUID id, UUID actorId, String actorRole, String action, String entityType, String entityId,
                           String details, Instant createdAt) {}

    private final ReviewRepository reviews;
    private final ReviewService reviewService;
    private final AuditEventRepository auditEvents;
    private final AuditService audit;

    public AdminReviewAuditController(ReviewRepository reviews, ReviewService reviewService,
                                      AuditEventRepository auditEvents, AuditService audit) {
        this.reviews = reviews;
        this.reviewService = reviewService;
        this.auditEvents = auditEvents;
        this.audit = audit;
    }

    @GetMapping("/reviews")
    @Transactional(readOnly = true)
    public PageResponse<ReviewRow> reviews(@RequestParam(required = false) String status,
                                           @RequestParam(defaultValue = "0") int page,
                                           @RequestParam(defaultValue = "20") int size) {
        Specification<Review> spec = (r, q, cb) -> status == null || status.isBlank() ? cb.conjunction()
                : cb.equal(r.get("status"), status);
        return PageResponse.of(reviews.findAll(spec, PageRequest.of(Math.max(0, page), Math.max(1, Math.min(size, 100)),
                Sort.by(Sort.Order.desc("createdAt")))), r -> new ReviewRow(r.getId(), r.getProductId(), r.getUserId(),
                r.getRating(), r.getText(), r.isVerified(), r.getStatus(), r.getCreatedAt()));
    }

    @PostMapping("/reviews/{id}/hide")
    @Transactional
    public ReviewRow hide(@PathVariable UUID id) {
        return moderate(id, true);
    }

    @PostMapping("/reviews/{id}/unhide")
    @Transactional
    public ReviewRow unhide(@PathVariable UUID id) {
        return moderate(id, false);
    }

    private ReviewRow moderate(UUID id, boolean hide) {
        Review r = reviewService.setHidden(id, hide);
        audit.record(hide ? "REVIEW_HIDDEN" : "REVIEW_RESTORED", "REVIEW", id, null);
        return new ReviewRow(r.getId(), r.getProductId(), r.getUserId(), r.getRating(), r.getText(), r.isVerified(),
                r.getStatus(), r.getCreatedAt());
    }

    @GetMapping("/audit")
    @org.springframework.security.access.prepost.PreAuthorize("hasRole('ADMIN')")
    @Transactional(readOnly = true)
    public PageResponse<AuditRow> audit(@RequestParam(required = false) String entityType,
                                        @RequestParam(required = false) String entityId,
                                        @RequestParam(defaultValue = "0") int page,
                                        @RequestParam(defaultValue = "50") int size) {
        Specification<AuditEvent> spec = (r, q, cb) -> {
            List<Predicate> ps = new ArrayList<>();
            if (entityType != null && !entityType.isBlank()) ps.add(cb.equal(r.get("entityType"), entityType));
            if (entityId != null && !entityId.isBlank()) ps.add(cb.equal(r.get("entityId"), entityId));
            return cb.and(ps.toArray(Predicate[]::new));
        };
        return PageResponse.of(auditEvents.findAll(spec, PageRequest.of(Math.max(0, page), Math.max(1, Math.min(size, 200)),
                Sort.by(Sort.Order.desc("createdAt")))), a -> new AuditRow(a.getId(), a.getActorId(), a.getActorRole(),
                a.getAction(), a.getEntityType(), a.getEntityId(), a.getDetails(), a.getCreatedAt()));
    }
}
