# REST API

Базовый путь: `/api/v1`. Машиночитаемая спецификация — [`openapi.json`](openapi.json) (генерируется работающим
бэкендом: `tools/export_openapi.sh`; в dev-профиле также доступен Swagger UI на `/swagger-ui.html`).

## Соглашения

- **Аутентификация.** `Authorization: Bearer <accessToken>`. Access-токен живёт 15 минут, refresh-токен — 30 дней и
  **ротируется** при каждом обновлении; повторное использование старого refresh-токена отзывает всю «семью» токенов.
- **Язык.** `Accept-Language: ru|kk|en` (или `?lang=`). Нет перевода → русский.
- **Деньги.** `BigDecimal`, валюта `KZT`, два знака. Цены, скидки, доставка и итог **всегда считает сервер**;
  клиент присылает только `variantId` и `quantity`.
- **Время.** Моменты времени — ISO-8601 UTC (`Z`). Даты и интервалы доставки — локальное время `Asia/Almaty`
  (`deliveryDate`, `slotStart`, `slotEnd`).
- **Ошибки.** `{ "code": "SLOT_FULL", "message": "...", "fieldErrors": {"field": "..."}, "timestamp": "..." }`.
  Коды стабильны, сообщения — для логов, не для показа пользователю. Статусы: 400 (валидация), 401, 403, 404, 409
  (конфликт состояния/остатков), 422 (бизнес-правило: слот, зона, промокод), 429, 503 (платежи не настроены).
- **Пагинация.** `?page=0&size=20` → `{content, page, size, totalElements, totalPages, hasNext}`.
- **Идемпотентность.** `POST /orders` принимает заголовок `Idempotency-Key`: повтор с тем же ключом вернёт тот же
  заказ (200 вместо 201), остаток и слот не резервируются повторно.
- **Лимиты.** OTP, refresh, создание заказа, webhook и `cart/quote` защищены rate limit по IP (429 + `Retry-After`).

## Основной сценарий

1. `GET /home`, `GET /products?...`, `GET /products/{idOrSlug}` — публично.
2. `POST /cart/quote` — публичный авторитетный расчёт корзины (корзина хранится на устройстве).
3. `POST /auth/otp/request` → `POST /auth/otp/verify` — вход по телефону.
4. `GET /delivery/zones/resolve`, `GET /delivery/slots` — зона и **реальные** доступные слоты.
5. `POST /orders` (адрес, получатель, слот или `asap`, подарок, `acceptTerms`) → заказ `PENDING_PAYMENT`.
6. `POST /orders/{id}/payments` → `GET /payments/{id}`; статус «оплачено» меняется **только** подписанным webhook.
7. `GET /orders/{id}`, `GET /orders/{id}/tracking` (+ `/tracking/stream`, SSE) — статус и курьер.

## Платёжные webhook

`POST /payments/webhook/{provider}` — публичный, без JWT. Тело читается как **сырая строка**, подпись
`X-Webhook-Signature` (HMAC-SHA256 от тела, секрет — `FEYA_PAYMENTS_WEBHOOK_SECRET`) проверяется до парсинга.
События дедуплицируются по `(provider, eventId)`; сумма и валюта сверяются с платежом; запоздалое «успешно» по уже
отменённому заказу автоматически возвращается клиенту. Подробности — [INTEGRATIONS.md](INTEGRATIONS.md).

## Роли

| Роль | Доступ |
|---|---|
| `CUSTOMER` | Свой профиль, адреса, корзина-котировки, свои заказы/платежи/уведомления/избранное/отзывы. |
| `FLORIST` | `/florist/**` только по своей точке: очередь заказов, остатки, товары. |
| `COURIER` | `/courier/**`: смена, заказы «готов к выдаче», статусы доставки, геопозиция. |
| `SUPPORT` | `/admin/**` на чтение + отмена/смена статусов по правилам автомата, назначение курьеров. |
| `ADMIN` | Всё: справочники, зоны/слоты, акции, возвраты, роли, аудит. |

Каждый ресурс клиента запрашивается только с `userId` из токена: чужой заказ/адрес/платёж → `404`.

## Все эндпоинты

### Аутентификация

| Метод | Путь |
|---|---|
| `POST` | `/api/v1/auth/logout` |
| `POST` | `/api/v1/auth/otp/request` |
| `POST` | `/api/v1/auth/otp/verify` |
| `POST` | `/api/v1/auth/refresh` |

### Профиль

| Метод | Путь |
|---|---|
| `GET` | `/api/v1/me` |
| `PATCH` | `/api/v1/me` |
| `POST` | `/api/v1/me/deletion-request` |
| `POST` | `/api/v1/me/devices` |
| `DELETE` | `/api/v1/me/devices` |

### Каталог и отзывы

| Метод | Путь |
|---|---|
| `GET` | `/api/v1/categories` |
| `GET` | `/api/v1/home` |
| `GET` | `/api/v1/products` |
| `GET` | `/api/v1/products/{idOrSlug}` |
| `GET` | `/api/v1/products/{idOrSlug}/related` |
| `GET` | `/api/v1/products/{productId}/reviews` |
| `POST` | `/api/v1/products/{productId}/reviews` |

### Избранное

| Метод | Путь |
|---|---|
| `GET` | `/api/v1/favorites` |
| `PUT` | `/api/v1/favorites/{productId}` |
| `DELETE` | `/api/v1/favorites/{productId}` |

### Корзина

| Метод | Путь |
|---|---|
| `POST` | `/api/v1/cart/quote` |

### Адреса

| Метод | Путь |
|---|---|
| `GET` | `/api/v1/addresses` |
| `POST` | `/api/v1/addresses` |
| `PUT` | `/api/v1/addresses/{id}` |
| `DELETE` | `/api/v1/addresses/{id}` |
| `PUT` | `/api/v1/addresses/{id}/default` |

### Доставка

| Метод | Путь |
|---|---|
| `GET` | `/api/v1/delivery/slots` |
| `GET` | `/api/v1/delivery/zones` |
| `GET` | `/api/v1/delivery/zones/resolve` |

### Заказы и трекинг

| Метод | Путь |
|---|---|
| `GET` | `/api/v1/orders` |
| `POST` | `/api/v1/orders` |
| `GET` | `/api/v1/orders/{id}` |
| `POST` | `/api/v1/orders/{id}/cancel` |
| `POST` | `/api/v1/orders/{orderId}/payments` |
| `GET` | `/api/v1/orders/{orderId}/tracking` |
| `GET` | `/api/v1/orders/{orderId}/tracking/stream` |

### Платежи

| Метод | Путь |
|---|---|
| `GET` | `/api/v1/payments/methods` |
| `POST` | `/api/v1/payments/sandbox/{paymentId}/complete` |
| `POST` | `/api/v1/payments/webhook/{provider}` |
| `GET` | `/api/v1/payments/{id}` |

### Уведомления

| Метод | Путь |
|---|---|
| `GET` | `/api/v1/notifications` |
| `POST` | `/api/v1/notifications/read-all` |
| `GET` | `/api/v1/notifications/unread-count` |
| `POST` | `/api/v1/notifications/{id}/read` |

### Флорист (FLORIST/ADMIN)

| Метод | Путь |
|---|---|
| `GET` | `/api/v1/florist/inventory` |
| `PUT` | `/api/v1/florist/inventory/{variantId}` |
| `GET` | `/api/v1/florist/orders` |
| `POST` | `/api/v1/florist/orders/{id}/accept` |
| `POST` | `/api/v1/florist/orders/{id}/preparing` |
| `POST` | `/api/v1/florist/orders/{id}/ready` |
| `POST` | `/api/v1/florist/orders/{id}/reject` |
| `GET` | `/api/v1/florist/products` |
| `POST` | `/api/v1/florist/products` |
| `GET` | `/api/v1/florist/products/{id}` |
| `PUT` | `/api/v1/florist/products/{id}` |
| `POST` | `/api/v1/florist/products/{id}/images` |
| `POST` | `/api/v1/florist/products/{id}/images/upload` |
| `DELETE` | `/api/v1/florist/products/{id}/images/{imageId}` |

### Курьер (COURIER)

| Метод | Путь |
|---|---|
| `POST` | `/api/v1/courier/location` |
| `GET` | `/api/v1/courier/me` |
| `GET` | `/api/v1/courier/orders` |
| `POST` | `/api/v1/courier/orders/{id}/claim` |
| `POST` | `/api/v1/courier/orders/{id}/status` |
| `PUT` | `/api/v1/courier/shift` |

### Администрирование (ADMIN/SUPPORT)

| Метод | Путь |
|---|---|
| `GET` | `/api/v1/admin/audit` |
| `GET` | `/api/v1/admin/banners` |
| `POST` | `/api/v1/admin/banners` |
| `PUT` | `/api/v1/admin/banners/{id}` |
| `GET` | `/api/v1/admin/categories` |
| `POST` | `/api/v1/admin/categories` |
| `PUT` | `/api/v1/admin/categories/{id}` |
| `GET` | `/api/v1/admin/couriers` |
| `POST` | `/api/v1/admin/couriers` |
| `PATCH` | `/api/v1/admin/couriers/{userId}` |
| `GET` | `/api/v1/admin/customers` |
| `PUT` | `/api/v1/admin/customers/{id}/roles` |
| `PATCH` | `/api/v1/admin/customers/{id}/status` |
| `GET` | `/api/v1/admin/dashboard` |
| `GET` | `/api/v1/admin/florists` |
| `POST` | `/api/v1/admin/florists` |
| `PUT` | `/api/v1/admin/florists/{id}` |
| `GET` | `/api/v1/admin/orders` |
| `GET` | `/api/v1/admin/orders/{id}` |
| `POST` | `/api/v1/admin/orders/{id}/assign-courier` |
| `POST` | `/api/v1/admin/orders/{id}/refund` |
| `POST` | `/api/v1/admin/orders/{id}/status` |
| `GET` | `/api/v1/admin/products` |
| `POST` | `/api/v1/admin/products` |
| `GET` | `/api/v1/admin/products/{id}` |
| `PUT` | `/api/v1/admin/products/{id}` |
| `POST` | `/api/v1/admin/products/{id}/images` |
| `POST` | `/api/v1/admin/products/{id}/images/upload` |
| `DELETE` | `/api/v1/admin/products/{id}/images/{imageId}` |
| `GET` | `/api/v1/admin/promos` |
| `POST` | `/api/v1/admin/promos` |
| `PUT` | `/api/v1/admin/promos/{id}` |
| `GET` | `/api/v1/admin/reviews` |
| `POST` | `/api/v1/admin/reviews/{id}/hide` |
| `POST` | `/api/v1/admin/reviews/{id}/unhide` |
| `PUT` | `/api/v1/admin/slots/{id}` |
| `GET` | `/api/v1/admin/zones` |
| `POST` | `/api/v1/admin/zones` |
| `PUT` | `/api/v1/admin/zones/{id}` |
| `GET` | `/api/v1/admin/zones/{zoneId}/slots` |
| `POST` | `/api/v1/admin/zones/{zoneId}/slots` |
