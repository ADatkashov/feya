package app.feya.delivery;

import app.feya.common.ApiException;
import app.feya.common.FeyaProperties;
import app.feya.common.Money;
import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class DeliveryService {
    static final int MAX_DAYS_AHEAD = 14;

    private final DeliveryZoneRepository zones;
    private final DeliverySlotTemplateRepository templates;
    private final JdbcTemplate jdbc;
    @jakarta.persistence.PersistenceContext
    private jakarta.persistence.EntityManager em;
    private final Clock clock;
    private final ZoneId businessZone;

    public DeliveryService(DeliveryZoneRepository zones, DeliverySlotTemplateRepository templates, JdbcTemplate jdbc,
                           Clock clock, ZoneId businessZone, FeyaProperties props) {
        this.zones = zones;
        this.templates = templates;
        this.jdbc = jdbc;
        this.clock = clock;
        this.businessZone = businessZone;
    }

    public ZoneId businessZone() {
        return businessZone;
    }

    public DeliveryZone getZone(UUID id) {
        return zones.findById(id).filter(DeliveryZone::isActive)
                .orElseThrow(() -> ApiException.unprocessable("ZONE_NOT_FOUND", "Delivery zone not available"));
    }

    public DeliveryZone defaultZone() {
        List<DeliveryZone> active = zones.findByActiveTrue();
        return active.stream().filter(DeliveryZone::isDefaultZone).findFirst()
                .or(() -> active.stream().findFirst())
                .orElseThrow(() -> ApiException.unprocessable("NOT_DELIVERABLE", "No delivery zones configured"));
    }

    /** Finds the delivery zone for an address. Coordinates win over the city name when provided. */
    public DeliveryZone resolveZone(String city, BigDecimal lat, BigDecimal lng) {
        List<DeliveryZone> active = zones.findByActiveTrue();
        if (lat != null && lng != null) {
            return active.stream()
                    .filter(z -> distanceKm(lat.doubleValue(), lng.doubleValue(), z.getCenterLat().doubleValue(),
                            z.getCenterLng().doubleValue()) <= z.getRadiusKm().doubleValue())
                    .min(Comparator.comparing(DeliveryZone::getRadiusKm))
                    .orElseThrow(() -> ApiException.unprocessable("NOT_DELIVERABLE", "We do not deliver to this location yet"));
        }
        String norm = normalizeCity(city);
        if (norm.isEmpty()) {
            throw ApiException.unprocessable("NOT_DELIVERABLE", "City is required");
        }
        List<DeliveryZone> inCity = active.stream().filter(z -> matchesCity(z, norm)).toList();
        return inCity.stream().filter(DeliveryZone::isDefaultZone).findFirst()
                .or(() -> inCity.stream().findFirst())
                .orElseThrow(() -> ApiException.unprocessable("NOT_DELIVERABLE", "We do not deliver to this city yet"));
    }

    public List<DeliveryZone> activeZones() {
        return zones.findByActiveTrue();
    }

    private static boolean matchesCity(DeliveryZone z, String norm) {
        if (norm.contains(z.getCityCode())) {
            return true;
        }
        for (String alias : z.getCityAliases().split(",")) {
            String a = alias.trim();
            if (!a.isEmpty() && norm.contains(a)) {
                return true;
            }
        }
        return false;
    }

    static String normalizeCity(String city) {
        return city == null ? "" : city.toLowerCase(Locale.ROOT).replaceAll("[^\\p{L}\\p{N}]+", "");
    }

    static double distanceKm(double lat1, double lon1, double lat2, double lon2) {
        double r = 6371.0088;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        return 2 * r * Math.asin(Math.sqrt(a));
    }

    // ---------------------------------------------------------------------------------------------
    // Slots
    // ---------------------------------------------------------------------------------------------

    public DeliveryDtos.SlotsResponse slots(DeliveryZone zone, int days) {
        Instant now = clock.instant();
        LocalDate today = LocalDate.ofInstant(now, businessZone);
        int span = Math.max(1, Math.min(days, MAX_DAYS_AHEAD));
        List<DeliveryDtos.DaySlots> out = new ArrayList<>();
        List<DeliverySlotTemplate> tpl = templates.findByZoneIdAndActiveTrueOrderByStartTime(zone.getId());
        for (int i = 0; i < span; i++) {
            LocalDate date = today.plusDays(i);
            List<DeliveryDtos.SlotDto> slots = new ArrayList<>();
            for (DeliverySlotTemplate t : tpl) {
                if (t.runsOn(date.getDayOfWeek())) {
                    slots.add(describe(t, date, now));
                }
            }
            out.add(new DeliveryDtos.DaySlots(date, slots));
        }
        return new DeliveryDtos.SlotsResponse(zone.getId(), businessZone.getId(), asapAvailable(zone, now),
                zone.getAsapFee(), zone.getAsapEtaMinutes(), out);
    }

    private DeliveryDtos.SlotDto describe(DeliverySlotTemplate t, LocalDate date, Instant now) {
        Instant start = ZonedDateTime.of(date, t.getStartTime(), businessZone).toInstant();
        boolean beforeCutoff = !now.plusSeconds(t.getCutoffMinutes() * 60L).isAfter(start);
        int used = usage(t.getId(), date);
        int remaining = Math.max(0, t.getCapacity() - used);
        String reason = !beforeCutoff ? "PAST_CUTOFF" : remaining == 0 ? "FULL" : null;
        return new DeliveryDtos.SlotDto(t.getId(), date, t.getStartTime(), t.getEndTime(), reason == null, remaining,
                t.getSurcharge(), reason);
    }

    public boolean asapAvailable(DeliveryZone zone, Instant now) {
        if (!zone.isAsapEnabled()) {
            return false;
        }
        LocalDateTime local = LocalDateTime.ofInstant(now, businessZone);
        LocalTime t = local.toLocalTime();
        return !t.isBefore(zone.getWorkStart())
                && !local.plusMinutes(zone.getAsapEtaMinutes()).toLocalTime().isAfter(zone.getWorkEnd())
                && local.plusMinutes(zone.getAsapEtaMinutes()).toLocalDate().equals(local.toLocalDate());
    }

    /** Validates a slot choice for ordering. Must be called with the template row locked for the capacity check. */
    public ValidatedSlot validateSlot(DeliveryZone zone, UUID templateId, LocalDate date) {
        Instant now = clock.instant();
        LocalDate today = LocalDate.ofInstant(now, businessZone);
        if (date == null || date.isBefore(today) || date.isAfter(today.plusDays(MAX_DAYS_AHEAD))) {
            throw ApiException.unprocessable("SLOT_INVALID_DATE", "Delivery date is out of the allowed range");
        }
        DeliverySlotTemplate t = templates.lockById(templateId)
                .filter(x -> x.isActive() && x.getZoneId().equals(zone.getId()))
                .orElseThrow(() -> ApiException.unprocessable("SLOT_UNAVAILABLE", "Delivery slot is not available"));
        if (!t.runsOn(date.getDayOfWeek())) {
            throw ApiException.unprocessable("SLOT_UNAVAILABLE", "Delivery slot is not available on this day");
        }
        Instant start = ZonedDateTime.of(date, t.getStartTime(), businessZone).toInstant();
        if (now.plusSeconds(t.getCutoffMinutes() * 60L).isAfter(start)) {
            throw ApiException.unprocessable("SLOT_PAST_CUTOFF", "The cutoff time for this slot has passed");
        }
        if (usage(t.getId(), date) >= t.getCapacity()) {
            throw ApiException.unprocessable("SLOT_FULL", "This delivery slot is fully booked");
        }
        return new ValidatedSlot(t, date, start);
    }

    public record ValidatedSlot(DeliverySlotTemplate template, LocalDate date, Instant startsAt) {}

    @Transactional(readOnly = true)
    public Instant asapEta(DeliveryZone zone) {
        if (!asapAvailable(zone, clock.instant())) {
            throw ApiException.unprocessable("ASAP_UNAVAILABLE", "ASAP delivery is not available right now");
        }
        return clock.instant().plusSeconds(zone.getAsapEtaMinutes() * 60L);
    }

    int usage(UUID templateId, LocalDate date) {
        if (org.springframework.transaction.support.TransactionSynchronizationManager.isActualTransactionActive()) {
            em.flush(); // pending orders of the current transaction must be visible to the native count
        }
        Integer n = jdbc.queryForObject("""
                select count(*) from orders where slot_template_id = ? and delivery_date = ?
                and status not in ('CANCELLED','PAYMENT_FAILED','REFUNDED')""", Integer.class, templateId, date);
        return n == null ? 0 : n;
    }

    /** Delivery fee for a given post-discount subtotal. Free-delivery threshold applies to the zone base fee only. */
    public BigDecimal fee(DeliveryZone zone, BigDecimal subtotalAfterDiscount, BigDecimal slotSurcharge, boolean asap) {
        BigDecimal fee = Money.ZERO;
        boolean free = zone.getFreeDeliveryThreshold() != null
                && subtotalAfterDiscount.compareTo(zone.getFreeDeliveryThreshold()) >= 0;
        if (!free) {
            fee = fee.add(zone.getBaseFee());
        }
        if (slotSurcharge != null) {
            fee = fee.add(slotSurcharge);
        }
        if (asap) {
            fee = fee.add(zone.getAsapFee());
        }
        return Money.scale(fee);
    }
}
