# Задача 001: Архітектура додатку і базова модель даних

## Мета

Закласти основу Flutter-додатку, на яку потім будуть спиратися BLE onboarding, HTTPS API, робоча схема ділянки, settings, logs і charts.

На цьому етапі не потрібно реалізовувати реальне підключення до контролера, BLE, HTTPS-запити або повноцінні екрани. Потрібно створити зрозумілу структуру коду, базові доменні моделі, локальне зберігання профілю пристрою і централізований стан додатку.

## Контекст із ТЗ

Додаток працює з одним основним контролером у першій версії, але структура не повинна блокувати майбутню підтримку кількох пристроїв.

Основні дані, які додаток має вміти зберігати локально:

- профіль контролера;
- остання відома IP-адреса;
- controller `apiAccessToken`;
- BLE device id;
- display name;
- локальна схема ділянки;
- стан останнього підключення.

Схема ділянки є локальними UI-даними мобільного додатку. Вона не замінює settings контролера.

## Обсяг задачі

### 1. Структура проєкту

Запропонувати і створити базову структуру `lib/`, наприклад:

- `lib/app/` - запуск додатку, root widget, routing або shell;
- `lib/core/` - shared utilities, result/error types, time helpers;
- `lib/features/devices/` - профілі пристроїв і стан підключення;
- `lib/features/plan/` - модель схеми ділянки;
- `lib/features/controller_settings/` - моделі settings контролера;
- `lib/features/sensors/` - моделі sensor metrics;
- `lib/storage/` - локальне зберігання.

Фінальна структура може відрізнятися, якщо це краще лягає на існуючий код, але вона має явно розділяти доменну логіку, storage і UI.

### 2. Доменні моделі

Створити базові immutable-моделі для основних сутностей.

#### DeviceProfile

Має описувати локальний профіль контролера:

- `id` - локальний id профілю;
- `displayName`;
- `bleDeviceId`;
- `lastKnownIpAddress`;
- `apiAccessToken` або посилання на secure-storage key;
- `serverDeviceId`, якщо cloud налаштований;
- `createdAt`;
- `updatedAt`.

На цьому етапі можна зберігати token у моделі тільки тимчасово, якщо secure storage ще не підключається, але код має бути спроєктований так, щоб token можна було легко винести в protected storage.

#### DeviceConnectionState

Має описувати стан доступу до пристрою:

- no device;
- offline;
- connecting;
- online;
- token invalid;
- requires BLE recovery;
- waiting for reboot.

Стан має бути достатнім для майбутніх екранів Device List, onboarding і Plan.

#### ControllerSettings

Створити модель snapshot settings контролера на основі API-документації:

- `GlobalSettings`;
- `RemoteLogSettings`;
- `ValveSetting`;
- `PressureSensorSetting`;
- `WaterCounterSetting`;
- `SoilSensorSetting`.

На цьому етапі достатньо моделей і JSON serialization/deserialization. UI редагування settings не входить у задачу.

#### Device objects

Окремо від raw settings створити доменні об'єкти пристрою. Вони потрібні, щоб UI, схема і runtime-метрики працювали з однаковими сутностями, а не напряму з JSON settings.

Кожен доменний об'єкт має мати:

- стабільний локальний `id`;
- `deviceProfileId`;
- посилання на відповідний setting;
- тип об'єкта;
- derived display data з setting, наприклад name, pin або slave address.

Потрібні типи:

- `ValveObject` - посилається на `ValveSetting`, зокрема на valve pin;
- `SoilSensorObject` - посилається на `SoilSensorSetting`, зокрема на Modbus slave address;
- `PressureSensorObject` - посилається на `PressureSensorSetting`, якщо він заданий;
- `WaterCounterObject` - посилається на `WaterCounterSetting`, зокрема на counter pin і тип лічильника;
- за потреби `DeviceObjectRef` як компактне посилання `{objectType, objectId}`.

Settings залишаються джерелом технічної конфігурації: назва, pin, slave address, `litersPerTick` та інші технічні поля беруться з відповідного setting. Доменні об'єкти не повинні дублювати ці поля як незалежну правду, окрім cached/derived значень для зручності UI.

#### SensorMetric

Модель останнього відомого значення сенсора або лічильника має прив'язуватися до доменного об'єкта, а не тільки до raw `sensorId`:

- `deviceObjectRef` або `deviceObjectId`;
- `sensorId`;
- `sensorType`;
- `name`;
- `value`;
- `uptimeMs`;
- optional local/server timestamp, якщо джерело його має.

Підтримати типи:

- pressure;
- water_counter;
- soil_temperature;
- soil_humidity.

Для soil sensor один `SoilSensorObject` може мати кілька metric series, наприклад humidity і temperature. Для water counter `WaterCounterObject` використовується як об'єкт, біля якого на схемі показується витрата за останні 5 хвилин.

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
- `deviceObjectRef` на `ValveObject`;
- color/style.

Для device object marker:

- локальний id;
- position;
- `deviceObjectRef` на `SoilSensorObject`, `WaterCounterObject` або інший об'єкт, який треба показати на схемі;
- marker type або display style.

Маркер не посилається напряму на `SoilSensorSetting`, `ValveSetting` або pin/slave address. Він посилається на доменний об'єкт, а доменний об'єкт вже має reference на свій setting.

Не додавати в PlanSchema візуальну прив'язку sensor-to-zone. Сенсори, клапани і лічильники є самостійними об'єктами; схема лише розміщує їх або малює область, прив'язану до valve object.

### 3. Локальне зберігання

Реалізувати абстракцію storage для:

- збереження/читання активного `DeviceProfile`;
- збереження/читання `PlanSchema` для пристрою;
- очищення локального профілю пристрою.

На цьому етапі можна використати простий local storage, який вже доречний для Flutter-проєкту. Якщо додається dependency, вона має бути виправдана і зафіксована в `pubspec.yaml`.

Secure storage для token можна або підключити одразу, або залишити як явний наступний крок через інтерфейс `TokenStorage`. Важливо не розкидати роботу з token напряму по UI.

### 4. App state

Створити базовий state holder для додатку:

- активний профіль пристрою;
- схема активного пристрою;
- поточний `DeviceConnectionState`;
- остання помилка підключення або storage;
- loading flags для стартового завантаження.

State management має відповідати поточному стилю проєкту. Якщо стиль ще не заданий, обрати простий підхід, який не ускладнить майбутню інтеграцію BLE/API.

### 5. Мінімальна UI-перевірка

Оновити стартовий екран так, щоб він використовував новий app state хоча б мінімально:

- якщо активного пристрою немає, показати стан `No device`;
- якщо профіль є, показати display name і connection state;
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
- створені доменні моделі для device profile, connection state, controller settings, device objects, sensor metrics і plan schema;
- моделі, які приходять з API або зберігаються локально, мають JSON serialization/deserialization;
- є storage abstraction для active device profile і plan schema;
- token не прив'язаний напряму до UI і може бути винесений у secure storage;
- root app може завантажити локальний state і показати мінімальний стан пристрою;
- проєкт проходить `flutter analyze`;
- існуючі тести не зламані або оновлені під новий root UI.

## Орієнтовні наступні задачі

Після завершення цієї задачі рухаємося по реальному шляху підключення, без мокових або демо-даних:

1. `002 BLE discovery and pairing` - сканування `Automatic Watering Hub`, підключення, pairing, базове читання BLE characteristics і збереження BLE device id.
2. `003 Wi-Fi provisioning over BLE` - читання поточних Wi-Fi settings, запис SSID/password, обробка `restartScheduled`, очікування reboot і повторне підключення через BLE.
3. `004 Controller access bootstrap` - читання `WifiIpAddress` і `ApiAccessToken` через BLE, збереження IP/token, перевірка локального HTTPS доступу.
4. `005 Controller settings sync` - `GET /api/settings`, parsing settings snapshot, побудова device objects із settings і збереження актуального стану конфігурації.
5. `006 Initial plan setup from real settings` - створення першої схеми на основі реальних valves, soil sensors і water counters; користувач розміщує реальні об'єкти, а не mock markers.
