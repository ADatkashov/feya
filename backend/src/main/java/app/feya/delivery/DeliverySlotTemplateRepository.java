package app.feya.delivery;

import jakarta.persistence.LockModeType;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;

public interface DeliverySlotTemplateRepository extends JpaRepository<DeliverySlotTemplate, UUID> {
    List<DeliverySlotTemplate> findByZoneIdAndActiveTrueOrderByStartTime(UUID zoneId);

    List<DeliverySlotTemplate> findByZoneIdOrderByStartTime(UUID zoneId);

    /** Row lock used to serialize slot-capacity checks for concurrent checkouts. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select t from DeliverySlotTemplate t where t.id = :id")
    Optional<DeliverySlotTemplate> lockById(UUID id);
}
