package app.feya.florist;

import jakarta.persistence.LockModeType;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;

public interface InventoryRepository extends JpaRepository<Inventory, UUID> {
    Optional<Inventory> findByFloristIdAndVariantId(UUID floristId, UUID variantId);

    List<Inventory> findByFloristId(UUID floristId);

    List<Inventory> findByVariantIdIn(Collection<UUID> variantIds);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select i from Inventory i where i.floristId = :floristId and i.variantId in :variantIds order by i.variantId")
    List<Inventory> lockForUpdate(UUID floristId, Collection<UUID> variantIds);

    /** Best available quantity per variant among active florists serving the zone. */
    @Query("""
            select i.variantId, max(i.quantity) from Inventory i, Florist f join f.zoneIds z
            where i.floristId = f.id and f.active = true and z = :zoneId and i.quantity > 0
            group by i.variantId""")
    List<Object[]> bestQuantityByVariant(UUID zoneId);

    @Query("select count(i) from Inventory i where i.quantity <= :threshold and (:floristId is null or i.floristId = :floristId)")
    long countLowStock(int threshold, UUID floristId);
}
