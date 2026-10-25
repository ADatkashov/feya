package app.feya.orders;

import java.util.UUID;

/** Published synchronously inside the transition transaction; listeners that must not fail it use AFTER_COMMIT. */
public record OrderStatusChanged(UUID orderId, UUID userId, OrderStatus from, OrderStatus to, Actor actor) {}
