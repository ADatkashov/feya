package app.feya.delivery;

import app.feya.common.Lang;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.LocalTime;
import java.util.Map;
import java.util.UUID;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "delivery_zones")
@Getter
@Setter
public class DeliveryZone {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;
    @Column(unique = true)
    private String code;
    private String cityCode;
    private String cityAliases = "";
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(columnDefinition = "jsonb")
    private Map<String, String> name;
    private BigDecimal centerLat;
    private BigDecimal centerLng;
    private BigDecimal radiusKm;
    private BigDecimal baseFee;
    private BigDecimal freeDeliveryThreshold;
    private boolean asapEnabled;
    private BigDecimal asapFee = BigDecimal.ZERO;
    private int asapEtaMinutes = 90;
    private LocalTime workStart = LocalTime.of(9, 0);
    private LocalTime workEnd = LocalTime.of(21, 0);
    @Column(name = "is_default")
    private boolean defaultZone;
    private boolean active = true;
    private String currency = "KZT";

    public String localizedName(Lang lang) {
        return lang.pick(name);
    }
}
