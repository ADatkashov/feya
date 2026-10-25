package app.feya.promotions;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PromoRedemptionRepository extends JpaRepository<PromoRedemption, UUID> {
    long countByPromoIdAndUserId(UUID promoId, UUID userId);

    Optional<PromoRedemption> findByOrderId(UUID orderId);
}
