package app.feya.orders;

import jakarta.persistence.LockModeType;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;

public interface OrderRepository extends JpaRepository<OrderEntity, UUID>, JpaSpecificationExecutor<OrderEntity> {
    Page<OrderEntity> findByUserId(UUID userId, Pageable pageable);

    Optional<OrderEntity> findByIdAndUserId(UUID id, UUID userId);

    Optional<OrderEntity> findByUserIdAndIdempotencyKey(UUID userId, String key);

    long countByUserIdAndStatusIn(UUID userId, Collection<OrderStatus> statuses);

    List<OrderEntity> findByStatusInAndCreatedAtBefore(Collection<OrderStatus> statuses, Instant before);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select o from OrderEntity o where o.id = :id")
    Optional<OrderEntity> lockById(UUID id);

    /** Verified-purchase check for reviews. */
    @Query("""
            select count(o) > 0 from OrderEntity o join o.items i
            where o.userId = :userId and o.status = app.feya.orders.OrderStatus.DELIVERED and i.productId = :productId""")
    boolean hasDeliveredProduct(UUID userId, UUID productId);

    @Query("""
            select o.id from OrderEntity o join o.items i
            where o.userId = :userId and o.status = app.feya.orders.OrderStatus.DELIVERED and i.productId = :productId
            order by o.deliveredAt desc""")
    List<UUID> findDeliveredOrderIds(UUID userId, UUID productId, Pageable pageable);
}
