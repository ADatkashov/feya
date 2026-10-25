package app.feya.reviews;

import app.feya.common.PageResponse;
import app.feya.security.Auth;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.UUID;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/products/{productId}/reviews")
public class ReviewController {
    public record ReviewRequest(@Min(1) @Max(5) int rating, @Size(max = 2000) String text) {}

    public record ReviewDto(UUID id, int rating, String text, String author, boolean verified, Instant createdAt) {}

    private final ReviewRepository reviews;
    private final ReviewService service;

    public ReviewController(ReviewRepository reviews, ReviewService service) {
        this.reviews = reviews;
        this.service = service;
    }

    @GetMapping
    public PageResponse<ReviewDto> list(@PathVariable UUID productId, @RequestParam(defaultValue = "0") int page,
                                        @RequestParam(defaultValue = "10") int size) {
        return PageResponse.of(reviews.findByProductIdAndStatusOrderByCreatedAtDesc(productId, "PUBLISHED",
                PageRequest.of(Math.max(0, page), Math.max(1, Math.min(size, 50)))), this::dto);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ReviewDto create(@PathVariable UUID productId, @Valid @RequestBody ReviewRequest req) {
        return dto(service.create(Auth.userId(), productId, req.rating(), req.text()));
    }

    private ReviewDto dto(Review r) {
        return new ReviewDto(r.getId(), r.getRating(), r.getText(), service.authorName(r.getUserId()), r.isVerified(),
                r.getCreatedAt());
    }
}
