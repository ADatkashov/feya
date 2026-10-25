package app.feya.administration;

import app.feya.common.ApiException;
import app.feya.common.AuditService;
import app.feya.delivery.DeliverySlotTemplate;
import app.feya.delivery.DeliverySlotTemplateRepository;
import app.feya.delivery.DeliveryZone;
import app.feya.delivery.DeliveryZoneRepository;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import java.math.BigDecimal;
import java.time.LocalTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/admin")
@PreAuthorize("hasRole('ADMIN')")
public class AdminDeliveryController {
    public record ZoneUpsert(@NotBlank @Pattern(regexp = "[a-z0-9][a-z0-9-]{1,38}") String code,
                             @NotBlank String cityCode, String cityAliases, @NotEmpty Map<String, String> name,
                             @NotNull @DecimalMin("-90") @DecimalMax("90") BigDecimal centerLat,
                             @NotNull @DecimalMin("-180") @DecimalMax("180") BigDecimal centerLng,
                             @NotNull @DecimalMin("0.1") BigDecimal radiusKm, @NotNull @DecimalMin("0") BigDecimal baseFee,
                             BigDecimal freeDeliveryThreshold, boolean asapEnabled, @DecimalMin("0") BigDecimal asapFee,
                             @Min(15) @Max(600) int asapEtaMinutes, @NotNull LocalTime workStart,
                             @NotNull LocalTime workEnd, boolean defaultZone, boolean active) {}

    public record ZoneAdmin(UUID id, String code, String cityCode, String cityAliases, Map<String, String> name,
                            BigDecimal centerLat, BigDecimal centerLng, BigDecimal radiusKm, BigDecimal baseFee,
                            BigDecimal freeDeliveryThreshold, boolean asapEnabled, BigDecimal asapFee,
                            int asapEtaMinutes, LocalTime workStart, LocalTime workEnd, boolean defaultZone,
                            boolean active) {}

    public record SlotUpsert(@NotNull LocalTime startTime, @NotNull LocalTime endTime, @Min(1) @Max(1000) int capacity,
                             @Min(0) @Max(2880) int cutoffMinutes, @DecimalMin("0") BigDecimal surcharge,
                             @Pattern(regexp = "[1-7](,[1-7])*") String daysOfWeek, boolean active) {}

    public record SlotAdmin(UUID id, UUID zoneId, LocalTime startTime, LocalTime endTime, int capacity,
                            int cutoffMinutes, BigDecimal surcharge, String daysOfWeek, boolean active) {}

    private final DeliveryZoneRepository zones;
    private final DeliverySlotTemplateRepository slots;
    private final AuditService audit;

    public AdminDeliveryController(DeliveryZoneRepository zones, DeliverySlotTemplateRepository slots, AuditService audit) {
        this.zones = zones;
        this.slots = slots;
        this.audit = audit;
    }

    @GetMapping("/zones")
    public List<ZoneAdmin> zones() {
        return zones.findAll().stream().map(this::dto).toList();
    }

    @PostMapping("/zones")
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public ZoneAdmin createZone(@Valid @RequestBody ZoneUpsert req) {
        if (zones.findByCode(req.code()).isPresent()) {
            throw ApiException.conflict("CODE_TAKEN", "Zone code is already in use");
        }
        DeliveryZone z = new DeliveryZone();
        apply(z, req);
        z = zones.save(z);
        audit.record("ZONE_CREATED", "ZONE", z.getId(), z.getCode());
        return dto(z);
    }

    @PutMapping("/zones/{id}")
    @Transactional
    public ZoneAdmin updateZone(@PathVariable UUID id, @Valid @RequestBody ZoneUpsert req) {
        DeliveryZone z = zones.findById(id).orElseThrow(() -> ApiException.notFound("Zone"));
        zones.findByCode(req.code()).filter(o -> !o.getId().equals(id)).ifPresent(o -> {
            throw ApiException.conflict("CODE_TAKEN", "Zone code is already in use");
        });
        apply(z, req);
        audit.record("ZONE_UPDATED", "ZONE", z.getId(), z.getCode());
        return dto(z);
    }

    @GetMapping("/zones/{zoneId}/slots")
    public List<SlotAdmin> slots(@PathVariable UUID zoneId) {
        return slots.findByZoneIdOrderByStartTime(zoneId).stream().map(this::slotDto).toList();
    }

    @PostMapping("/zones/{zoneId}/slots")
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public SlotAdmin createSlot(@PathVariable UUID zoneId, @Valid @RequestBody SlotUpsert req) {
        if (!zones.existsById(zoneId)) {
            throw ApiException.notFound("Zone");
        }
        DeliverySlotTemplate t = new DeliverySlotTemplate();
        t.setZoneId(zoneId);
        apply(t, req);
        t = slots.save(t);
        audit.record("SLOT_CREATED", "SLOT", t.getId(), null);
        return slotDto(t);
    }

    @PutMapping("/slots/{id}")
    @Transactional
    public SlotAdmin updateSlot(@PathVariable UUID id, @Valid @RequestBody SlotUpsert req) {
        DeliverySlotTemplate t = slots.findById(id).orElseThrow(() -> ApiException.notFound("Slot"));
        apply(t, req);
        audit.record("SLOT_UPDATED", "SLOT", t.getId(), null);
        return slotDto(t);
    }

    private void apply(DeliverySlotTemplate t, SlotUpsert r) {
        if (!r.endTime().isAfter(r.startTime())) {
            throw ApiException.badRequest("INVALID_SLOT", "End time must be after start time");
        }
        t.setStartTime(r.startTime());
        t.setEndTime(r.endTime());
        t.setCapacity(r.capacity());
        t.setCutoffMinutes(r.cutoffMinutes());
        t.setSurcharge(r.surcharge() == null ? BigDecimal.ZERO : r.surcharge());
        t.setDaysOfWeek(r.daysOfWeek() == null ? "1,2,3,4,5,6,7" : r.daysOfWeek());
        t.setActive(r.active());
    }

    private void apply(DeliveryZone z, ZoneUpsert r) {
        if (r.name().get("ru") == null || r.name().get("ru").isBlank()) {
            throw ApiException.badRequest("RU_TEXT_REQUIRED", "Russian name is required");
        }
        if (!r.workEnd().isAfter(r.workStart())) {
            throw ApiException.badRequest("INVALID_HOURS", "Working hours end must be after start");
        }
        z.setCode(r.code());
        z.setCityCode(r.cityCode().toLowerCase());
        z.setCityAliases(r.cityAliases() == null ? "" : r.cityAliases().toLowerCase());
        z.setName(r.name());
        z.setCenterLat(r.centerLat());
        z.setCenterLng(r.centerLng());
        z.setRadiusKm(r.radiusKm());
        z.setBaseFee(r.baseFee());
        z.setFreeDeliveryThreshold(r.freeDeliveryThreshold());
        z.setAsapEnabled(r.asapEnabled());
        z.setAsapFee(r.asapFee() == null ? BigDecimal.ZERO : r.asapFee());
        z.setAsapEtaMinutes(r.asapEtaMinutes());
        z.setWorkStart(r.workStart());
        z.setWorkEnd(r.workEnd());
        z.setDefaultZone(r.defaultZone());
        z.setActive(r.active());
        if (r.defaultZone()) {
            // At most one default zone per city.
            zones.findAll().stream().filter(o -> o.isDefaultZone() && o.getCityCode().equals(z.getCityCode())
                    && !o.getId().equals(z.getId())).forEach(o -> o.setDefaultZone(false));
        }
    }

    private ZoneAdmin dto(DeliveryZone z) {
        return new ZoneAdmin(z.getId(), z.getCode(), z.getCityCode(), z.getCityAliases(), z.getName(), z.getCenterLat(),
                z.getCenterLng(), z.getRadiusKm(), z.getBaseFee(), z.getFreeDeliveryThreshold(), z.isAsapEnabled(),
                z.getAsapFee(), z.getAsapEtaMinutes(), z.getWorkStart(), z.getWorkEnd(), z.isDefaultZone(), z.isActive());
    }

    private SlotAdmin slotDto(DeliverySlotTemplate t) {
        return new SlotAdmin(t.getId(), t.getZoneId(), t.getStartTime(), t.getEndTime(), t.getCapacity(),
                t.getCutoffMinutes(), t.getSurcharge(), t.getDaysOfWeek(), t.isActive());
    }
}
