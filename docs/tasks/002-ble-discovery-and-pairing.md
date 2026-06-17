# Задача 002: BLE discovery and pairing

## Мета

Реалізувати перший технічний крок onboarding flow: пошук контролера `Automatic Watering Hub` через BLE, підключення до нього, pairing із 6-значним passkey і discovery очікуваного BLE service/characteristics для подальших задач.

На цьому етапі не потрібно налаштовувати Wi-Fi, читати API token або перевіряти HTTPS API. Потрібно створити BLE-шар, який можна безпечно використати в наступних задачах onboarding.

## Контекст із ТЗ

BLE використовується для первинного налаштування та відновлення доступу:

- пошук пристрою `Automatic Watering Hub`;
- pairing із 6-значним passkey;
- читання та запис Wi-Fi settings;
- читання IP-адреси контролера;
- читання `apiAccessToken`;
- перегляд live BLE log notifications як допоміжний діагностичний канал.

У першій версії додаток працює з одним основним контролером, але BLE-сервіс не повинен бути жорстко прив'язаний до одного глобального singleton-пристрою. Надалі він має підтримати повторне підключення, recovery і service tools.

Точний BLE contract із firmware:

- device name: `Automatic Watering Hub`;
- service UUID: `4d42b2d0-35ba-4b70-b8a2-d1cf01e904c1`;
- захист: encrypted authenticated pairing;
- passkey: `482917`;
- bond keys зберігаються ОС, тому повторний pairing для відомого телефону не має вимагатися;
- fast advertising триває перші 5 хвилин після старту, далі slow advertising;
- після disconnect advertising запускається повторно.

## Обсяг задачі

### 1. BLE dependency і дозволи платформ

Додати BLE dependency, доречну для Flutter-проєкту.

Потрібно:

- зафіксувати dependency у `pubspec.yaml`;
- додати Android permissions для BLE scan/connect і location, якщо цього вимагає обрана бібліотека або Android SDK;
- додати iOS usage descriptions для Bluetooth;
- не додавати зайві permissions, які не потрібні для BLE onboarding.

Якщо обрана бібліотека вимагає окремого handling Bluetooth/location permission status, це має бути винесено в BLE-шар або onboarding state, а не розкидано по UI.

### 2. BLE domain models

Створити моделі для BLE discovery і connection flow.

Потрібні мінімальні сутності:

- `BleDiscoveredDevice`:
  - `id`;
  - `name`;
  - optional RSSI;
  - ознака, що це ймовірний `Automatic Watering Hub`;
  - service UUID або інші advertising hints, якщо доступні.
- `BleConnectionState`:
  - idle;
  - scanning;
  - deviceFound;
  - connecting;
  - pairingRequired;
  - pairing;
  - connected;
  - disconnected;
  - permissionRequired;
  - bluetoothDisabled;
  - error.
- `BleConnectionError` або простий error type із людським повідомленням і технічною причиною для логування без секретів.

Створити централізований файл constants із реальними BLE UUID:

- service `AutomaticWateringHub`: `4d42b2d0-35ba-4b70-b8a2-d1cf01e904c1`;
- `WifiSettings`: `4d42b2d1-35ba-4b70-b8a2-d1cf01e904c1`, `READ`, encrypted, authenticated;
- `SaveWifiSettings`: `4d42b2d2-35ba-4b70-b8a2-d1cf01e904c1`, `READ`, `WRITE`, encrypted, authenticated;
- `WifiIpAddress`: `4d42b2d3-35ba-4b70-b8a2-d1cf01e904c1`, `READ`, encrypted, authenticated;
- `ApiAccessToken`: `4d42b2d4-35ba-4b70-b8a2-d1cf01e904c1`, `READ`, encrypted, authenticated;
- `LogNotifications`: `4d42b2d5-35ba-4b70-b8a2-d1cf01e904c1`, `READ`, `NOTIFY`, encrypted, authenticated.

UUID не мають дублюватися по коду. На цьому етапі потрібно лише discover service/characteristics і підтвердити, що підключено очікуваний BLE service; читання Wi-Fi/IP/token/log payload виконується в наступних задачах.

### 3. BLE service abstraction

Створити абстракцію BLE-сервісу, яку можна підмінити в тестах.

Мінімальний контракт:

- перевірити доступність Bluetooth і permissions;
- запустити scan;
- зупинити scan;
- повертати stream/list знайдених пристроїв;
- підключитися до вибраного пристрою;
- виконати pairing або ініціювати системний pairing flow;
- відключитися;
- прочитати базову інформацію про BLE-пристрій або доступні services/characteristics;
- перевірити наявність service `4d42b2d0-35ba-4b70-b8a2-d1cf01e904c1` після connect.

UI не повинен напряму працювати з класами BLE-бібліотеки. Усі типи конкретної бібліотеки мають залишатися всередині infrastructure implementation.

### 4. Onboarding state для discovery/pairing

Додати state holder для першої частини onboarding.

Стан має містити:

- поточний крок;
- список знайдених BLE-пристроїв;
- вибраний BLE device;
- `BleConnectionState` як єдине джерело стану scan/connect/pairing;
- помилку останньої BLE-операції.

Доступність переходу до наступного кроку не зберігати окремим полем. UI має обчислювати її з поточного кроку, вибраного BLE device і `BleConnectionState`.

Не додавати окремі loading flags для scan/connect/pairing, якщо ці стани вже представлені в `BleConnectionState`. UI має виводити progress/disabled стани з `BleConnectionState`, щоб scan, connect і pairing лишалися послідовним state machine, а не набором незалежних booleans.

Цей state може бути окремим від глобального `AppState`, але після успішного pairing має оновити або створити `WateringHub` із `bleDeviceId` і базовим `displayName`.

### 5. UI першого BLE-кроку

Додати мінімальний onboarding screen або flow для BLE discovery.

Екран має дозволяти:

- бачити стан Bluetooth/permissions;
- запустити або повторити scan;
- побачити знайдені `Automatic Watering Hub` пристрої;
- вибрати пристрій;
- підключитися;
- ввести 6-значний passkey, якщо pairing не обробляється повністю системним діалогом;
- побачити успішний стан pairing;
- перейти до наступного кроку onboarding.

UI має явно відрізняти стани "нічого не знайдено", "Bluetooth вимкнений", "немає дозволу" і "помилка підключення".

Усі видимі користувачу тексти onboarding screen мають бути українською мовою: заголовки, кнопки, підказки, порожні стани, validation errors і user-facing BLE errors. Технічні назви BLE device/service/characteristics, UUID і firmware contract values не перекладаються.

### 6. Збереження BLE device id

Після успішного підключення/pairing потрібно:

- створити або оновити активний `WateringHub`;
- зберегти `bleDeviceId`;
- зберегти зрозумілий `displayName`, якщо його можна отримати з advertising або BLE device name;
- не зберігати Wi-Fi password, API token або інші секрети в цій задачі.

## Не входить у задачу

- читання або запис Wi-Fi settings;
- очікування reboot після Wi-Fi provisioning;
- читання IP-адреси контролера;
- читання `apiAccessToken`;
- HTTPS client;
- certificate pinning;
- `GET /api/settings`;
- live BLE logs;
- service tools;
- повноцінний дизайн onboarding.

## Критерії готовності

Задача готова, якщо:

- dependency для BLE додана й проєкт збирається;
- Android/iOS BLE permissions налаштовані;
- BLE constants зібрані в одному місці;
- є BLE service abstraction без прямої залежності UI від BLE-бібліотеки;
- реалізовано scan `Automatic Watering Hub` пристроїв;
- реалізовано connect/pairing flow із 6-значним passkey або системним pairing;
- після успішного pairing локально зберігається `bleDeviceId` в активному `WateringHub`;
- onboarding UI показує реальні стани scan/connect/pairing;
- onboarding UI не містить англомовних user-facing текстів;
- помилки не містять Wi-Fi password, API token або інших секретів;
- проєкт проходить `flutter analyze`;
- додані або оновлені тести для BLE state/service abstraction там, де це можливо без реального BLE hardware.
