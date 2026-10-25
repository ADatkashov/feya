package app.feya.payments;

import app.feya.orders.OrderEntity;
import app.feya.orders.OrderRepository;
import app.feya.orders.OrderStatus;
import app.feya.orders.OrderStatusChanged;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

/** When a paid order is cancelled, the money goes back automatically (in the same transaction as the cancellation). */
@Component
public class RefundOnCancelListener {
    private final PaymentService payments;
    private final OrderRepository orders;

    public RefundOnCancelListener(PaymentService payments, OrderRepository orders) {
        this.payments = payments;
        this.orders = orders;
    }

    @EventListener
    public void onStatusChanged(OrderStatusChanged e) {
        if (e.to() == OrderStatus.CANCELLED) {
            OrderEntity o = orders.findById(e.orderId()).orElse(null);
            if (o != null && o.getPaymentStatus() == OrderEntity.PaymentState.PAID) {
                payments.refundOrder(e.orderId(), "order cancelled", e.actor() == null ? null : e.userId());
            }
        }
    }
}
