package app.feya.delivery;

import app.feya.common.ApiException;
import app.feya.common.Lang;
import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/delivery")
public class DeliveryController {
    private final DeliveryService delivery;

    public DeliveryController(DeliveryService delivery) {
        this.delivery = delivery;
    }

    @GetMapping("/zones")
    public List<DeliveryDtos.ZoneDto> zones(Lang lang) {
        return delivery.activeZones().stream().map(z -> DeliveryDtos.ZoneDto.of(z, lang)).toList();
    }

    @GetMapping("/zones/resolve")
    public DeliveryDtos.ZoneDto resolve(@RequestParam(required = false) String city,
                                        @RequestParam(required = false) BigDecimal lat,
                                        @RequestParam(required = false) BigDecimal lng, Lang lang) {
        validateCoords(lat, lng);
        return DeliveryDtos.ZoneDto.of(delivery.resolveZone(city, lat, lng), lang);
    }

    @GetMapping("/slots")
    public DeliveryDtos.SlotsResponse slots(@RequestParam(required = false) UUID zoneId,
                                            @RequestParam(defaultValue = "7") int days) {
        DeliveryZone zone = zoneId == null ? delivery.defaultZone() : delivery.getZone(zoneId);
        return delivery.slots(zone, days);
    }

    static void validateCoords(BigDecimal lat, BigDecimal lng) {
        if ((lat == null) != (lng == null)) {
            throw ApiException.badRequest("INVALID_COORDINATES", "Both lat and lng are required");
        }
        if (lat != null && (lat.abs().compareTo(BigDecimal.valueOf(90)) > 0 || lng.abs().compareTo(BigDecimal.valueOf(180)) > 0)) {
            throw ApiException.badRequest("INVALID_COORDINATES", "Coordinates out of range");
        }
    }
}
