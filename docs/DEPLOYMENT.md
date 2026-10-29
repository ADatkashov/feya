# Развёртывание

## Что нужно

1. PostgreSQL 16 с регулярными бэкапами (PITR или ежедневные дампы + проверка восстановления).
2. Контейнер/JVM для бэкенда (`backend/Dockerfile`, Java 21), за обратным прокси с TLS (nginx/Caddy/ingress).
3. Постоянное хранилище для загрузок (volume или объектное хранилище + CDN) — см. `FEYA_MEDIA_*`.
4. Платёжный провайдер, SMS-шлюз, (опц.) FCM — см. [INTEGRATIONS.md](INTEGRATIONS.md).

## Переменные окружения (production)

| Переменная | Обязательна | Назначение |
|---|---|---|
| `FEYA_ENV` | нет (по умолчанию `production`) | Включает `ProductionGuard` |
| `FEYA_DB_URL` / `FEYA_DB_USER` / `FEYA_DB_PASSWORD` | да | PostgreSQL |
| `FEYA_JWT_SECRET` | да | ≥ 32 символов, случайный, **не** `dev-only…` |
| `FEYA_PAYMENTS_PROVIDER` | да | id реального провайдера (`sandbox` в production запрещён) |
| `FEYA_PAYMENTS_WEBHOOK_SECRET` | да при провайдере | Секрет подписи webhook |
| `FEYA_CORS_ALLOWED_ORIGINS` | если есть web-клиенты | Точные origin'ы, через запятую |
| `FEYA_MEDIA_BASE_URL`, `FEYA_MEDIA_UPLOAD_DIR` | нет | CDN-префикс и каталог загрузок |
| `FEYA_RATE_LIMIT_ENABLED` | нет | По умолчанию `true` |
| `FEYA_DEV_OTP_ENABLED` | **должна быть false** | Запрещена в production |
| `PORT` | нет | По умолчанию 8080 |

Бэкенд **не стартует**, если в production включён dev-OTP, sandbox-платежи, dev-секрет JWT или не задан секрет webhook.
Секреты передавайте через менеджер секретов платформы, не через репозиторий и не через образы.

## Чек-лист запуска

- [ ] CI зелёный на `main` (self-hosted раннер настроен по [CI.md](CI.md)): бэкенд-тесты, `flutter analyze/test`, сборка web и Docker-образа.
- [ ] Профиль `dev` и сид **не** используются; `GET /api/v1/home` пуст, пока персонал не заведёт каталог.
- [ ] Через консоль `/admin/` созданы: категории, точки (флористы) с зонами, зоны и слоты, товары, остатки, курьеры.
      Первого администратора создайте SQL-вставкой в `users`/`user_roles` (роль `ADMIN`) — в production сид-аккаунтов нет.
- [ ] Реализован и проверен `SmsSender` (иначе войти нельзя), реализован `PaymentProvider`, проверен webhook.
- [ ] TLS на прокси; проброс `X-Forwarded-For/Proto` (приложение использует `forward-headers-strategy: framework`);
      rate limit хранится в памяти процесса — при нескольких репликах добавьте лимиты на уровне прокси/шлюза.
- [ ] Закрыт доступ к `/actuator` (отдаются только `health`, `info`); `FEYA_SWAGGER_ENABLED=false`
      (по умолчанию), при желании отключите и `/v3/api-docs` (`springdoc.api-docs.enabled=false`).
- [ ] CSP/заголовки для `/admin/` на уровне прокси; консоль доступна только персоналу (проверки — на сервере).
- [ ] Мониторинг: `/actuator/health/liveness|readiness`, алерты на 5xx, рост `PAYMENT_FAILED`, зависшие `PENDING_PAYMENT`.
- [ ] Юридические тексты (политика, условия) заменены на проверенные и прописаны `PRIVACY_URL`/`TERMS_URL`.
- [ ] Реальные фотографии каталога вместо иллюстраций разработки.
- [ ] Процесс удаления данных по запросам `DELETION_REQUESTED` (приложение только помечает аккаунт и отзывает сессии).

## Миграции

Flyway применяет `db/migration` при старте. Не редактируйте уже применённые `V*`: добавляйте новые. `R__dev_seed.sql`
существует только в `db/seed-dev` и подключается профилем `dev`.

## Мобильные релизы

- **Android:** создайте keystore (`key.properties` — вне репозитория, уже в `.gitignore`), настройте
  `mobile/android/app/build.gradle*` на подпись и `applicationId` (`kz.feya.feya` — временный), затем
  `flutter build appbundle --release --dart-define=API_BASE_URL=https://api...`.
- **iOS:** Apple Developer, bundle id, сертификаты, `flutter build ipa`; для push — APNs-ключ в Firebase.
- Для production обязателен HTTPS `API_BASE_URL`. Иконки, сплэш, названия магазинов и скриншоты — на вашей стороне.
- Не проверено в этом окружении: сборки Android/iOS (нет Android SDK/Xcode); проверены `flutter analyze`,
  `flutter test` и `flutter build web`.

## Откат

Образ бэкенда неизменяем: откат = выкатка предыдущего тега. Миграции только вперёд — для отката схемы заранее
готовьте компенсирующую миграцию; перед миграциями делайте снимок БД.
