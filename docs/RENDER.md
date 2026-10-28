# Деплой демо-стенда на Render

Сервис: Docker (`backend/Dockerfile`, контекст `./backend`), БД: Render Postgres (free).

Переменные окружения веб-сервиса:

| Переменная | Значение |
|---|---|
| `SPRING_PROFILES_ACTIVE` | `dev` (демо: сид-каталог, dev-OTP, sandbox-платежи) |
| `FEYA_ENV` | `dev` |
| `FEYA_DB_HOST` / `FEYA_DB_PORT` / `FEYA_DB_NAME` | internal hostname БД / `5432` / имя БД |
| `FEYA_DB_USER` / `FEYA_DB_PASSWORD` | из Render → БД → Connect |
| `FEYA_JWT_SECRET` | случайная строка ≥ 32 символов |
| `FEYA_PAYMENTS_WEBHOOK_SECRET` | случайная строка |
| `FEYA_CORS_ALLOWED_ORIGIN_PATTERNS` | `*` или origin клиента |

Health check: `/actuator/health/readiness`.

Демо-режим публично открывает dev-OTP и демо-аккаунты (в т.ч. админа). Не вносить реальные данные.
Для продакшена: убрать профиль `dev`, `FEYA_ENV=production`, отключить dev-OTP и sandbox, подключить реального платёжного провайдера и SMS.
Free-Postgres на Render удаляется через 30 дней, free-веб-сервис засыпает при простое.
