package app.feya.delivery;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.LocalTime;
import java.util.UUID;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "delivery_slot_templates")
@Getter
@Setter
public class DeliverySlotTemplate {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;
    private UUID zoneId;
    private LocalTime startTime;
    private LocalTime endTime;
    private int capacity;
    private int cutoffMinutes = 120;
    private BigDecimal surcharge = BigDecimal.ZERO;
    private String daysOfWeek = "1,2,3,4,5,6,7";
    private boolean active = true;

    public boolean runsOn(DayOfWeek day) {
        for (String s : daysOfWeek.split(",")) {
            if (!s.isBlank() && Integer.parseInt(s.trim()) == day.getValue()) {
                return true;
            }
        }
        return false;
    }
}
