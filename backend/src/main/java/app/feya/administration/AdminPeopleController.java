package app.feya.administration;

import app.feya.common.ApiException;
import app.feya.common.AuditService;
import app.feya.common.PageResponse;
import app.feya.courier.Courier;
import app.feya.courier.CourierRepository;
import app.feya.delivery.DeliveryZoneRepository;
import app.feya.florist.Florist;
import app.feya.florist.FloristRepository;
import app.feya.identity.PhoneNumbers;
import app.feya.identity.RefreshTokenRepository;
import app.feya.identity.Role;
import app.feya.identity.User;
import app.feya.identity.UserRepository;
import app.feya.identity.UserStatus;
import app.feya.security.Auth;
import jakarta.persistence.criteria.Predicate;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Customers, staff accounts, florist shops and couriers. */
@RestController
@RequestMapping("/api/v1/admin")
public class AdminPeopleController {
    public record UserRow(UUID id, String phone, String name, String email, List<String> roles, String status,
                          UUID floristId, Instant createdAt, Instant lastLoginAt) {}

    public record StatusRequest(@NotNull UserStatus status) {}

    public record RolesRequest(@NotNull Set<Role> roles, UUID floristId) {}

    public record FloristUpsert(@NotBlank @Size(max = 160) String name, @NotBlank @Size(max = 80) String city,
                                @Size(max = 255) String address, @Size(max = 24) String phone, int priority,
                                boolean active, Set<UUID> zoneIds) {}

    public record FloristRow(UUID id, String name, String city, String address, String phone, int priority,
                             boolean active, Set<UUID> zoneIds) {}

    public record CourierUpsert(@NotBlank @Size(max = 24) String phone, @Size(max = 120) String name,
                                @Size(max = 60) String vehicle, boolean active) {}

    public record CourierRow(UUID userId, String phone, String name, String vehicle, boolean active, boolean onShift,
                             boolean locationSharing) {}

    private final UserRepository users;
    private final RefreshTokenRepository refreshTokens;
    private final FloristRepository florists;
    private final CourierRepository couriers;
    private final DeliveryZoneRepository zones;
    private final AuditService audit;
    private final Clock clock;

    public AdminPeopleController(UserRepository users, RefreshTokenRepository refreshTokens, FloristRepository florists,
                                 CourierRepository couriers, DeliveryZoneRepository zones, AuditService audit, Clock clock) {
        this.users = users;
        this.refreshTokens = refreshTokens;
        this.florists = florists;
        this.couriers = couriers;
        this.zones = zones;
        this.audit = audit;
        this.clock = clock;
    }

    // --- Customers & staff accounts -----------------------------------------------------------

    @GetMapping("/customers")
    @Transactional(readOnly = true)
    public PageResponse<UserRow> customers(@RequestParam(required = false) String q,
                                           @RequestParam(required = false) Role role,
                                           @RequestParam(defaultValue = "0") int page,
                                           @RequestParam(defaultValue = "20") int size) {
        Specification<User> spec = (r, cq, cb) -> {
            List<Predicate> ps = new ArrayList<>();
            if (q != null && !q.isBlank()) {
                String like = "%" + q.trim().toLowerCase().replace("%", "\\%").replace("_", "\\_") + "%";
                ps.add(cb.or(cb.like(r.get("phone"), like, '\\'), cb.like(cb.lower(r.get("name")), like, '\\')));
            }
            if (role != null) {
                ps.add(cb.isMember(role, r.<Set<Role>>get("roles")));
            }
            return cb.and(ps.toArray(Predicate[]::new));
        };
        return PageResponse.of(users.findAll(spec, PageRequest.of(Math.max(0, page), Math.max(1, Math.min(size, 100)),
                Sort.by(Sort.Order.desc("createdAt")))), this::row);
    }

    @PatchMapping("/customers/{id}/status")
    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public UserRow setStatus(@PathVariable UUID id, @Valid @RequestBody StatusRequest req) {
        User u = users.findById(id).orElseThrow(() -> ApiException.notFound("User"));
        if (u.getId().equals(Auth.userId())) {
            throw ApiException.badRequest("SELF_MODIFICATION", "You cannot change your own status");
        }
        u.setStatus(req.status());
        if (req.status() == UserStatus.BLOCKED) {
            refreshTokens.revokeAllForUser(u.getId(), clock.instant());
        }
        audit.record("USER_STATUS_SET", "USER", u.getId(), req.status().name());
        return row(u);
    }

    @PutMapping("/customers/{id}/roles")
    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public UserRow setRoles(@PathVariable UUID id, @Valid @RequestBody RolesRequest req) {
        User u = users.findById(id).orElseThrow(() -> ApiException.notFound("User"));
        if (u.getId().equals(Auth.userId())) {
            throw ApiException.badRequest("SELF_MODIFICATION", "You cannot change your own roles");
        }
        Set<Role> roles = EnumSet.of(Role.CUSTOMER);
        roles.addAll(req.roles());
        if (roles.contains(Role.FLORIST)) {
            if (req.floristId() == null || !florists.existsById(req.floristId())) {
                throw ApiException.badRequest("FLORIST_REQUIRED", "A florist shop is required for the FLORIST role");
            }
            u.setFloristId(req.floristId());
        } else {
            u.setFloristId(null);
        }
        u.setRoles(roles);
        if (roles.contains(Role.COURIER) && !couriers.existsById(u.getId())) {
            Courier c = new Courier();
            c.setUserId(u.getId());
            couriers.save(c);
        }
        refreshTokens.revokeAllForUser(u.getId(), clock.instant()); // force re-login so tokens carry the new roles
        audit.record("USER_ROLES_SET", "USER", u.getId(), roles.toString());
        return row(u);
    }

    // --- Florists ---------------------------------------------------------------------------------

    @GetMapping("/florists")
    @PreAuthorize("hasAnyRole('ADMIN','SUPPORT')")
    @Transactional(readOnly = true)
    public List<FloristRow> florists() {
        return florists.findAll(Sort.by("name")).stream().map(this::floristRow).toList();
    }

    @PostMapping("/florists")
    @PreAuthorize("hasRole('ADMIN')")
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public FloristRow createFlorist(@Valid @RequestBody FloristUpsert req) {
        Florist f = new Florist();
        applyFlorist(f, req);
        f = florists.save(f);
        audit.record("FLORIST_CREATED", "FLORIST", f.getId(), f.getName());
        return floristRow(f);
    }

    @PutMapping("/florists/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public FloristRow updateFlorist(@PathVariable UUID id, @Valid @RequestBody FloristUpsert req) {
        Florist f = florists.findById(id).orElseThrow(() -> ApiException.notFound("Florist"));
        applyFlorist(f, req);
        audit.record("FLORIST_UPDATED", "FLORIST", f.getId(), f.getName());
        return floristRow(f);
    }

    private void applyFlorist(Florist f, FloristUpsert req) {
        Set<UUID> zoneIds = req.zoneIds() == null ? Set.of() : req.zoneIds();
        if (zoneIds.stream().anyMatch(z -> !zones.existsById(z))) {
            throw ApiException.badRequest("INVALID_ZONE", "Unknown delivery zone");
        }
        f.setName(req.name().trim());
        f.setCity(req.city().trim());
        f.setAddress(req.address());
        f.setPhone(req.phone());
        f.setPriority(req.priority());
        f.setActive(req.active());
        f.getZoneIds().clear();
        f.getZoneIds().addAll(zoneIds);
    }

    // --- Couriers ---------------------------------------------------------------------------------

    @GetMapping("/couriers")
    @PreAuthorize("hasAnyRole('ADMIN','SUPPORT')")
    @Transactional(readOnly = true)
    public List<CourierRow> couriers() {
        return couriers.findAll().stream().map(this::courierRow).toList();
    }

    @PostMapping("/couriers")
    @PreAuthorize("hasRole('ADMIN')")
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public CourierRow createCourier(@Valid @RequestBody CourierUpsert req) {
        String phone = PhoneNumbers.normalize(req.phone());
        User u = users.findByPhone(phone).orElseGet(() -> {
            User n = new User();
            n.setPhone(phone);
            return users.save(n);
        });
        if (req.name() != null && !req.name().isBlank()) {
            u.setName(req.name().trim());
        }
        Set<Role> roles = EnumSet.copyOf(u.getRoles());
        roles.add(Role.COURIER);
        u.setRoles(roles);
        Courier c = couriers.findById(u.getId()).orElseGet(() -> {
            Courier n = new Courier();
            n.setUserId(u.getId());
            return n;
        });
        c.setVehicle(req.vehicle());
        c.setActive(req.active());
        couriers.save(c);
        refreshTokens.revokeAllForUser(u.getId(), clock.instant());
        audit.record("COURIER_SAVED", "COURIER", u.getId(), null);
        return courierRow(c);
    }

    @PatchMapping("/couriers/{userId}")
    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public CourierRow updateCourier(@PathVariable UUID userId, @Valid @RequestBody CourierUpsert req) {
        Courier c = couriers.findById(userId).orElseThrow(() -> ApiException.notFound("Courier"));
        c.setVehicle(req.vehicle());
        c.setActive(req.active());
        if (!req.active()) {
            c.setOnShift(false);
            c.setLocationSharing(false);
        }
        audit.record("COURIER_UPDATED", "COURIER", userId, null);
        return courierRow(c);
    }

    private UserRow row(User u) {
        return new UserRow(u.getId(), u.getPhone(), u.getName(), u.getEmail(),
                u.getRoles().stream().map(Enum::name).sorted().toList(), u.getStatus().name(), u.getFloristId(),
                u.getCreatedAt(), u.getLastLoginAt());
    }

    private FloristRow floristRow(Florist f) {
        return new FloristRow(f.getId(), f.getName(), f.getCity(), f.getAddress(), f.getPhone(), f.getPriority(),
                f.isActive(), Set.copyOf(f.getZoneIds()));
    }

    private CourierRow courierRow(Courier c) {
        User u = users.findById(c.getUserId()).orElse(null);
        return new CourierRow(c.getUserId(), u == null ? null : u.getPhone(), u == null ? null : u.getName(),
                c.getVehicle(), c.isActive(), c.isOnShift(), c.isLocationSharing());
    }
}
