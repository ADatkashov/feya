package app.feya.courier;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

public interface CourierLocationRepository extends JpaRepository<CourierLocation, UUID> {
    Optional<CourierLocation> findFirstByCourierIdOrderByRecordedAtDesc(UUID courierId);

    List<CourierLocation> findTop20ByOrderIdOrderByRecordedAtDesc(UUID orderId);

    @Modifying
    @Query("delete from CourierLocation l where l.createdAt < :before")
    int deleteOlderThan(Instant before);
}
