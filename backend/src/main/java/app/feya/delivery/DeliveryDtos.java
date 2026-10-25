package app.feya.delivery;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.UUID;

public final class DeliveryDtos {
    private DeliveryDtos() {}

    public record ZoneDto(UUID id, String code, String name, String cityCode, BigDecimal baseFee,
                          BigDecimal freeDeliveryThreshold, boolean asapEnabled, BigDecimal asapFee,
                          int asapEtaMinutes, String currency) {
        public static ZoneDto of(DeliveryZone z, app.feya.common.Lang lang) {
            return new ZoneDto(z.getId(), z.getCode(), z.localizedName(lang), z.getCityCode(), z.getBaseFee(),
                    z.getFreeDeliveryThreshold(), z.isAsapEnabled(), z.getAsapFee(), z.getAsapEtaMinutes(),
                    z.getCurrency());
        }
    }

    public record SlotDto(UUID templateId, LocalDate date, LocalTime start, LocalTime end, boolean available,
                          int remaining, BigDecimal surcharge, String unavailableReason) {}

    public record DaySlots(LocalDate date, List<SlotDto> slots) {}

    public record SlotsResponse(UUID zoneId, String timezone, boolean asapAvailable, BigDecimal asapFee,
                                int asapEtaMinutes, List<DaySlots> days) {}
}
