package app.feya.orders;

import static app.feya.orders.Actor.ADMIN;
import static app.feya.orders.Actor.COURIER;
import static app.feya.orders.Actor.CUSTOMER;
import static app.feya.orders.Actor.FLORIST;
import static app.feya.orders.Actor.SUPPORT;
import static app.feya.orders.Actor.SYSTEM;
import static app.feya.orders.OrderStatus.*;

import app.feya.common.ApiException;
import java.util.EnumMap;
import java.util.EnumSet;
import java.util.Map;
import java.util.Set;

/** The single source of truth for which status changes are legal and who may perform them. */
public final class OrderStateMachine {
    private static final Map<OrderStatus, Map<OrderStatus, Set<Actor>>> RULES = new EnumMap<>(OrderStatus.class);

    static {
        allow(CREATED, PENDING_PAYMENT, SYSTEM);

        allow(PENDING_PAYMENT, PAID, SYSTEM);
        allow(PENDING_PAYMENT, PAYMENT_FAILED, SYSTEM);
        allow(PENDING_PAYMENT, CANCELLED, CUSTOMER, SYSTEM, ADMIN, SUPPORT);

        allow(PAYMENT_FAILED, PENDING_PAYMENT, SYSTEM);
        allow(PAYMENT_FAILED, PAID, SYSTEM); // a delayed provider confirmation after a reported failure
        allow(PAYMENT_FAILED, CANCELLED, CUSTOMER, SYSTEM, ADMIN, SUPPORT);

        allow(PAID, CONFIRMED, FLORIST, ADMIN, SUPPORT);
        allow(PAID, CANCELLED, CUSTOMER, FLORIST, ADMIN, SUPPORT);

        allow(CONFIRMED, PREPARING, FLORIST, ADMIN);
        allow(CONFIRMED, CANCELLED, CUSTOMER, FLORIST, ADMIN, SUPPORT);

        allow(PREPARING, READY_FOR_PICKUP, FLORIST, ADMIN);
        allow(PREPARING, CANCELLED, FLORIST, ADMIN, SUPPORT);

        allow(READY_FOR_PICKUP, COURIER_ASSIGNED, COURIER, ADMIN, SUPPORT);
        allow(READY_FOR_PICKUP, CANCELLED, ADMIN, SUPPORT);

        allow(COURIER_ASSIGNED, PICKED_UP, COURIER, ADMIN);
        allow(COURIER_ASSIGNED, READY_FOR_PICKUP, COURIER, ADMIN, SUPPORT);
        allow(COURIER_ASSIGNED, CANCELLED, ADMIN, SUPPORT);

        allow(PICKED_UP, ON_THE_WAY, COURIER, ADMIN);
        allow(ON_THE_WAY, DELIVERED, COURIER, ADMIN);

        allow(DELIVERED, REFUNDED, ADMIN, SUPPORT, SYSTEM); // SYSTEM completes an admin-initiated refund
        allow(CANCELLED, REFUNDED, SYSTEM, ADMIN);
    }

    private OrderStateMachine() {}

    private static void allow(OrderStatus from, OrderStatus to, Actor... actors) {
        RULES.computeIfAbsent(from, k -> new EnumMap<>(OrderStatus.class)).put(to, EnumSet.of(actors[0], actors));
    }

    public static boolean canTransition(OrderStatus from, OrderStatus to, Actor actor) {
        return RULES.getOrDefault(from, Map.of()).getOrDefault(to, Set.of()).contains(actor);
    }

    public static boolean isLegalMove(OrderStatus from, OrderStatus to) {
        return RULES.getOrDefault(from, Map.of()).containsKey(to);
    }

    /** Statuses the given actor may move an order to from {@code from}. */
    public static Set<OrderStatus> allowedTargets(OrderStatus from, Actor actor) {
        Set<OrderStatus> out = EnumSet.noneOf(OrderStatus.class);
        RULES.getOrDefault(from, Map.of()).forEach((to, actors) -> {
            if (actors.contains(actor)) {
                out.add(to);
            }
        });
        return out;
    }

    public static void require(OrderStatus from, OrderStatus to, Actor actor) {
        if (!isLegalMove(from, to)) {
            throw ApiException.conflict("INVALID_TRANSITION", "Order cannot move from " + from + " to " + to);
        }
        if (!canTransition(from, to, actor)) {
            throw ApiException.forbidden("This action is not permitted for the current role");
        }
    }
}
