# FEYA mobile

Клиентское приложение (Flutter). Полное описание проекта — в [корневом README](../README.md), архитектура —
в [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md).

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080   # эмулятор Android → бэкенд на хосте
flutter analyze && flutter test
```

Конфигурация только через `--dart-define` (`API_BASE_URL`, `MAP_LINK_TEMPLATE`, `SUPPORT_PHONE`, `SUPPORT_WHATSAPP`,
`PRIVACY_URL`, `TERMS_URL`). Секретов в приложении нет. Строки интерфейса: `../tools/i18n_strings.py` → `lib/l10n/*.arb`.
Шрифт Inter (SIL OFL 1.1) лежит в `assets/fonts/` вместе с лицензией.
