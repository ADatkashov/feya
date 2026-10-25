package app.feya.orders;

public enum OrderStatus {
    CREATED, PENDING_PAYMENT, PAID, CONFIRMED, PREPARING, READY_FOR_PICKUP, COURIER_ASSIGNED, PICKED_UP, ON_THE_WAY,
    DELIVERED, CANCELLED, PAYMENT_FAILED, REFUNDED;

    /** Statuses that count against delivery-slot capacity and keep stock reserved. */
    public boolean active() {
        return this != CANCELLED && this != PAYMENT_FAILED && this != REFUNDED;
    }
}
