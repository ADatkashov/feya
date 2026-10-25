package app.feya.promotions;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
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
@Table(name = "promo_codes")
@Getter
@Setter
public class PromoCode {
    public enum Type { PERCENT, FIXED }

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;
    @Column(unique = true)
    private String code;
    @Enumerated(EnumType.STRING)
    private Type type;
    private BigDecimal value;
    private BigDecimal minOrder = BigDecimal.ZERO;
    private BigDecimal maxDiscount;
    private Instant validFrom;
    private Instant validUntil;
    private Integer usageLimit;
    private Integer perUserLimit;
    private int usedCount;
    private boolean active = true;
}
