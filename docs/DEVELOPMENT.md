# Разработка

## Требования

JDK 21, PostgreSQL 16 (локально или Docker), Flutter 3.47+ (Dart 3.13), Node.js (только для UI-проверок в браузере),
Python 3 + Pillow (только для регенерации иллюстраций/сида/строк).

## Бэкенд

```bash
# База (если нет своего PostgreSQL)
docker run -d --name feya-pg -e POSTGRES_USER=feya -e POSTGRES_PASSWORD=feya -e POSTGRES_DB=feya -p 5432:5432 postgres:16-alpine

cd backend
SPRING_PROFILES_ACTIVE=dev ./gradlew bootRun     # http://localhost:8080, Swagger: /swagger-ui.html, консоль: /admin/
```

Профиль `dev` применяет миграции **и** сид-каталог (`db/seed-dev/R__dev_seed.sql`), включает dev-OTP (код приходит в
ответе `POST /auth/otp/request` поле `devCode`) и sandbox-платежи. Без профиля `dev` бэкенд стартует как production:
потребует `FEYA_JWT_SECRET` и не включит ни одного dev-переключателя.

Демо-аккаунты (только dev-сид): админ `+77000000001`, флорист Достык `+77000000002`, курьер `+77000000003`,
поддержка `+77000000004`, флорист Самал `+77000000005`, клиент `+77010000000`. Любой новый номер = новый клиент.

### Тесты бэкенда

Интеграционные тесты идут на **настоящем PostgreSQL** (тот же Flyway, сид, транзакционный откат на тест):

```bash
createdb feya_test   # или: su postgres -c "createdb -O feya feya_test"
FEYA_TEST_DB_URL=jdbc:postgresql://localhost:5432/feya_test FEYA_TEST_DB_USER=feya FEYA_TEST_DB_PASSWORD=feya \
  ./gradlew test
```

Значения по умолчанию совпадают с примером выше. В CI используется service-контейнер PostgreSQL. Testcontainers не
подключён сознательно: так тесты одинаково идут локально, в CI и в окружениях без Docker-демона.
`ConcurrencyIT` и `MigrationIT` не транзакционны (реальные гонки / DDL) и сами убирают за собой.

### Данные для разработки

- `tools/generate_seed.py` → `backend/src/main/resources/db/seed-dev/R__dev_seed.sql` (идемпотентно; повторяемая
  миграция Flyway). Это **вымышленные** товары, цены и остатки. Отзывов, рейтингов и статистики продаж в сиде нет.
- `tools/generate_media.py` рисует оригинальные иллюстрации букетов (`backend/src/main/resources/media`). Это
  заглушки для разработки: перед запуском замените их реальными фотографиями, на которые у вас есть права.
- Сброс dev-базы: `dropdb feya && createdb feya` и перезапуск (миграции и сид применятся заново).

## Мобильное приложение

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080      # Android-эмулятор (по умолчанию для Android)
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
flutter analyze && flutter test
flutter build web --release --no-web-resources-cdn --dart-define=API_BASE_URL=...
```

`--dart-define`: `API_BASE_URL`, `MAP_LINK_TEMPLATE`, `SUPPORT_PHONE`, `SUPPORT_WHATSAPP`, `PRIVACY_URL`, `TERMS_URL`.
Для Android (HTTP на localhost) в debug-сборке эмулятор ходит на `10.0.2.2`; в релизе используйте только HTTPS.

### Локализация

Строки — в `tools/i18n_strings.py` (`ru` — шаблон, `kk`, `en`). После правки:
`python3 tools/i18n_strings.py && (cd mobile && flutter gen-l10n)`. Плюральные формы — ICU (`itemsCount`, `stems`).

### Проверка в браузере

Flutter web рендерит в canvas; для автотестов включайте семантику (`flt-semantics-placeholder`) и ищите элементы
по ролям/подписям (это же проверяет доступность). Для скриншотов в окружениях без доступа к `gstatic.com` собирайте с
`--no-web-resources-cdn`.

## Проверки перед коммитом

```bash
(cd backend && ./gradlew test)
(cd mobile && dart format --set-exit-if-changed lib test && flutter analyze && flutter test)
```
