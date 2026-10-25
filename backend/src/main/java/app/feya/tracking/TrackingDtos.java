package app.feya.tracking;

import app.feya.orders.OrderDtos;
import app.feya.orders.OrderEntity;
import app.feya.orders.OrderStatus;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class TrackingDtos {
    private TrackingDtos() {}

    public record CourierInfo(String name, String phone, String vehicle) {}

    /** A real, recent position reported by the courier app. Absent when no valid fresh update exists. */
    public record Location(BigDecimal latitude, BigDecimal longitude, Instant updatedAt) {}

    public record Tracking(UUID orderId, String number, OrderStatus status, OrderEntity.PaymentState paymentStatus,
                           Instant eta, List<OrderDtos.TimelineEntry> timeline, CourierInfo courier,
                           Location courierLocation, boolean liveTracking, Instant serverTime) {}
}
