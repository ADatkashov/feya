package app.feya.tracking;

import app.feya.notifications.NotificationService;
import app.feya.orders.OrderEntity;
import app.feya.orders.OrderRepository;
import app.feya.orders.OrderStatusChanged;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/** After commit: write the in-app notification (+push) and push a tracking update to open streams. */
@Component
public class OrderEventsListener {
    private final NotificationService notifications;
    private final OrderRepository orders;
    private final TrackingService tracking;
    private final SseHub hub;

    public OrderEventsListener(NotificationService notifications, OrderRepository orders, TrackingService tracking,
                               SseHub hub) {
        this.notifications = notifications;
        this.orders = orders;
        this.tracking = tracking;
        this.hub = hub;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Transactional(propagation = org.springframework.transaction.annotation.Propagation.REQUIRES_NEW, readOnly = true)
    public void onStatusChanged(OrderStatusChanged e) {
        OrderEntity o = orders.findById(e.orderId()).orElse(null);
        if (o == null) {
            return;
        }
        if (notifications.hasOrderText(e.to())) {
            notifications.notifyOrderStatus(e.userId(), o.getId(), o.getNumber(), e.to());
        }
        if (hub.subscribers(o.getId()) > 0) {
            hub.publish(o.getId(), tracking.build(o));
        }
    }
}
