package app.feya.notifications;

import app.feya.common.Lang;
import app.feya.identity.DeviceToken;
import app.feya.identity.DeviceTokenRepository;
import app.feya.identity.User;
import app.feya.identity.UserRepository;
import app.feya.orders.OrderStatus;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Service
public class NotificationService {
    private record Text(String ru, String kk, String en) {
        String of(Lang l) {
            return switch (l) {
                case RU -> ru;
                case KK -> kk;
                case EN -> en;
            };
        }
    }

    private static final Map<OrderStatus, Text[]> ORDER_TEXTS = Map.of(
            OrderStatus.PAID, new Text[] {
                    new Text("Оплата прошла", "Төлем сәтті өтті", "Payment received"),
                    new Text("Заказ %s оплачен. Ждём подтверждения флориста.", "%s тапсырысы төленді. Флористтің растауын күтеміз.", "Order %s is paid. Waiting for the florist to confirm.")},
            OrderStatus.PAYMENT_FAILED, new Text[] {
                    new Text("Оплата не прошла", "Төлем өтпеді", "Payment failed"),
                    new Text("Не удалось оплатить заказ %s. Попробуйте ещё раз.", "%s тапсырысын төлеу мүмкін болмады. Қайта көріңіз.", "We could not process payment for order %s. Please try again.")},
            OrderStatus.CONFIRMED, new Text[] {
                    new Text("Заказ подтверждён", "Тапсырыс расталды", "Order confirmed"),
                    new Text("Заказ %s принят флористом.", "%s тапсырысын флорист қабылдады.", "Order %s was accepted by the florist.")},
            OrderStatus.PREPARING, new Text[] {
                    new Text("Собираем букет", "Букет жиналуда", "Preparing your bouquet"),
                    new Text("Флорист собирает заказ %s.", "Флорист %s тапсырысын жинап жатыр.", "The florist is preparing order %s.")},
            OrderStatus.COURIER_ASSIGNED, new Text[] {
                    new Text("Курьер назначен", "Курьер тағайындалды", "Courier assigned"),
                    new Text("Для заказа %s назначен курьер.", "%s тапсырысына курьер тағайындалды.", "A courier was assigned to order %s.")},
            OrderStatus.ON_THE_WAY, new Text[] {
                    new Text("Курьер в пути", "Курьер жолда", "Courier is on the way"),
                    new Text("Заказ %s уже едет к получателю.", "%s тапсырысы алушыға жолда.", "Order %s is on its way to the recipient.")},
            OrderStatus.DELIVERED, new Text[] {
                    new Text("Заказ доставлен", "Тапсырыс жеткізілді", "Order delivered"),
                    new Text("Заказ %s доставлен. Спасибо, что выбрали FEYA!", "%s тапсырысы жеткізілді. FEYA таңдағаныңызға рахмет!", "Order %s was delivered. Thank you for choosing FEYA!")},
            OrderStatus.CANCELLED, new Text[] {
                    new Text("Заказ отменён", "Тапсырыс бас тартылды", "Order cancelled"),
                    new Text("Заказ %s отменён.", "%s тапсырысынан бас тартылды.", "Order %s was cancelled.")},
            OrderStatus.REFUNDED, new Text[] {
                    new Text("Возврат средств", "Қаражат қайтарылды", "Refund issued"),
                    new Text("По заказу %s оформлен возврат.", "%s тапсырысы бойынша қайтару рәсімделді.", "A refund was issued for order %s.")});

    private final NotificationRepository notifications;
    private final UserRepository users;
    private final DeviceTokenRepository devices;
    private final PushSender push;

    public NotificationService(NotificationRepository notifications, UserRepository users,
                               DeviceTokenRepository devices, PushSender push) {
        this.notifications = notifications;
        this.users = users;
        this.devices = devices;
        this.push = push;
    }

    public boolean hasOrderText(OrderStatus status) {
        return ORDER_TEXTS.containsKey(status);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void notifyOrderStatus(UUID userId, UUID orderId, String orderNumber, OrderStatus status) {
        Text[] t = ORDER_TEXTS.get(status);
        User user = users.findById(userId).orElse(null);
        if (t == null || user == null || !user.isNotifyOrderUpdates()) {
            return;
        }
        Lang lang = user.lang();
        Notification n = new Notification();
        n.setUserId(userId);
        n.setType("ORDER_" + status.name());
        n.setTitle(t[0].of(lang));
        n.setBody(String.format(t[1].of(lang), orderNumber));
        n.setData("order:" + orderId);
        notifications.save(n);
        if (user.isNotifyPush()) {
            List<String> tokens = devices.findByUserId(userId).stream().map(DeviceToken::getToken).toList();
            if (!tokens.isEmpty()) {
                try {
                    push.send(tokens, n.getTitle(), n.getBody(), n.getData());
                } catch (RuntimeException e) {
                    // A push outage must never break order processing; the in-app inbox already has the message.
                }
            }
        }
    }
}
