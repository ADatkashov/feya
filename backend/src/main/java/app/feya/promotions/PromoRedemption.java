package app.feya.promotions;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "promo_redemptions")
@Getter
@Setter
public class PromoRedemption {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;
    private UUID promoId;
    private UUID userId;
    private UUID orderId;
    private Instant createdAt = Instant.now();
}
