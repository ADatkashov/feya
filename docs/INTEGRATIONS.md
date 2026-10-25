# Интеграции и внешние сервисы

Ничего из перечисленного не требует правки модуля заказов: все интеграции — за интерфейсами.

## Платёжный шлюз

Интерфейс: `app.feya.payments.PaymentProvider`.

```java
String id();                       // "kaspi", "halyk", ...
boolean sandbox();
Session createSession(Payment p, String description);   // providerPaymentId + checkoutUrl (hosted page)
boolean verifySignature(String rawBody, String header); // сравнение за постоянное время
ProviderEvent parseEvent(String rawBody);               // PAYMENT_SUCCEEDED/FAILED, REFUND_SUCCEEDED/FAILED
RefundOutcome refund(Payment p, BigDecimal amount, String reason);
```

Чтобы подключить провайдера (Kaspi Pay, Halyk epay, CloudPayments KZ и т. п.):

1. Реализуйте интерфейс и зарегистрируйте как Spring-бин (по образцу `SandboxPaymentProvider` / `PaymentConfig`).
   Используйте **hosted checkout** или нативный SDK — номера карт не должны попадать на серверы FEYA.
2. Задайте `FEYA_PAYMENTS_PROVIDER=<id>` и `FEYA_PAYMENTS_WEBHOOK_SECRET` (или перенесите проверку подписи под схему
   провайдера — в `verifySignature`). Без секрета production не стартует (`ProductionGuard`).
3. Настройте у провайдера URL `https://<api>/api/v1/payments/webhook/<id>`.
4. Приложение уже открывает `checkoutUrl` во внешнем браузере и опрашивает `GET /payments/{id}` до финального статуса.
5. Прогоните тесты `PaymentIT` против своей реализации и сквозной сценарий в песочнице провайдера.

**Не проверено без реквизитов:** обмен с реальным шлюзом, форматы подписи конкретных провайдеров, возвраты через
API провайдера. Сейчас в репозитории только `sandbox` (деньги не двигает, в production запрещён).

## SMS (вход по OTP)

Интерфейс `app.feya.identity.SmsSender`. По умолчанию `LoggingSmsSender` код **не доставляет** и не пишет его в лог.
Для продакшена добавьте бин `SmsSender` под выбранный шлюз (например SMSC.kz, Mobizon, Twilio Verify).
`FEYA_DEV_OTP_ENABLED=true` возвращает код в ответе API — только для разработки (в production запрещено).

## Push-уведомления

Интерфейс `app.feya.notifications.PushSender`; по умолчанию логирует «push не настроен», in-app inbox работает всегда.
Клиент регистрирует токен устройства `POST /me/devices`. Для FCM нужно:
1. Добавить Firebase в Flutter (`firebase_core`, `firebase_messaging`, `google-services.json` /
   `GoogleService-Info.plist` — **не коммитить**), запросить разрешение и отправить токен на `/me/devices`.
2. Реализовать `PushSender` через FCM HTTP v1 (сервисный аккаунт из секрета окружения).

Не реализовано в репозитории: клиентская часть Firebase и серверная отправка через FCM.

## Карты и геокодирование

Сейчас адрес вводится вручную (город, улица, дом …); бэкенд принимает необязательные `latitude/longitude` и по ним
выбирает зону доставки точнее. «Живая» позиция курьера отдаётся клиенту как координаты; в приложении есть кнопка
«Открыть на карте» по шаблону `MAP_LINK_TEMPLATE` (по умолчанию 2GIS). Встроенный тайловый виджет карты и выбор точки
на карте **не включены** — для Казахстана рекомендуются 2GIS MapGL/Yandex/OSM-тайлы по лицензии продакшена; добавляется
в `address_form_screen.dart` и `tracking_screen.dart` без изменения API.

## Хранилище изображений

Статика каталога лежит в `backend/src/main/resources/media` (иллюстрации разработки), загрузки персонала — в каталоге
`FEYA_MEDIA_UPLOAD_DIR` (volume). Для продакшена вынесите в объектное хранилище/CDN и задайте `FEYA_MEDIA_BASE_URL`.
