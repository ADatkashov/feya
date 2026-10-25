package app.feya.courier;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "courier_locations")
@Getter
@Setter
public class CourierLocation {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;
    private UUID courierId;
    private UUID orderId;
    private BigDecimal latitude;
    private BigDecimal longitude;
    @jakarta.persistence.Column(name = "accuracy_m")
    private BigDecimal accuracyM;
    private Instant recordedAt;
    private Instant createdAt = Instant.now();
}
