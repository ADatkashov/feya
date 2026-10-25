package app.feya.tracking;

import app.feya.common.ApiException;
import app.feya.common.FeyaProperties;
import app.feya.courier.Courier;
import app.feya.courier.CourierLocation;
import app.feya.courier.CourierLocationRepository;
import app.feya.courier.CourierRepository;
import app.feya.identity.User;
import app.feya.identity.UserRepository;
import app.feya.orders.OrderDtos;
import app.feya.orders.OrderEntity;
import app.feya.orders.OrderRepository;
import app.feya.orders.OrderStatus;
import app.feya.orders.OrderStatusHistoryRepository;
import java.time.Clock;
import java.time.Instant;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class TrackingService {
    private final OrderRepository orders;
    private final OrderStatusHistoryRepository history;
    private final UserRepository users;
    private final CourierRepository couriers;
    private final CourierLocationRepository locations;
    private final FeyaProperties props;
    private final Clock clock;

    public TrackingService(OrderRepository orders, OrderStatusHistoryRepository history, UserRepository users,
                           CourierRepository couriers, CourierLocationRepository locations, FeyaProperties props,
                           Clock clock) {
        this.orders = orders;
        this.history = history;
        this.users = users;
        this.couriers = couriers;
        this.locations = locations;
        this.props = props;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public TrackingDtos.Tracking forCustomer(UUID userId, UUID orderId) {
        OrderEntity o = orders.findByIdAndUserId(orderId, userId).orElseThrow(() -> ApiException.notFound("Order"));
        return build(o);
    }

    @Transactional(readOnly = true)
    public TrackingDtos.Tracking build(UUID orderId) {
        return build(orders.findById(orderId).orElseThrow(() -> ApiException.notFound("Order")));
    }

    TrackingDtos.Tracking build(OrderEntity o) {
        var timeline = history.findByOrderIdOrderByCreatedAt(o.getId()).stream()
                .map(h -> new OrderDtos.TimelineEntry(h.getToStatus(), h.getCreatedAt(), null)).toList();
        TrackingDtos.CourierInfo courier = null;
        TrackingDtos.Location location = null;
        if (o.getCourierId() != null && o.getStatus() != OrderStatus.DELIVERED && o.getStatus().active()
                || o.getCourierId() != null && o.getStatus() == OrderStatus.DELIVERED) {
            User cu = users.findById(o.getCourierId()).orElse(null);
            Courier c = couriers.findById(o.getCourierId()).orElse(null);
            if (cu != null) {
                courier = new TrackingDtos.CourierInfo(cu.getName() == null ? "Courier" : cu.getName(), cu.getPhone(),
                        c == null ? null : c.getVehicle());
            }
            location = liveLocation(o, c);
        }
        return new TrackingDtos.Tracking(o.getId(), o.getNumber(), o.getStatus(), o.getPaymentStatus(), o.getEtaAt(),
                timeline, courier, location, location != null, clock.instant());
    }

    /** Only a fresh position from a courier who is on shift, sharing location, and carrying this order. */
    private TrackingDtos.Location liveLocation(OrderEntity o, Courier c) {
        if (c == null || !c.isOnShift() || !c.isLocationSharing()
                || o.getStatus() != OrderStatus.PICKED_UP && o.getStatus() != OrderStatus.ON_THE_WAY) {
            return null;
        }
        CourierLocation l = locations.findFirstByCourierIdOrderByRecordedAtDesc(c.getUserId()).orElse(null);
        if (l == null) {
            return null;
        }
        Instant oldest = clock.instant().minus(props.tracking().locationTtl());
        if (l.getRecordedAt().isBefore(oldest)) {
            return null;
        }
        return new TrackingDtos.Location(l.getLatitude(), l.getLongitude(), l.getRecordedAt());
    }
}
