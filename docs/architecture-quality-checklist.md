# Чек-ліст якості архітектури

Цей чек-ліст містить лише рекомендації, які практично покращують надійність, супровід або майбутню розробку функцій. Пункти звірені з поточним кодом і залишені тільки там, де користь конкретна.

## Залишити

- [ ] Під час додавання або зміни BLE characteristic методів у `FlutterReactiveBleService` спершу винести спільні read/write envelope helper-и.
  - Причина: `FlutterReactiveBleService` є природним platform adapter, тому його не варто розбивати лише через розмір. Реальне дублювання видно в `readWifiSettings`, `readWifiIpAddress`, `readApiAccessToken` і `saveWifiSettings`, де повторюється вибір characteristic, читання, decode envelope і обробка `success: false`.
  - Практичний ефект: майбутні BLE характеристики, live logs або diagnostics notifications додаватимуться через один helper-шлях, а service не перетвориться на набір майже однакових методів.
  - Докази в коді: `lib/features/ble/flutter_reactive_ble_service.dart`.
