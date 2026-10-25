package app.feya.reviews;

import app.feya.catalog.Product;
import app.feya.catalog.ProductRepository;
import app.feya.common.ApiException;
import app.feya.identity.User;
import app.feya.identity.UserRepository;
import app.feya.orders.OrderRepository;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ReviewService {
    private final ReviewRepository reviews;
    private final ProductRepository products;
    private final OrderRepository orders;
    private final UserRepository users;

    public ReviewService(ReviewRepository reviews, ProductRepository products, OrderRepository orders,
                         UserRepository users) {
        this.reviews = reviews;
        this.products = products;
        this.orders = orders;
        this.users = users;
    }

    /**
     * Only customers whose order containing the product was delivered may review it (verified purchase); one review
     * per customer and product.
     */
    @Transactional
    public Review create(UUID userId, UUID productId, int rating, String text) {
        if (rating < 1 || rating > 5) {
            throw ApiException.badRequest("INVALID_RATING", "Rating must be between 1 and 5");
        }
        Product product = products.findById(productId).filter(Product::isActive)
                .orElseThrow(() -> ApiException.notFound("Product"));
        List<UUID> delivered = orders.findDeliveredOrderIds(userId, productId, PageRequest.of(0, 1));
        if (delivered.isEmpty()) {
            throw ApiException.forbidden("Only customers who received this product can review it");
        }
        if (reviews.existsByProductIdAndUserId(productId, userId)) {
            throw ApiException.conflict("REVIEW_EXISTS", "You have already reviewed this product");
        }
        Review r = new Review();
        r.setProductId(productId);
        r.setUserId(userId);
        r.setOrderId(delivered.get(0));
        r.setRating((short) rating);
        r.setText(text == null || text.isBlank() ? null : text.trim());
        r.setVerified(true);
        r = reviews.saveAndFlush(r);
        recomputeRating(product);
        return r;
    }

    @Transactional
    public void recomputeRating(Product product) {
        Object[] agg = reviews.aggregate(product.getId());
        Object[] row = agg.length == 1 && agg[0] instanceof Object[] nested ? nested : agg;
        long count = row[1] == null ? 0 : ((Number) row[1]).longValue();
        product.setRatingCount((int) count);
        product.setRatingAvg(count == 0 || row[0] == null ? null
                : BigDecimal.valueOf(((Number) row[0]).doubleValue()).setScale(2, RoundingMode.HALF_UP));
    }

    @Transactional
    public Review setHidden(UUID reviewId, boolean hidden) {
        Review r = reviews.findById(reviewId).orElseThrow(() -> ApiException.notFound("Review"));
        r.setStatus(hidden ? "HIDDEN" : "PUBLISHED");
        products.findById(r.getProductId()).ifPresent(this::recomputeRating);
        return r;
    }

    public String authorName(UUID userId) {
        User u = users.findById(userId).orElse(null);
        if (u == null || u.getName() == null || u.getName().isBlank()) {
            return "FEYA";
        }
        String[] parts = u.getName().trim().split("\\s+");
        return parts.length > 1 ? parts[0] + " " + parts[1].charAt(0) + "." : parts[0];
    }
}
