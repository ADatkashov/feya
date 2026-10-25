package app.feya.orders;

import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "order_status_history")
@Getter
@Setter
public class OrderStatusHistory {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;
    private UUID orderId;
    @Enumerated(EnumType.STRING)
    private OrderStatus fromStatus;
    @Enumerated(EnumType.STRING)
    private OrderStatus toStatus;
    @Enumerated(EnumType.STRING)
    private Actor actorRole;
    private UUID actorId;
    private String note;
    private Instant createdAt = Instant.now();
}
