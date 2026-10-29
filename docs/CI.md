# CI

Workflow: [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) — четыре джоба: `Backend` (тесты на PostgreSQL + `bootJar`),
`Mobile` (format, analyze, test, web build), `Docker` (compose config + образ бэкенда), `No committed secrets`.
Запуск: push в `main`, `pull_request` (только из этого же репозитория — форки на раннер не пускаются), вручную — нет.

## Self-hosted runner

GitHub-hosted раннеры требуют Actions-минуты/биллинг (если их нет — джобы падают за секунды с `runner_id = 0`, без шагов).
Self-hosted раннер на своей машине их не расходует. Раннер выбирается переменной репозитория `CI_RUNS_ON`
(не задана = `ubuntu-latest`), менять код не нужно. Скрипт и схема перенесены из проверенной настройки
`ADatkashov/zairo` (ветка `develop`).

1. Linux x64 с Docker (пользователь в группе `docker`). GitHub → репозиторий *Settings → Actions → Runners → New
   self-hosted runner* → скопировать registration token (действует 1 час).
2. `scripts/setup-self-hosted-runner.sh <token>` — скачивает раннер, регистрирует (метки `self-hosted,linux,x64`) и
   ставит сервисом (`systemd`). Запускать **не от root**, нужен `sudo`.
3. *Settings → Secrets and variables → Actions → Variables*: `CI_RUNS_ON` = `["self-hosted","linux"]`.
4. *Actions → Runner smoke test → Run workflow* — проверка, что раннер берёт джобы. Затем перезапустить CI.
   Вернуться на GitHub-hosted: удалить переменную `CI_RUNS_ON`.

**Windows:** запускайте раннер внутри WSL2 (Ubuntu), не нативно: `wsl --install -d Ubuntu`; в Docker Desktop включить
WSL integration для Ubuntu; опционально включить `systemd=true` в `/etc/wsl.conf` (иначе скрипт попросит запускать
`~/actions-runner-feya/run.sh` вручную и держать терминал открытым). Компьютер должен быть включён на время CI.

### Особенности

- Раннер ставится в `~/actions-runner-feya` (переменная `RUNNER_DIR`), поэтому не конфликтует с раннером другого
  репозитория на той же машине (например, `~/actions-runner` для `zairo`). Раннер привязан к одному репозиторию;
  два раннера на одной машине работают как два отдельных сервиса.
- Раннер постоянный: Gradle, pub и Flutter SDK остаются на диске, поэтому CI быстрее. При заданном `CI_RUNS_ON`
  облачные кэши (`setup-java`, `flutter-action`) отключены — они считаются в квоте Actions storage.
- PostgreSQL для тестов поднимается service-контейнером на **случайном** порту хоста, поэтому локальный PostgreSQL
  на 5432 не мешает.
- Артефакты отчёта о тестах хранятся 3 дня.
- Джобы пропускаются для PR из форков (`head.repo.full_name != github.repository`): код чужих форков не должен
  выполняться на вашей машине. Не добавляйте триггеры `pull_request_target` и не включайте раннер для публичных форков.
- Если машина выключена, джоб ждёт в очереди.
