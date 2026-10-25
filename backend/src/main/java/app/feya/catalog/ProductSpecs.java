package app.feya.catalog;

import app.feya.florist.Florist;
import app.feya.florist.Inventory;
import jakarta.persistence.criteria.Predicate;
import jakarta.persistence.criteria.Root;
import jakarta.persistence.criteria.Subquery;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.domain.Specification;

final class ProductSpecs {
    private ProductSpecs() {}

    static Specification<Product> active() {
        return (root, q, cb) -> cb.isTrue(root.get("active"));
    }

    static Specification<Product> category(String slug) {
        return (root, q, cb) -> cb.equal(root.get("category").get("slug"), slug);
    }

    static Specification<Product> text(String needle) {
        String like = "%" + needle.toLowerCase().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%";
        return (root, q, cb) -> cb.like(root.get("searchText"), like, '\\');
    }

    static Specification<Product> price(BigDecimal min, BigDecimal max) {
        return (root, q, cb) -> {
            List<Predicate> ps = new ArrayList<>();
            if (min != null) ps.add(cb.greaterThanOrEqualTo(root.get("priceFrom"), min));
            if (max != null) ps.add(cb.lessThanOrEqualTo(root.get("priceFrom"), max));
            return cb.and(ps.toArray(Predicate[]::new));
        };
    }

    static Specification<Product> flag(String attribute) {
        return (root, q, cb) -> cb.isTrue(root.get(attribute));
    }

    static Specification<Product> createdAfter(Instant since) {
        return (root, q, cb) -> cb.greaterThanOrEqualTo(root.get("createdAt"), since);
    }

    static Specification<Product> idIn(List<UUID> ids) {
        return (root, q, cb) -> ids.isEmpty() ? cb.disjunction() : root.get("id").in(ids);
    }

    static Specification<Product> excluding(UUID id) {
        return (root, q, cb) -> cb.notEqual(root.get("id"), id);
    }

    /** Product has at least one active variant in stock at an active florist serving the zone. */
    static Specification<Product> inStockInZone(UUID zoneId) {
        return (root, query, cb) -> {
            Subquery<Integer> sq = query.subquery(Integer.class);
            Root<Inventory> inv = sq.from(Inventory.class);
            Root<ProductVariant> variant = sq.from(ProductVariant.class);
            Root<Florist> florist = sq.from(Florist.class);
            sq.select(cb.literal(1)).where(
                    cb.equal(inv.get("variantId"), variant.get("id")),
                    cb.equal(variant.get("product"), root),
                    cb.isTrue(variant.get("active")),
                    cb.greaterThan(inv.<Integer>get("quantity"), 0),
                    cb.equal(inv.get("floristId"), florist.get("id")),
                    cb.isTrue(florist.get("active")),
                    cb.isMember(zoneId, florist.<java.util.Set<UUID>>get("zoneIds")));
            return cb.exists(sq);
        };
    }
}
