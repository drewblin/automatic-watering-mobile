# Задача 007: Home device dashboard and manual valve control

## Мета

Замінити тимчасовий головний екран після успішного onboarding/settings sync на робочий dashboard контролера.

Головний екран має показувати всі налаштовані device objects контролера з поточними показниками, отриманими через локальний HTTPS API. Для клапанів потрібно додати примусове відкриття на заданий час через API контролера.

План ділянки і редактор схеми відкладаються на post-release і не входять у цю задачу. Dashboard має бути списковим/секційним екраном без залежності від `PlanSchema`.

Кнопку переходу в налаштування контролера потрібно перенести з body головного екрана у верхній правий кут `AppBar` як іконку-шестерню.

Усі видимі користувачу тексти мають бути українською мовою.

## Контекст із ТЗ і firmware API

Задачі 005 і 006 уже дають додатку:

- активний `WateringHub`;
- останній успішно зчитаний `ControllerSettings`;
- побудовані `DeviceObject` для клапанів, soil sensors, pressure sensor і water counters;
- локальний HTTPS API client із bearer token auth і certificate pinning;
- сторінку редагування settings через `PUT /api/settings`.

Ця задача додає daily-use екран для локального контролю.

Контракт firmware описаний у:

`https://github.com/drewblin/automatic-watering-hub/blob/master/mobile-app-developer-documentation.md`

Потрібні endpoints:

- `GET /api/sensors/metrics`;
- `POST /api/valves/open-for-time`.

## Обсяг задачі

### 1. Entry point головного екрана

Оновити `HomeScreen` для стану `AppStartupStatus.ready`.

Потрібно:

- прибрати кнопку **Налаштування контролера** з центрального body;
- додати в `AppBar` icon button із шестернею;
- по натисканню шестерні відкривати `ControllerSettingsScreen`;
- body головного екрана замінити на dashboard налаштованих пристроїв;
- не використовувати `PlanSchema` для побудови dashboard;
- не показувати landing/marketing/empty декоративний екран, якщо settings уже є.

У `AppBar`:

- title: **Автоматичний полив**;
- action icon: шестерня;
- tooltip: **Налаштування контролера**.

### 2. Metrics API client

Розширити `LocalControllerApiClient` методом читання sensor metrics.

Запит:

```http
GET /api/sensors/metrics
Authorization: Bearer <apiAccessToken>
```

Відповідь:

```json
{
  "success": true,
  "data": {
    "sensors": [
      {
        "sensorId": 2,
        "sensorType": "pressure",
        "name": "Pressure sensor",
        "value": 2.4,
        "uptimeMs": 123456
      }
    ]
  },
  "error": null
}
```

Потрібно:

- парсити envelope через наявний `ApiEnvelope`;
- парсити `data.sensors` як список `SensorMetric`;
- заповнювати `SensorMetric.timestamp` поточним часом отримання відповіді на телефоні;
- обробляти HTTP statuses `200`, `400`, `401`, `404`, `413`, `500`, `503`;
- не логувати bearer token;
- відрізняти `value: null` від `value: 0`;
- повертати typed result, а не сирий JSON у UI.

`sensorId` означає:

- Modbus slave address для `pressure`, `soil_temperature`, `soil_humidity`;
- GPIO pin для `water_counter`.

Поточні `sensorType`:

- `pressure`;
- `water_counter`;
- `soil_temperature`;
- `soil_humidity`.

### 3. Dashboard refresh repository / controller

Додати окремий repository або controller для refresh головного dashboard.

Відповідальність:

- при refresh запитувати актуальні settings через `GET /api/settings`;
- після успішного settings sync перебудовувати `DeviceObject`;
- викликати `LocalControllerApiClient.getSensorMetrics`;
- використовувати active `WateringHub.lastKnownIpAddress` і `apiAccessToken`;
- мапити metrics до device objects;
- тримати latest metrics тільки in-memory;
- мати стан dashboard refresh:
  - `idle`;
  - `loading`;
  - `loaded`;
  - `failed`.

Потрібно зберігати:

- latest list/map `SensorMetric`;
- `lastMetricsSyncedAt`;
- останню помилку refresh;
- стан активного refresh;
- стан ручного відкриття клапана, якщо він не винесений в окремий controller.

Dashboard має мати дію **Оновити стан**. Ця дія завжди виконує комплексний refresh: спочатку `GET /api/settings`, потім `GET /api/sensors/metrics`. Після відкриття ready dashboard потрібно виконати initial dashboard refresh автоматично за тим самим порядком.

Порядок refresh:

1. Виконати `GET /api/settings`.
2. Розпарсити актуальний `ControllerSettings`.
3. Оновити in-memory settings snapshot у `AppState`.
4. Перебудувати `DeviceObject` з актуальних settings.
5. Виконати `GET /api/sensors/metrics`.
6. Зіставити metrics уже з актуальними device objects.
7. Оновити `lastMetricsSyncedAt` і `lastSettingsSyncedAt`/`SettingsResponseData.syncedAt`.

Якщо `GET /api/settings` завершився помилкою:

- не виконувати `GET /api/sensors/metrics`;
- не скидати останній успішний settings snapshot;
- показати українське повідомлення про помилку;
- дати кнопку **Спробувати ще раз**;
- `401` має переводити користувача в стан, сумісний із recovery через BLE/token reread, якщо такий state уже передбачений у app layer.

Якщо settings sync успішний, але refresh metrics завершився помилкою:

- залишити актуальні settings і перебудовані device objects;
- не скидати останні успішні metrics, якщо вони є, але показати що оновити показники не вдалося;
- показати українське повідомлення про помилку;
- дати кнопку **Спробувати ще раз**;
- `401` має переводити користувача в стан, сумісний із recovery через BLE/token reread, якщо такий state уже передбачений у app layer.

### 4. Відображення клапанів

Клапан будується з `ValveObject` / `ValveSetting`.

Для кожного клапана показувати:

- назву клапана: `ValveSetting.name`;
- поточну вологість прив'язаного датчика, якщо є metric:
  - `sensorType: soil_humidity`;
  - `sensorId == ValveSetting.soilSensorSlaveAddress`;
- поточну температуру грунту прив'язаного датчика, якщо є metric:
  - `sensorType: soil_temperature`;
  - `sensorId == ValveSetting.soilSensorSlaveAddress`;
- стан metric value:
  - числове значення;
  - окремий стан **значення недоступне**, якщо `value == null`;
  - окремий стан **немає даних**, якщо metric не прийшла;
- час останнього отримання metrics на телефоні;
- кнопку **Відкрити клапан**.

Не показувати на card клапана GPIO pin, Modbus address або назву прив'язаного датчика. Це налаштування, а не daily-use інформація. Якщо прив'язаний датчик не знайдено або metrics не можуть бути зіставлені, показати лаконічний стан **Потрібна перевірка налаштувань** без технічних ids.

Формат значень:

- humidity: percent, наприклад `64.2 %`;
- soil temperature: Celsius, наприклад `21.8 °C`.

UI не має показувати клапан як реально відкритий після команди, якщо API не повертає live-state клапана. Після успішної команди показати тільки transient notification/snackbar **Команду відправлено**. Не додавати постійний локальний status на card клапана.

### 5. Ручне відкриття клапана

Додати HTTPS API method:

```http
POST /api/valves/open-for-time
Authorization: Bearer <apiAccessToken>
Content-Type: application/json
```

Тіло запиту:

```json
{
  "pin": 19,
  "seconds": 60
}
```

Відповідь:

```json
{
  "success": true,
  "data": {
    "pin": 19,
    "seconds": 60
  },
  "error": null
}
```

Потрібно:

- додати method у `LocalControllerApiClient`;
- додати repository/use case для manual valve control;
- не формувати JSON у widget layer;
- перевіряти duration на клієнті до запиту;
- показувати confirmation dialog перед відправкою;
- блокувати повторне натискання для того самого клапана, поки запит триває;
- обробляти `404 Not Found` як відсутній клапан на контролері;
- обробляти `401` як invalid token/recovery case;
- обробляти network/TLS/controller unavailable українською мовою;
- після успішної команди показати коротке повідомлення українською.

Validation:

- `pin` береться тільки з `ValveSetting.pin`, користувач не вводить pin вручну;
- `seconds` має бути додатним integer;
- `seconds <= settings.globalSettings.maximumManualValveOpenTimeSeconds`;
- default duration: `settings.globalSettings.zoneWateringDurationSeconds`;
- якщо default duration перевищує maximum manual duration, default у UI має бути обмежений maximum manual duration або форма має одразу показати помилку;
- destructive/critical дія потребує підтвердження.

Confirmation dialog:

- title: **Відкрити клапан?**;
- content має містити назву клапана і duration;
- primary action: **Відкрити**;
- secondary action: **Скасувати**.

Duration control:

- numeric input або stepper/slider;
- поруч показати maximum manual duration;
- помилки validation показувати біля поля українською.

### 6. Відображення датчиків вологості грунту

Soil sensor будується з `SoilSensorObject` / `SoilSensorSetting`.

Для кожного soil sensor показувати:

- назву датчика: `SoilSensorSetting.name`;
- поточну вологість:
  - metric `sensorType: soil_humidity`;
  - `sensorId == SoilSensorSetting.slaveAddress`;
- поточну температуру грунту:
  - metric `sensorType: soil_temperature`;
  - `sensorId == SoilSensorSetting.slaveAddress`;
- стан metric value:
  - числове значення;
  - **значення недоступне**, якщо `value == null`;
  - **немає даних**, якщо metric відсутня;
- час останнього отримання metrics на телефоні.

Не показувати Modbus address, `sensorId`, `uptimeMs` або список прив'язаних клапанів на основному екрані.

### 7. Відображення датчика тиску

Pressure sensor будується з `PressureSensorObject` / `PressureSensorSetting`, якщо `settings.pressureSensor != null`.

Якщо pressure sensor налаштований, показувати:

- назву датчика;
- поточний тиск:
  - metric `sensorType: pressure`;
  - `sensorId == PressureSensorSetting.slaveAddress`;
- одиниця вимірювання: `bar`;
- **значення недоступне**, якщо `value == null`;
- **немає даних**, якщо metric відсутня;
- час останнього отримання metrics.

Якщо pressure sensor не налаштований:

- не створювати device card для неіснуючого sensor object;
- у summary/configuration state можна показати, що датчик тиску не налаштований, якщо configuration state incomplete.

### 8. Відображення лічильників води

Water counter будується з `WaterCounterObject` / `WaterCounterSetting`.

Потрібно окремо візуально відрізняти:

- магістральний лічильник води з `magistralWaterCounterSetting`;
- лічильники води гілок із `leafWaterCounterSettings`.

Якщо поточний `WaterCounterObject` не містить явного subtype, додати subtype або інший derived field, щоб UI міг показати правильну групу. Не визначати subtype тільки з назви.

Для кожного water counter показувати:

- назву;
- тип:
  - **Магістральний лічильник**;
  - **Лічильник гілки**;
- поточне значення:
  - metric `sensorType: water_counter`;
  - `sensorId == WaterCounterSetting.pin`;
- одиниця і сенс значення: **загальна кількість літрів з моменту запуску контролера**;
- **значення недоступне**, якщо `value == null`;
- **немає даних**, якщо metric відсутня;
- час останнього отримання metrics.

Не показувати GPIO pin, `litersPerTick` або інші технічні налаштування лічильника на основному екрані.

Не показувати `water_counter` як real-time flow rate і не підписувати його як “витрата за останні 5 хвилин”. За актуальним уточненням API це total liters since controller startup.

### 9. Dashboard layout

Головний екран має бути компактним робочим dashboard.

Рекомендована структура:

- верхній status block:
  - назва контролера;
  - стан локального HTTPS доступу;
  - поточний час з точки зору контролера;
  - час останнього settings sync;
  - час останнього metrics refresh;
  - короткий configuration state;
  - action **Оновити стан**;
- секція **Клапани**;
- секція **Датчики вологості грунту**;
- секція **Датчик тиску**;
- секція **Лічильники води**.

Для секцій:

- якщо devices немає, показувати короткий empty state українською;
- cards не вкладати в інші cards;
- не використовувати hero/landing композицію;
- controls мають бути стабільного розміру і не стрибати при refresh;
- довгі назви пристроїв мають переноситися без overflow.

Показ часу:

- поточний час контролера брати з останнього `SettingsResponseData.controllerCurrentTime` або `controllerCurrentTimestamp`;
- для settings sync використовувати `SettingsResponseData.syncedAt`, якщо він є в моделі;
- для metrics refresh використовувати `lastMetricsSyncedAt`;
- для окремих metrics використовувати `SensorMetric.timestamp`;
- `uptimeMs` не показувати як час останнього оновлення, бо це uptime контролера, а не wall-clock timestamp.

Якщо `controllerCurrentTime` і `controllerCurrentTimestamp` дорівнюють `null`, показати **Час контролера не синхронізовано**. Не підміняти controller time часом телефону.

### 10. State integration

Оновити app/home state так, щоб UI не тримав бізнес-стан тільки в widgets.

Потрібні стани:

- dashboard refresh state:
  - `idle`;
  - `loading`;
  - `loaded`;
  - `failed`;
- manual valve command state:
  - `idle`;
  - `confirming` або локальний dialog state;
  - `sending`;
  - `sent`;
  - `failed`.

Можна адаптувати назви до існуючої архітектури, але не дублювати один і той самий стан кількома boolean-прапорцями.

Latest metrics не зберігати в persistent storage. Після restart додатку metrics треба читати заново.

### 11. Error handling

Dashboard refresh errors:

- timeout/network: **Не вдалося отримати показники. Перевірте з'єднання з контролером.**
- TLS/fingerprint: **Не вдалося перевірити HTTPS-сертифікат контролера.**
- `401`: **Контролер відхилив токен доступу. Потрібне повторне підключення.**
- unexpected response/schema mismatch: **Контролер повернув неочікувану відповідь.**

Manual valve errors:

- duration too long: **Час відкриття не може перевищувати N с.**
- valve not found / `404`: **Клапан не знайдено на контролері.**
- network/TLS/token errors аналогічно metrics refresh;
- controller unavailable / `503`: **Контролер тимчасово недоступний.**

Помилки не мають містити bearer token або інші секрети.

### 12. Не входить у задачу

- `Plan` screen;
- `PlanSchema` editor;
- графічна схема ділянки;
- charts/history screen;
- server API для metrics latest/series/summary;
- push notifications;
- BLE live logs;
- server logs;
- Modbus device address service tools;
- автоматичне визначення реального open/closed state клапана, якщо API його не повертає;
- persistent cache для metrics.

## Критерії готовності

Задача готова, якщо:

- головний ready screen показує dashboard пристроїв, а не тимчасову центральну кнопку settings;
- settings відкриваються через шестерню в `AppBar`;
- dashboard будується з поточного `ControllerSettings` і `DeviceObject`, без залежності від `PlanSchema`;
- initial load і кнопка **Оновити стан** виконують комплексний refresh: `GET /api/settings`, rebuild `DeviceObject`, потім `GET /api/sensors/metrics`;
- якщо `GET /api/settings` падає, metrics refresh не виконується;
- `GET /api/sensors/metrics` реалізований у local controller API client;
- metrics response парситься в typed `SensorMetric`;
- `timestamp` metrics заповнюється часом отримання відповіді на телефоні;
- `value: null` показується як недоступне значення і не плутається з `0`;
- cards пристроїв показують тільки назву і поточні показники, без GPIO pin, Modbus address, `sensorId`, `litersPerTick` і назв прив'язаних датчиків;
- soil sensor card показує humidity і temperature за внутрішнім mapping `sensorId == slaveAddress`;
- pressure sensor card показує pressure у `bar`;
- water counter card показує total liters since controller startup за внутрішнім mapping `sensorId == pin`;
- water counters не підписані як real-time flow або витрата за останні 5 хвилин;
- valve card показує humidity і temperature прив'язаного soil sensor без показу назви датчика або технічних ids;
- valve card має дію ручного відкриття;
- після успішного ручного відкриття показується transient notification, а не постійний status на card;
- dashboard показує поточний час контролера з `controllerCurrentTime` або `controllerCurrentTimestamp`;
- `POST /api/valves/open-for-time` реалізований у API client/repository;
- manual valve payload має поля `pin` і `seconds`;
- duration для manual valve control валідовується проти `maximumManualValveOpenTimeSeconds`;
- перед відкриттям клапана показується confirmation українською;
- під час відправки команди повторна дія для клапана заблокована;
- success/error стани manual valve command показуються українською;
- dashboard refresh має loading/loaded/failed стани;
- dashboard має кнопку повторного refresh, яка запитує і актуальні settings, і поточні metrics;
- latest metrics не зберігаються в persistent storage;
- `401`, network, TLS, `404`, `503` і schema mismatch обробляються зрозумілими українськими повідомленнями;
- user-facing UI не містить англомовних текстів;
- bearer token не логуються і не показуються;
- проєкт проходить `flutter analyze`;
- додані або оновлені тести для metrics parsing, мапінгу metrics до device objects, dashboard UI, manual valve validation і manual valve API payload.
