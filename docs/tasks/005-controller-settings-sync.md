# Задача 005: Controller settings sync

## Мета

Реалізувати першу реальну синхронізацію конфігурації контролера через локальний HTTPS API: виконати `GET /api/settings`, розпарсити повний settings snapshot, побудувати доменні device objects із реальних settings і тримати актуальний стан конфігурації в пам'яті app state.

Після цієї задачі додаток має розуміти, які клапани, soil sensors, pressure sensor і water counters реально налаштовані на контролері, і може переходити до початкового створення схеми ділянки без mock-об'єктів.

## Контекст із ТЗ

Settings контролера є джерелом технічної конфігурації. Локальна схема ділянки є тільки UI-даними мобільного додатку і не замінює settings.

Settings snapshot не потрібно зберігати в local storage. Після restart додатку settings треба знову читати з контролера через `GET /api/settings`, щоб не створювати ризик розсинхронізації локального cache з реальною конфігурацією контролера.

Базова конфігурація вважається неповною, якщо немає потрібних компонентів для автоматичного поливу, зокрема:

- pressure sensor;
- magistral water counter;
- мінімум одного soil sensor;
- клапанів, прив'язаних до soil sensors.

Збереження controller settings через `PUT /api/settings` не входить у цю задачу. Тут потрібне тільки читання, parsing, validation на рівні стану і побудова локальних об'єктів для UI.

`GET /api/settings` повертає HTTPS JSON envelope:

```json
{
  "success": true,
  "data": {
    "settings": {
      "globalSettings": {},
      "remoteLogSettings": {},
      "valveSettings": [],
      "pressureSensor": null,
      "magistralWaterCounterSetting": null,
      "leafWaterCounterSettings": [],
      "soilSensorSettings": []
    },
    "controllerCurrentTimestamp": 1717245600,
    "controllerCurrentTime": "2024-06-01T12:00:00+0300"
  },
  "error": null
}
```

`controllerCurrentTimestamp` і `controllerCurrentTime` можуть бути `null`, якщо час контролера ще не синхронізований.

## Обсяг задачі

### 1. Settings API client method

Розширити local controller API client методом `getSettings`.

Потрібно:

- використовувати IP і token із задачі 004;
- виконувати `GET /api/settings`;
- додавати header `Authorization: Bearer <apiAccessToken>`;
- обробляти timeout/network/TLS/401/unexpected response;
- обробляти HTTP statuses `200`, `400`, `401`, `404`, `413`, `500`, `503` відповідно до API client із задачі 004;
- не логувати bearer token;
- повертати typed result, а не сирий JSON у UI.

Оскільки задача 004 використовує `GET /api/settings` тільки як bootstrap check, у цій задачі потрібно винести повний parsing у нормальний settings repository/use case.

### 2. Settings parsing and compatibility

Використати моделі `ControllerSettings`, створені в задачі 001, і довести JSON parsing до реальної відповіді контролера.

Потрібно:

- розпарсити `GlobalSettings`;
- розпарсити `RemoteLogSettings`;
- розпарсити `ValveSetting`;
- розпарсити `PressureSensorSetting`;
- розпарсити `WaterCounterSetting`;
- розпарсити `SoilSensorSetting`;
- коректно обробити optional/null поля;
- відрізняти відсутній sensor/counter від нульового числового значення;
- мати зрозумілу помилку schema mismatch, якщо firmware повертає неочікуваний формат.

Typed schema:

- `SettingsResponseData`:
  - `settings` - `ControllerSettings`;
  - `controllerCurrentTimestamp` - integer Unix timestamp або `null`;
  - `controllerCurrentTime` - string ISO-like time з offset або `null`.
- `ControllerSettings`:
  - `globalSettings` - required object `GlobalSettings`;
  - `remoteLogSettings` - required object `RemoteLogSettings`;
  - `valveSettings` - array of `ValveSetting`, максимум 32 items за firmware validation;
  - `pressureSensor` - `PressureSensorSetting` або `null`;
  - `magistralWaterCounterSetting` - `WaterCounterSetting` або `null`;
  - `leafWaterCounterSettings` - array of `WaterCounterSetting`, максимум 32 items;
  - `soilSensorSettings` - array of `SoilSensorSetting`, максимум 32 items.
- `GlobalSettings`:
  - `idleWaterCounterReadIntervalSeconds` - integer seconds, valid range `1..2147483`;
  - `wateringWaterCounterReadIntervalSeconds` - integer seconds, valid range `1..2147483`;
  - `idlePressureSensorReadIntervalSeconds` - integer seconds, valid range `1..2147483`;
  - `wateringPressureSensorReadIntervalSeconds` - integer seconds, valid range `1..2147483`;
  - `idleSoilSensorReadIntervalSeconds` - integer seconds, valid range `1..2147483`;
  - `wateringSoilSensorReadIntervalSeconds` - integer seconds, valid range `1..2147483`;
  - `maximumManualValveOpenTimeSeconds` - integer seconds, valid range `1..2147483`;
  - `startWateringBelowHumidityPercent` - integer `0..100`;
  - `stopWateringAboveHumidityPercent` - integer `0..100`, має бути більшим за start threshold;
  - `wateringStartMode` - enum string `immediately` або `withinWateringWindow`;
  - `wateringWindowStartTime` - `TimeOfDaySetting` або `null`;
  - `wateringWindowEndTime` - `TimeOfDaySetting` або `null`;
  - `zoneWateringDurationSeconds` - integer seconds, valid range `1..2147483`;
  - `zoneWateringRetryDelaySeconds` - integer seconds, valid range `1..2147483`.
- `TimeOfDaySetting`:
  - `hour` - integer `0..23`;
  - `minute` - integer `0..59`.
- `RemoteLogSettings`:
  - `url` - string base server ingest URL; firmware додає `/logs` і `/metrics`;
  - `token` - string controller ingest bearer token, не mobile session token.
- `ValveSetting`:
  - `pin` - integer GPIO pin;
  - `name` - string;
  - `soilSensorSlaveAddress` - integer Modbus address, має посилатися на наявний soil sensor.
- `PressureSensorSetting`:
  - `slaveAddress` - integer Modbus address `1..247`;
  - `name` - string.
- `WaterCounterSetting`:
  - `pin` - integer GPIO pin;
  - `name` - string;
  - `litersPerTick` - додатне скінченне number.
- `SoilSensorSetting`:
  - `slaveAddress` - integer Modbus address `1..247`;
  - `name` - string.

Для `wateringStartMode: "immediately"` `wateringWindowStartTime` і `wateringWindowEndTime` можуть бути `null`. Для `withinWateringWindow` обидва об'єкти мають бути задані; якщо end time менший за start time, вікно переходить через північ.

Parsing має бути покритий fixtures або unit tests із прикладами реального JSON.

### 3. Settings repository

Створити repository/use case для синхронізації settings.

Відповідальність repository:

- викликати API client;
- перетворити JSON у `ControllerSettings`;
- оновити app state in-memory;
- не зберігати settings snapshot у local storage або іншому persistent cache;
- повернути typed sync result із часом останньої успішної синхронізації.

UI не повинен сам викликати HTTP client і парсити JSON.

### 4. Build device objects from settings

Побудувати доменні об'єкти пристрою на основі settings.

Потрібні об'єкти:

- `ValveObject` для кожного `ValveSetting`;
- `SoilSensorObject` для кожного `SoilSensorSetting`;
- `PressureSensorObject`, якщо pressure sensor заданий;
- `WaterCounterObject` для кожного `WaterCounterSetting`;
- plain string `deviceObjectId` для компактних посилань в UI/state.

Важливо:

- стабільні локальні ids мають бути deterministic від `wateringHubId` і setting identity, щоб UI references лишалися стабільними після повторного sync;
- derived display data можна кешувати для UI, але технічні поля залишаються похідними від settings;
- `PlanSchema` у цій задачі не створювати, не оновлювати і не мігрувати. Згадувати її можна тільки як майбутнього споживача стабільних `DeviceObject.id`.

### 5. Configuration completeness state

Додати обчислення стану базової конфігурації.

Стан має показувати:

- `unknown`;
- `ready`;
- `incomplete`;
- `invalid`.

Мінімальні перевірки:

- є pressure sensor;
- є magistral water counter, якщо settings дозволяють його визначити;
- є хоча б один soil sensor;
- є хоча б один valve;
- кожен valve, який бере участь в автоматичному поливі, посилається на наявний soil sensor;
- GPIO pins не конфліктують у межах прочитаних settings;
- Modbus addresses soil sensors не конфліктують із pressure sensor.

Цей state потрібен для Plan і Settings UI. Він не замінює firmware validation, але має пояснювати користувачу, чому система ще не готова.

### 6. App state integration

Оновити `AppState` або відповідний state holder.

Потрібно зберігати:

- latest `ControllerSettings` тільки in-memory;
- список побудованих `DeviceObject`;
- `configurationState`:
  - `unknown`;
  - `ready`;
  - `incomplete`;
  - `invalid`;
- `settingsSyncState`:
  - `idle`;
  - `syncing`;
  - `synced`;
  - `failed`;
- `lastSettingsSyncedAt`;
- останню sync помилку.

Окремий loading flag для settings sync не потрібен. UI має виводити progress/disabled стани з `settingsSyncState`, щоб не дублювати один і той самий стан у boolean-прапорцях.

Після успішного sync:

- `WateringHubState` має перейти в `online`;
- `configurationState` має бути перерахований;
- UI не має показувати старий settings snapshot як актуальний під час активного sync без відповідної індикації.

### 7. Minimal UI integration

Оновити стартовий/головний стан додатку після bootstrap.

Мінімально UI має показувати:

- що контролер доступний;
- час останньої sync settings;
- кількість valves, soil sensors і water counters;
- configuration state;
- дію "Повторити sync";
- помилку sync, якщо вона сталася.

Повноцінні екрани `Plan`, `Zones` і `Settings` не входять у цю задачу, але після sync має бути зрозуміло, чи можна переходити до створення початкової схеми.

Усі видимі користувачу тексти minimal UI integration мають бути українською мовою: статуси sync, configuration state, кнопки, labels, empty/error states і пояснення. Технічні назви settings fields, API paths, JSON keys і enum values не перекладаються.

## Не входить у задачу

- `PUT /api/settings`;
- UI редагування settings;
- ручний запуск клапана;
- отримання sensor metrics;
- initial plan editor;
- автоматичне створення повної схеми;
- створення, оновлення або міграція `PlanSchema`;
- persistent cache/local storage для settings snapshot;
- charts;
- logs;
- server API;
- push notifications.

## Критерії готовності

Задача готова, якщо:

- local controller API client має метод `GET /api/settings`;
- відповідь контролера парситься в `ControllerSettings`;
- parser коректно обробляє optional/null поля і schema mismatch;
- settings sync винесений у repository/use case, а не реалізований напряму в UI;
- з settings будуються стабільні `DeviceObject` для valves, soil sensors, pressure sensor і water counters;
- app state містить latest settings тільки in-memory, device objects, sync state і configuration state;
- settings snapshot не зберігається в local storage/persistent cache;
- settings sync UI не містить англомовних user-facing текстів;
- configuration completeness state відрізняє `unknown`/`ready`/`incomplete`/`invalid`;
- settings sync state відрізняє `idle`/`syncing`/`synced`/`failed`;
- UI показує мінімальний результат sync і дає повторити sync;
- `401` або недоступний HTTPS API оновлюють `WateringHubState` відповідно до задачі 004;
- проєкт проходить `flutter analyze`;
- тести покривають parsing settings fixtures, побудову device objects і configuration completeness checks.
