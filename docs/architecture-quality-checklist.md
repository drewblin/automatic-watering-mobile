# Чек-ліст якості архітектури

Цей чек-ліст містить лише рекомендації, які практично покращують надійність, супровід або майбутню розробку функцій. Пункти звірені з поточним кодом і залишені тільки там, де користь конкретна.

## Залишити

- [ ] Зробити `AppState` і колекції state models defensively immutable.
  - Причина: `AppState` є immutable за домовленістю, але приймає `List<DeviceObject>` напряму. Майбутні callers можуть змінити списки після публікації state і обійти `AppStateStore.notifyListeners`.
  - Практичний ефект: запобігає складній для діагностики десинхронізації UI/state, зберігаючи поточну `ChangeNotifier` архітектуру.
  - Докази в коді: `lib/app/app_state.dart`, `lib/app/app_state_store.dart`.

- [ ] Додати corruption-tolerant parsing для збережених hub і plan data.
  - Причина: `SharedPreferencesWateringHubStorage` напряму кастить decoded JSON. Застаріла schema, перерваний запис або ручне пошкодження даних можуть кинути exception під час startup до того, як застосунок запропонує recovery.
  - Практичний ефект: користувачі зможуть відновитися через повторний onboarding або очищення профілю замість fatal startup screen через проблеми local storage.
  - Докази в коді: `lib/storage/local_watering_hub_storage.dart`, `lib/app/app_startup_service.dart`.

- [ ] Під час додавання або зміни BLE characteristic методів у `FlutterReactiveBleService` спершу винести спільні read/write envelope helper-и.
  - Причина: `FlutterReactiveBleService` є природним platform adapter, тому його не варто розбивати лише через розмір. Реальне дублювання видно в `readWifiSettings`, `readWifiIpAddress`, `readApiAccessToken` і `saveWifiSettings`, де повторюється вибір characteristic, читання, decode envelope і обробка `success: false`.
  - Практичний ефект: майбутні BLE характеристики, live logs або diagnostics notifications додаватимуться через один helper-шлях, а service не перетвориться на набір майже однакових методів.
  - Докази в коді: `lib/features/ble/flutter_reactive_ble_service.dart`.
