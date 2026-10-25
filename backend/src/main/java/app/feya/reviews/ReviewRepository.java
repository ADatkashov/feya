package app.feya.reviews;

import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;

public interface ReviewRepository extends JpaRepository<Review, UUID>, JpaSpecificationExecutor<Review> {
    Page<Review> findByProductIdAndStatusOrderByCreatedAtDesc(UUID productId, String status, Pageable pageable);

    boolean existsByProductIdAndUserId(UUID productId, UUID userId);

    @Query("select avg(r.rating), count(r) from Review r where r.productId = :productId and r.status = 'PUBLISHED'")
    Object[] aggregate(UUID productId);
}
