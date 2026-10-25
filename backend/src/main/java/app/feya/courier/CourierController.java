package app.feya.courier;

import app.feya.common.ApiException;
import app.feya.common.PageResponse;
import app.feya.courier.CourierLocationRepository;
import app.feya.courier.CourierRepository;
import app.feya.florist.Florist;
import app.feya.florist.FloristRepository;
import app.feya.orders.Actor;
import app.feya.orders.OrderEntity;
import app.feya.orders.OrderRepository;
import app.feya.orders.OrderService;
import app.feya.orders.OrderStatus;
import app.feya.security.Auth;
import app.feya.tracking.SseHub;
import app.feya.tracking.TrackingService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.EnumSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/courier")
public class CourierController {
    private static final Set<OrderStatus> COURIER_SETTABLE = EnumSet.of(OrderStatus.PICKED_UP, OrderStatus.ON_THE_WAY,
            OrderStatus.DELIVERED, OrderStatus.READY_FOR_PICKUP);

    public record ProfileDto(UUID userId, String vehicle, boolean onShift, boolean locationSharing) {}

    public record ShiftRequest(@NotNull Boolean onShift, @NotNull Boolean locationSharing) {}

    public record StatusRequest(@NotNull OrderStatus status) {}

    public record LocationRequest(@NotNull @DecimalMin("-90") @DecimalMax("90") BigDecimal latitude,
                                  @NotNull @DecimalMin("-180") @DecimalMax("180") BigDecimal longitude,
                                  @DecimalMin("0") @DecimalMax("100000") BigDecimal accuracyM, Instant recordedAt,
                                  UUID orderId) {}

    public record CourierOrder(UUID id, String number, OrderStatus status, String pickupName, String pickupAddress,
                               String deliveryAddress, String recipientName, String recipientPhone,
                               String instructions, LocalDate deliveryDate, LocalTime slotStart, LocalTime slotEnd,
                               boolean asap, Instant eta) {}

    private final CourierRepository couriers;
    private final CourierLocationRepository locations;
    private final OrderRepository orders;
    private final OrderService orderService;
    private final FloristRepository florists;
    private final SseHub hub;
    private final TrackingService tracking;
    private final Clock clock;

    public CourierController(CourierRepository couriers, CourierLocationRepository locations, OrderRepository orders,
                             OrderService orderService, FloristRepository florists, SseHub hub,
                             TrackingService tracking, Clock clock) {
        this.couriers = couriers;
        this.locations = locations;
        this.orders = orders;
        this.orderService = orderService;
        this.florists = florists;
        this.hub = hub;
        this.tracking = tracking;
        this.clock = clock;
    }

    @GetMapping("/me")
    public ProfileDto me() {
        Courier c = courier();
        return new ProfileDto(c.getUserId(), c.getVehicle(), c.isOnShift(), c.isLocationSharing());
    }

    @PutMapping("/shift")
    @Transactional
    public ProfileDto shift(@Valid @RequestBody ShiftRequest req) {
        Courier c = courier();
        c.setOnShift(req.onShift());
        // Sharing is only meaningful on shift; going off shift always stops it.
        c.setLocationSharing(req.onShift() && req.locationSharing());
        return new ProfileDto(c.getUserId(), c.getVehicle(), c.isOnShift(), c.isLocationSharing());
    }

    /** scope=available: ready orders nobody has claimed; scope=mine: orders assigned to this courier and in progress. */
    @GetMapping("/orders")
    @Transactional(readOnly = true)
    public PageResponse<CourierOrder> orders(@RequestParam(defaultValue = "mine") String scope,
                                             @RequestParam(defaultValue = "0") int page,
                                             @RequestParam(defaultValue = "20") int size) {
        UUID me = courier().getUserId();
        Specification<OrderEntity> spec = "available".equals(scope)
                ? (r, q, cb) -> cb.and(cb.equal(r.get("status"), OrderStatus.READY_FOR_PICKUP), cb.isNull(r.get("courierId")))
                : (r, q, cb) -> cb.and(cb.equal(r.get("courierId"), me),
                        r.get("status").in(OrderStatus.COURIER_ASSIGNED, OrderStatus.PICKED_UP, OrderStatus.ON_THE_WAY));
        var result = orders.findAll(spec, PageRequest.of(Math.max(0, page), Math.max(1, Math.min(size, 50)),
                Sort.by("etaAt").ascending()));
        return PageResponse.of(result, o -> toDto(o, "mine".equals(scope)));
    }

    @PostMapping("/orders/{id}/claim")
    @Transactional
    public CourierOrder claim(@PathVariable UUID id) {
        Courier c = courier();
        if (!c.isOnShift()) {
            throw ApiException.conflict("NOT_ON_SHIFT", "Start your shift first");
        }
        OrderEntity o = orders.lockById(id).orElseThrow(() -> ApiException.notFound("Order"));
        if (o.getCourierId() != null) {
            throw ApiException.conflict("ALREADY_CLAIMED", "Order is already assigned");
        }
        o.setCourierId(c.getUserId());
        orderService.transition(o, OrderStatus.COURIER_ASSIGNED, Actor.COURIER, c.getUserId(), null);
        return toDto(o, true);
    }

    @PostMapping("/orders/{id}/status")
    @Transactional
    public CourierOrder status(@PathVariable UUID id, @Valid @RequestBody StatusRequest req) {
        Courier c = courier();
        if (!COURIER_SETTABLE.contains(req.status())) {
            throw ApiException.forbidden("This status cannot be set by a courier");
        }
        OrderEntity o = orders.lockById(id).filter(x -> c.getUserId().equals(x.getCourierId()))
                .orElseThrow(() -> ApiException.notFound("Order"));
        orderService.transition(o, req.status(), Actor.COURIER, c.getUserId(), null);
        if (req.status() == OrderStatus.READY_FOR_PICKUP) {
            o.setCourierId(null); // courier released the order back to the pool
        }
        return toDto(o, o.getCourierId() != null);
    }

    /** Accepts positions only from an on-shift courier who enabled sharing; stale/future timestamps are rejected. */
    @PostMapping("/location")
    @Transactional
    public void location(@Valid @RequestBody LocationRequest req) {
        Courier c = courier();
        if (!c.isOnShift() || !c.isLocationSharing()) {
            throw ApiException.conflict("LOCATION_SHARING_OFF", "Location sharing is not enabled");
        }
        Instant now = clock.instant();
        Instant at = req.recordedAt() == null ? now : req.recordedAt();
        if (at.isAfter(now.plusSeconds(60)) || at.isBefore(now.minus(Duration.ofMinutes(2)))) {
            throw ApiException.badRequest("INVALID_TIMESTAMP", "Location timestamp is out of range");
        }
        OrderEntity order = null;
        if (req.orderId() != null) {
            order = orders.findById(req.orderId()).filter(o -> c.getUserId().equals(o.getCourierId()))
                    .orElseThrow(() -> ApiException.notFound("Order"));
        }
        CourierLocation l = new CourierLocation();
        l.setCourierId(c.getUserId());
        l.setOrderId(order == null ? null : order.getId());
        l.setLatitude(req.latitude());
        l.setLongitude(req.longitude());
        l.setAccuracyM(req.accuracyM());
        l.setRecordedAt(at);
        locations.save(l);
        if (order != null && hub.subscribers(order.getId()) > 0) {
            hub.publish(order.getId(), tracking.build(order.getId()));
        }
    }

    private Courier courier() {
        UUID uid = Auth.userId();
        return couriers.findById(uid).filter(Courier::isActive)
                .orElseThrow(() -> ApiException.forbidden("No active courier profile"));
    }

    private CourierOrder toDto(OrderEntity o, boolean assignedToMe) {
        Florist f = florists.findById(o.getFloristId()).orElse(null);
        String address = o.getAddrStreet() + " " + o.getAddrBuilding()
                + (o.getAddrApartment() == null ? "" : ", кв. " + o.getAddrApartment())
                + (o.getAddrEntrance() == null ? "" : ", подъезд " + o.getAddrEntrance())
                + (o.getAddrFloor() == null ? "" : ", этаж " + o.getAddrFloor());
        // Recipient contact details are only released to the courier who carries the order.
        return new CourierOrder(o.getId(), o.getNumber(), o.getStatus(), f == null ? null : f.getName(),
                f == null ? null : f.getAddress(), o.getAddrCity() + ", " + address,
                assignedToMe ? o.getRecipientName() : null, assignedToMe ? o.getRecipientPhone() : null,
                assignedToMe ? o.getInstructions() : null, o.getDeliveryDate(), o.getSlotStart(), o.getSlotEnd(),
                o.isDeliveryAsap(), o.getEtaAt());
    }
}
