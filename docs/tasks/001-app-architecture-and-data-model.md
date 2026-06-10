# Задача 001: Архітектура додатку і базова модель даних

## Мета

Закласти основу Flutter-додатку, на яку потім будуть спиратися BLE onboarding, HTTPS API, робоча схема ділянки, settings, logs і charts.

На цьому етапі не потрібно реалізовувати реальне підключення до контролера, BLE, HTTPS-запити або повноцінні екрани. Потрібно створити зрозумілу структуру коду, базові доменні моделі, локальне зберігання профілю watering hub і централізований стан додатку.

## Контекст із ТЗ

Додаток працює з одним основним контролером у першій версії, але структура не повинна блокувати майбутню підтримку кількох пристроїв.

Основні дані, які додаток має вміти зберігати локально:

- профіль watering hub;
- остання відома IP-адреса;
- controller `apiAccessToken` у secure storage;
- BLE device id;
- display name;
- локальна схема ділянки;
- стан останнього підключення.

Схема ділянки є локальними UI-даними мобільного додатку. Вона не замінює settings контролера.

Усі BLE read/write results і HTTPS responses мають єдиний JSON envelope:

```json
{
  "success": true,
  "data": {},
  "error": null
}
```

Для помилки:

```json
{
  "success": false,
  "data": {},
  "error": "Missing field: ssid"
}
```

Моделі API мають парсити саме цей envelope, а не очікувати, що payload лежить у корені JSON.

## Обсяг задачі

### 1. Структура проєкту

Запропонувати і створити базову структуру `lib/`, наприклад:

- `lib/app/` - запуск додатку, root widget, routing або shell;
- `lib/core/` - shared utilities, result/error types, time helpers;
- `lib/features/watering_hubs/` - профілі watering hub і стан підключення;
- `lib/features/plan/` - модель схеми ділянки;
- `lib/features/controller_settings/` - моделі settings контролера;
- `lib/features/sensors/` - моделі sensor metrics;
- `lib/storage/` - локальне зберігання.

Фінальна структура може відрізнятися, якщо це краще лягає на існуючий код, але вона має явно розділяти доменну логіку, storage і UI.

### 2. Доменні моделі

Створити базові immutable-моделі для основних сутностей.

#### WateringHub

Має описувати локальний профіль контролера `Automatic Watering Hub`:

- `id` - локальний id watering hub;
- `displayName`;
- `bleDeviceId`;
- `lastKnownIpAddress`;
- `apiAccessToken` - in-memory controller token, який заповнюється з secure storage під час старту додатку;
- `serverDeviceId`, якщо cloud налаштований;
- `createdAt`;
- `updatedAt`.

`apiAccessToken` не має серіалізуватися в JSON або plain local storage разом із `WateringHub`. Persistent storage для token має бути тільки secure storage за `wateringHubId`; у `WateringHub` token тримається для зручного доступу в runtime.

#### WateringHubState

Має описувати стан доступу до watering hub:

- `noDevice` - у додатку ще немає активного `WateringHub`;
- `offline` - профіль є, але зараз немає активного підключення або доступність ще не перевірена;
- `connecting` - додаток намагається встановити доступ до hub через BLE або HTTPS;
- `ipPending` - IP через BLE прочитано як `0.0.0.0`, тобто контролер ще не підключився до Wi-Fi;
- `checkingLocalHttps` - IP і token є, додаток перевіряє локальний HTTPS доступ через `GET /api/settings`;
- `online` - локальний HTTPS доступ підтверджено, token прийнятий;
- `httpsUnavailable` - IP/token є, але HTTPS API недоступний: timeout, network/TLS/controller unavailable;
- `tokenInvalid` - контролер повернув `401`, token треба перечитати через BLE;
- `requiresBleRecovery` - для відновлення доступу треба підключитися через BLE: перечитати IP або token;
- `reconnectingBle` - додаток повторно шукає/підключає той самий BLE device після disconnect/reboot/recovery.

Стан має бути достатнім для майбутніх екранів Device List, onboarding і Plan.

#### ControllerSettings

Створити модель snapshot settings контролера на основі API-документації:

- `GlobalSettings`:
  - `idleWaterCounterReadIntervalSeconds` - integer seconds;
  - `wateringWaterCounterReadIntervalSeconds` - integer seconds;
  - `idlePressureSensorReadIntervalSeconds` - integer seconds;
  - `wateringPressureSensorReadIntervalSeconds` - integer seconds;
  - `idleSoilSensorReadIntervalSeconds` - integer seconds;
  - `wateringSoilSensorReadIntervalSeconds` - integer seconds;
  - `maximumManualValveOpenTimeSeconds` - integer seconds;
  - `startWateringBelowHumidityPercent` - integer `0..100`;
  - `stopWateringAboveHumidityPercent` - integer `0..100`;
  - `wateringStartMode` - enum string `immediately` або `withinWateringWindow`;
  - `wateringWindowStartTime` - `TimeOfDaySetting` або `null`;
  - `wateringWindowEndTime` - `TimeOfDaySetting` або `null`;
  - `zoneWateringDurationSeconds` - integer seconds;
  - `zoneWateringRetryDelaySeconds` - integer seconds.
- `TimeOfDaySetting`:
  - `hour` - integer `0..23`;
  - `minute` - integer `0..59`.
- `RemoteLogSettings`:
  - `url` - string server ingest base URL, до якого firmware додає `/logs` і `/metrics`;
  - `token` - string controller ingest bearer token, не mobile session token.
- `ValveSetting`:
  - `pin` - integer GPIO pin;
  - `name` - string;
  - `soilSensorSlaveAddress` - integer Modbus slave address існуючого soil sensor.
- `PressureSensorSetting`:
  - `slaveAddress` - integer Modbus slave address;
  - `name` - string.
- `WaterCounterSetting`:
  - `pin` - integer GPIO pin;
  - `name` - string;
  - `litersPerTick` - додатне скінченне number.
- `SoilSensorSetting`:
  - `slaveAddress` - integer Modbus slave address;
  - `name` - string.

Назви ключів у JSON `settings` мають бути зафіксовані явно:

- `globalSettings` - object `GlobalSettings`;
- `remoteLogSettings` - object `RemoteLogSettings`;
- `valveSettings` - array of `ValveSetting`;
- `pressureSensor` - `PressureSensorSetting` або `null`;
- `magistralWaterCounterSetting` - `WaterCounterSetting` або `null`;
- `leafWaterCounterSettings` - array of `WaterCounterSetting`;
- `soilSensorSettings` - array of `SoilSensorSetting`.

`pressureSensor` і `magistralWaterCounterSetting` у settings можуть бути `null`. Arrays `valveSettings`, `leafWaterCounterSettings`, `soilSensorSettings` мають парситися як списки відповідних типів.

На цьому етапі достатньо моделей і JSON serialization/deserialization. UI редагування settings не входить у задачу.

#### Device objects

Окремо від raw settings створити доменні об'єкти пристрою. Вони потрібні, щоб UI, схема і runtime-метрики працювали з однаковими сутностями, а не напряму з JSON settings.

Кожен доменний об'єкт має мати:

- стабільний локальний `id`, унікальний серед усіх `WateringHub` у локальному storage додатку;
- `wateringHubId`;
- посилання на відповідний setting;
- тип об'єкта;
- derived display data з setting, наприклад name, pin або slave address.

`DeviceObject.id` не має бути унікальним тільки в межах одного контролера. Він має бути глобально унікальним серед усіх збережених watering hubs, щоб `PlanSchema`, metrics cache і UI state могли посилатися на об'єкт одним id без додаткового namespace. Рекомендований формат deterministic id: `<wateringHubId>:<objectType>:<settingIdentity>`, наприклад `hub_123:valve:19`, `hub_123:soil_sensor:1`, `hub_123:water_counter:34`.

Потрібні типи:

- `ValveObject` - посилається на `ValveSetting`, зокрема на valve pin;
- `SoilSensorObject` - посилається на `SoilSensorSetting`, зокрема на Modbus slave address;
- `PressureSensorObject` - посилається на `PressureSensorSetting`, якщо він заданий;
- `WaterCounterObject` - посилається на `WaterCounterSetting`, зокрема на counter pin і тип лічильника.

Для посилань на device object використовувати plain string `deviceObjectId`.

Settings залишаються джерелом технічної конфігурації: назва, pin, slave address, `litersPerTick` та інші технічні поля беруться з відповідного setting. Доменні об'єкти не повинні дублювати ці поля як незалежну правду, окрім cached/derived значень для зручності UI.

#### SensorMetric

Модель останнього відомого значення сенсора або лічильника має прив'язуватися до доменного об'єкта, а не тільки до raw `sensorId`:

- `deviceObjectId`;
- `sensorId`;
- `sensorType`;
- `name`;
- `value`;
- `uptimeMs`;
- `timestamp`.

Підтримати типи:

- `pressure`;
- `water_counter`;
- `soil_temperature`;
- `soil_humidity`.

Модель має відповідати payload `GET /api/sensors/metrics`: `sensorId` integer, `sensorType` enum string, `name` string, `value` number або `null`, `uptimeMs` integer. `timestamp` є обов'язковим у mobile model: якщо джерело метрики не повертає timestamp, як controller `GET /api/sensors/metrics`, заповнювати його поточним часом отримання даних на телефоні.

Для soil sensor один `SoilSensorObject` може мати кілька metric series, наприклад humidity і temperature.

#### PlanSchema

Модель локальної схеми ділянки зберігає візуальне розташування об'єктів, але не є джерелом технічної конфігурації.

Схема містить:

- id схеми;
- version;
- canvas size або normalized coordinate system;
- список zone shape elements;
- список будівель/орієнтирів;
- список device object markers.

Для zone shape element:

- локальний id;
- polygon або набір normalized points;
- `deviceObjectId` на `ValveObject`;
- color/style.

Для building/landmark element:

- локальний id;
- `type` - enum `building`, `landmark`;
- `label` - string або `null`;
- geometry:
  - `polygon` - набір normalized points для будинку, навісу, теплиці або іншого площинного орієнтира;
  - або `position` - normalized point для точкового орієнтира;
- `style` - простий візуальний стиль, наприклад fill color, stroke color, icon або marker type.

Будівлі й орієнтири є тільки локальними UI-елементами схеми. Вони не посилаються на controller settings і не створюють device objects.

Для device object marker:

- локальний id;
- position;
- `deviceObjectId` на `SoilSensorObject`, `WaterCounterObject` або інший об'єкт, який треба показати на схемі;
- marker type або display style.

Маркер не посилається напряму на `SoilSensorSetting`, `ValveSetting` або pin/slave address. Він посилається на доменний об'єкт, а доменний об'єкт вже має reference на свій setting.

Не додавати в PlanSchema візуальну прив'язку sensor-to-zone. Сенсори, клапани і лічильники є самостійними об'єктами; схема лише розміщує їх або малює область, прив'язану до valve object.

### 3. Локальне зберігання

Реалізувати абстракцію storage для:

- збереження/читання активного `WateringHub`;
- збереження/читання `PlanSchema` для watering hub;
- очищення локального профілю watering hub.

На цьому етапі можна використати простий local storage, який вже доречний для Flutter-проєкту. Якщо додається dependency, вона має бути виправдана і зафіксована в `pubspec.yaml`.

Secure storage для token підключити одразу. Важливо не розкидати роботу з token напряму по UI.

### 4. App state

Створити базовий state holder для додатку:

- активний `WateringHub`;
- схема активного watering hub;
- поточний `WateringHubState`;
- остання помилка підключення або storage;
- `AppStartupState` для початкового завантаження:
  - `initializing` - додаток читає локальний `WateringHub`, `PlanSchema` і token із secure storage;
  - `ready` - стартове завантаження завершене, state можна показувати в UI;
  - `failed` - не вдалося прочитати local або secure storage, помилка доступна як typed error.

`AppStartupState` потрібен, щоб UI не показував `noDevice` або неповний профіль, поки стартове читання storage ще триває. Окремі loading flags для `WateringHub`, `PlanSchema` і token у цій задачі не потрібні.

State management має відповідати поточному стилю проєкту. Якщо стиль ще не заданий, обрати простий підхід, який не ускладнить майбутню інтеграцію BLE/API.

### 5. Мінімальна UI-перевірка

Оновити стартовий екран так, щоб він використовував новий app state хоча б мінімально:

- якщо активного пристрою немає, показати стан `noDevice`;
- якщо профіль є, показати display name і `WateringHubState`;
- без реалізації реального підключення.

Це потрібно тільки для перевірки, що моделі, storage і app state під'єднані до Flutter tree.

## Не входить у задачу

- BLE scan/pairing;
- HTTPS client;
- certificate pinning;
- реальний `GET /api/settings`;
- реальний `GET /api/sensors/metrics`;
- редактор схеми;
- повноцінний Plan screen;
- charts;
- logs;
- push notifications;
- UI редагування controller settings.

## Критерії готовності

Задача готова, якщо:

- у `lib/` є зрозуміла базова структура модулів;
- створені доменні моделі для `WateringHub`, `WateringHubState`, controller settings, device objects, sensor metrics і plan schema;
- моделі, які приходять з API або зберігаються локально, мають JSON serialization/deserialization; `WateringHub.apiAccessToken` виключається з JSON serialization;
- є storage abstraction для active `WateringHub` і plan schema;
- `apiAccessToken` зберігається persistently тільки в secure storage, а в `WateringHub` заповнюється in-memory під час старту;
- root app може завантажити локальний state і показати мінімальний стан пристрою;
- проєкт проходить `flutter analyze`;
- існуючі тести не зламані або оновлені під новий root UI.
