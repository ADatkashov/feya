package app.feya.florist;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface FloristRepository extends JpaRepository<Florist, UUID> {
    @Query("select distinct f from Florist f join f.zoneIds z where f.active = true and z = :zoneId order by f.priority, f.name")
    List<Florist> findActiveByZone(UUID zoneId);
}
