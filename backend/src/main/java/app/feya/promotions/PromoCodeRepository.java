package app.feya.promotions;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

public interface PromoCodeRepository extends JpaRepository<PromoCode, UUID> {
    Optional<PromoCode> findByCodeIgnoreCase(String code);

    /** Atomic redemption; returns 0 when the usage limit has been reached by a concurrent order. */
    @Modifying
    @Query("update PromoCode p set p.usedCount = p.usedCount + 1 where p.id = :id and (p.usageLimit is null or p.usedCount < p.usageLimit)")
    int tryIncrementUsage(UUID id);

    @Modifying
    @Query("update PromoCode p set p.usedCount = p.usedCount - 1 where p.id = :id and p.usedCount > 0")
    int decrementUsage(UUID id);
}
