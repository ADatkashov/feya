package app.feya;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import app.feya.common.ApiException;
import app.feya.orders.Actor;
import app.feya.orders.OrderStateMachine;
import app.feya.orders.OrderStatus;
import java.util.EnumSet;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

class OrderStateMachineTest {

    @Test
    void happyPathIsAllowedForTheRightActors() {
        assertThat(OrderStateMachine.canTransition(OrderStatus.CREATED, OrderStatus.PENDING_PAYMENT, Actor.SYSTEM)).isTrue();
        assertThat(OrderStateMachine.canTransition(OrderStatus.PENDING_PAYMENT, OrderStatus.PAID, Actor.SYSTEM)).isTrue();
        assertThat(OrderStateMachine.canTransition(OrderStatus.PAID, OrderStatus.CONFIRMED, Actor.FLORIST)).isTrue();
        assertThat(OrderStateMachine.canTransition(OrderStatus.CONFIRMED, OrderStatus.PREPARING, Actor.FLORIST)).isTrue();
        assertThat(OrderStateMachine.canTransition(OrderStatus.PREPARING, OrderStatus.READY_FOR_PICKUP, Actor.FLORIST)).isTrue();
        assertThat(OrderStateMachine.canTransition(OrderStatus.READY_FOR_PICKUP, OrderStatus.COURIER_ASSIGNED, Actor.COURIER)).isTrue();
        assertThat(OrderStateMachine.canTransition(OrderStatus.COURIER_ASSIGNED, OrderStatus.PICKED_UP, Actor.COURIER)).isTrue();
        assertThat(OrderStateMachine.canTransition(OrderStatus.PICKED_UP, OrderStatus.ON_THE_WAY, Actor.COURIER)).isTrue();
        assertThat(OrderStateMachine.canTransition(OrderStatus.ON_THE_WAY, OrderStatus.DELIVERED, Actor.COURIER)).isTrue();
    }

    @Test
    void customersCanOnlyCancelEarly() {
        Set<OrderStatus> cancellable = EnumSet.noneOf(OrderStatus.class);
        for (OrderStatus s : OrderStatus.values()) {
            if (OrderStateMachine.canTransition(s, OrderStatus.CANCELLED, Actor.CUSTOMER)) cancellable.add(s);
        }
        assertThat(cancellable).containsExactlyInAnyOrder(OrderStatus.PENDING_PAYMENT, OrderStatus.PAYMENT_FAILED,
                OrderStatus.PAID, OrderStatus.CONFIRMED);
    }

    @ParameterizedTest
    @EnumSource(OrderStatus.class)
    void customersCanNeverDriveFulfilmentOrPaymentStatuses(OrderStatus from) {
        for (OrderStatus to : new OrderStatus[] {OrderStatus.PAID, OrderStatus.CONFIRMED, OrderStatus.PREPARING,
                OrderStatus.READY_FOR_PICKUP, OrderStatus.COURIER_ASSIGNED, OrderStatus.PICKED_UP, OrderStatus.ON_THE_WAY,
                OrderStatus.DELIVERED, OrderStatus.REFUNDED, OrderStatus.PAYMENT_FAILED}) {
            assertThat(OrderStateMachine.canTransition(from, to, Actor.CUSTOMER)).as("%s -> %s", from, to).isFalse();
        }
    }

    @Test
    void paymentOutcomesAreSystemOnly() {
        for (Actor a : Actor.values()) {
            if (a == Actor.SYSTEM) continue;
            assertThat(OrderStateMachine.canTransition(OrderStatus.PENDING_PAYMENT, OrderStatus.PAID, a)).isFalse();
            assertThat(OrderStateMachine.canTransition(OrderStatus.PENDING_PAYMENT, OrderStatus.PAYMENT_FAILED, a)).isFalse();
        }
    }

    @ParameterizedTest
    @EnumSource(Actor.class)
    void refundedAndFinalStatesHaveNoExit(Actor actor) {
        for (OrderStatus to : OrderStatus.values()) {
            assertThat(OrderStateMachine.isLegalMove(OrderStatus.REFUNDED, to)).isFalse();
            assertThat(OrderStateMachine.canTransition(OrderStatus.DELIVERED, to, actor))
                    .isEqualTo(to == OrderStatus.REFUNDED && actor != Actor.CUSTOMER && actor != Actor.FLORIST && actor != Actor.COURIER);
        }
    }

    @Test
    void couriersCannotSkipSteps() {
        assertThat(OrderStateMachine.canTransition(OrderStatus.COURIER_ASSIGNED, OrderStatus.DELIVERED, Actor.COURIER)).isFalse();
        assertThat(OrderStateMachine.canTransition(OrderStatus.READY_FOR_PICKUP, OrderStatus.ON_THE_WAY, Actor.COURIER)).isFalse();
        assertThat(OrderStateMachine.canTransition(OrderStatus.ON_THE_WAY, OrderStatus.CANCELLED, Actor.ADMIN)).isFalse();
    }

    @Test
    void requireDistinguishesIllegalMovesFromMissingPermission() {
        assertThatThrownBy(() -> OrderStateMachine.require(OrderStatus.PAID, OrderStatus.DELIVERED, Actor.ADMIN))
                .isInstanceOfSatisfying(ApiException.class, e -> assertThat(e.code()).isEqualTo("INVALID_TRANSITION"));
        assertThatThrownBy(() -> OrderStateMachine.require(OrderStatus.PAID, OrderStatus.CONFIRMED, Actor.CUSTOMER))
                .isInstanceOfSatisfying(ApiException.class, e -> assertThat(e.code()).isEqualTo("FORBIDDEN"));
    }
}
