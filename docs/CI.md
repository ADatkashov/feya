# CI

Репозиторий публичный, поэтому используются бесплатные GitHub-hosted раннеры (`ubuntu-latest`). Self-hosted раннер,
переменная `CI_RUNS_ON`, `runner-smoke.yml` и `scripts/setup-self-hosted-runner.sh` удалены: на публичном репозитории
такой раннер позволил бы чужим PR выполнять код на вашей машине. Не возвращайте его. PR из форков получают read-only токен без секретов.

Workflow: [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) — четыре джоба: `Backend` (тесты на PostgreSQL + `bootJar`),
`Mobile` (format, analyze, test, web build), `Docker` (compose config + образ бэкенда), `No committed secrets`.
Запуск: push в `main`, любой `pull_request`, вручную (`workflow_dispatch`). Новый push отменяет устаревший прогон (`concurrency`).

## Android APK (CD)

Workflow [`android-apk.yml`](../.github/workflows/android-apk.yml) запускается **автоматически при push в `main`**, если
менялось `mobile/**`, и вручную (*Actions → Android APK → Run workflow*, адрес бэкенда можно изменить в поле).
Результат: *Releases → Android APK #N* — постоянная ссылка на `.apk` (открыть на телефоне, нажать на файл, разрешить установку
из неизвестных источников) и тот же файл как артефакт `feya-apk` (14 дней).

Без параметров APK смотрит на демо-бэкенд `https://feya-backend-sea8.onrender.com` (первый запрос после простоя может идти 2–3 минуты —
бесплатный тариф Render засыпает).

### Подпись

- **Без секретов** — APK подписан debug-ключом (`feya-debug-signed-N.apk`): годится для установки вручную, не для Google Play.
- **С секретами** — release-ключом (`feya-release-signed-N.apk`). Один раз создайте ключ и добавьте в
  *Settings → Secrets and variables → Actions → Secrets*:
  `ANDROID_KEYSTORE_BASE64` (`base64 -w0 release.jks`), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
  Ключ: `keytool -genkeypair -v -keystore release.jks -alias feya -keyalg RSA -keysize 2048 -validity 10000`.
  **Сохраните `release.jks` и пароли в надёжном месте** — потеряв ключ, обновить приложение у пользователей будет нельзя.
  Никогда не коммитьте `.jks` и `key.properties` (они в `.gitignore`; CI ловит это джобом `No committed secrets`).
- Телефон с APK, подписанным другим ключом, должен сначала удалить приложение.

Локально то же самое: `cd mobile && flutter build apk --release --dart-define=API_BASE_URL=https://feya-backend-sea8.onrender.com`
(для release-подписи положите `mobile/android/key.properties` с `storeFile`, `storePassword`, `keyAlias`, `keyPassword`).
