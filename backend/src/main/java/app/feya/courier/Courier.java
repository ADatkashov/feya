package app.feya.courier;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "couriers")
@Getter
@Setter
public class Courier {
    @Id
    private UUID userId;
    private String vehicle;
    private boolean onShift;
    private boolean locationSharing;
    private boolean active = true;
    private Instant createdAt = Instant.now();
}
