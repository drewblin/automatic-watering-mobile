# Задача 003: Wi-Fi provisioning over BLE

## Мета

Реалізувати налаштування Wi-Fi контролера через BLE після успішного discovery/pairing із задачі 002.

На цьому етапі користувач має мати змогу прочитати поточний стан Wi-Fi, ввести або оновити SSID/password, записати налаштування в контролер і повторно підключитися до контролера через BLE після перезавантаження.

## Контекст із ТЗ

Wi-Fi credentials не мають передаватися через HTTPS API. Вони налаштовуються тільки через BLE.

Onboarding flow містить такі кроки:

1. Сканування BLE-пристроїв.
2. Підключення та pairing.
3. Введення або оновлення Wi-Fi credentials.
4. Збереження Wi-Fi settings.
5. Очікування перезавантаження контролера.
6. Повторне BLE-підключення.
7. Отримання IP-адреси та API token.
8. Перевірка HTTPS-з'єднання.

Ця задача покриває кроки 3-6. IP і token читаються в задачі 004.

BLE read/write values є UTF-8 JSON strings у єдиному envelope:

```json
{
  "success": true,
  "data": {},
  "error": null
}
```

У разі помилки `success` дорівнює `false`, `data` є object, `error` є string із повідомленням firmware.

Контролер не надсилає окреме BLE-повідомлення про початок або завершення reboot. Додаток отримує тільки result запису Wi-Fi settings, після чого має сам керувати паузою, disconnect/reconnect і retry.

## Обсяг задачі

### 1. BLE Wi-Fi characteristics contract

Розширити BLE constants і service abstraction характеристиками Wi-Fi provisioning.

Потрібно централізовано описати:

- characteristic для читання поточних Wi-Fi settings:
  - name `WifiSettings`;
  - UUID `4d42b2d1-35ba-4b70-b8a2-d1cf01e904c1`;
  - properties `READ`, encrypted, authenticated;
  - response envelope:

```json
{
  "success": true,
  "data": {
    "wifiSettings": {
      "ssid": "network-name",
      "password": "network-password"
    }
  },
  "error": null
}
```

- characteristic для запису нових Wi-Fi settings:
  - name `SaveWifiSettings`;
  - UUID `4d42b2d2-35ba-4b70-b8a2-d1cf01e904c1`;
  - properties `READ`, `WRITE`, encrypted, authenticated;
  - write request:

```json
{
  "ssid": "network-name",
  "password": "network-password"
}
```

- response value у тому самому `SaveWifiSettings` characteristic:

```json
{
  "success": true,
  "data": {
    "restartScheduled": true
  },
  "error": null
}
```

Окремих characteristics для SSID/password/apply немає: додаток записує один JSON object у `SaveWifiSettings`, після чого читає result із цього ж characteristic або використовує write result, якщо BLE-бібліотека повертає оновлене value.

### 2. Wi-Fi provisioning models

Створити доменні моделі для Wi-Fi onboarding.

Мінімально потрібні:

- `WifiCredentials`:
  - `ssid`;
  - `password`;
  - validation errors.

`WifiCredentials` використовується і для прочитаних із контролера Wi-Fi settings, і для введення користувача. Після читання `WifiSettings` із BLE у `ssid` підставляється `data.wifiSettings.ssid`, а `password` має бути порожнім рядком незалежно від того, що firmware повернув у `data.wifiSettings.password`.

- `SaveWifiSettingsResponse`:
  - `restartScheduled` boolean із `data.restartScheduled`.
- `WifiProvisioningError`:
  - user-facing message;
  - technical reason/code для логування без credentials;
  - source operation, наприклад read current settings, validate input, save settings або reconnect BLE.

Password не повинен зберігатися в `WateringHub`, shared preferences, logs або error messages.

### 3. Read current Wi-Fi settings over BLE

Додати метод у BLE service для читання поточних Wi-Fi settings.

Поведінка:

- якщо BLE не підключений, state має перейти в reconnecting або показати потребу повторного підключення;
- прочитати `WifiSettings` characteristic `4d42b2d1-35ba-4b70-b8a2-d1cf01e904c1`;
- розпарсити envelope `success/data/error`;
- якщо `success: false`, показати `error` без додавання credentials у logs;
- якщо поточний SSID відомий, підставити його в `WifiCredentials.ssid`;
- `WifiCredentials.password` після читання з контролера має лишатися порожнім;
- password із firmware response не показувати, не зберігати в `WateringHub`, не тримати в довгоживучому state і не логувати.

Цей крок потрібен і для первинного onboarding, і для майбутнього recovery у Settings.

### 4. Validate Wi-Fi input

Перед записом у BLE потрібно виконати базову клієнтську валідацію:

- SSID не порожній;
- SSID не перевищує допустиму довжину для Wi-Fi мережі;
- password відповідає мінімальним обмеженням WPA/WPA2, якщо використовується захищена мережа;
- прибрати випадкові leading/trailing spaces, але не змінювати password без явної логіки;
- не логувати введені credentials.

Якщо підтримуються відкриті мережі, це має бути явний режим UI, а не побічний ефект порожнього password.

UI має мати дію "Використати поточну Wi-Fi мережу телефону", якщо телефон зараз підключений до Wi-Fi і платформа дозволяє отримати ці дані:

- автоматично підставити поточний SSID у поле `ssid`;
- автоматично підставити password тільки якщо ОС або обрана platform API реально повертає його після дозволу користувача;
- якщо password недоступний через обмеження Android/iOS, залишити поле password порожнім і дати користувачу ввести його вручну;
- не зберігати й не логувати SSID/password, отримані з телефону.

### 5. Write Wi-Fi settings over BLE

Реалізувати BLE-команди запису Wi-Fi settings.

Потрібно:

- записати один JSON object `{ "ssid": string, "password": string }` у `SaveWifiSettings`;
- після write прочитати value `SaveWifiSettings` або отримати його з результату write, якщо бібліотека це підтримує;
- обробити envelope `success/data/error`;
- обробити `data.restartScheduled` boolean як підтвердження, що контролер прийняв settings і запланував reboot;
- після короткої паузи або BLE disconnect перевести `WateringHubState` у `reconnectingBle`;
- показати помилку, якщо контролер відхилив settings;
- не залишати password у довгоживучому state після завершення або помилки.

Якщо BLE write потребує chunking, retry або MTU handling, ця логіка має бути всередині BLE infrastructure, а не в UI.

### 6. Reconnect BLE after scheduled reboot

Після успішного збереження Wi-Fi settings додаток має:

- не чекати окремого BLE notification/status про reboot, бо контролер його не надсилає;
- від'єднатися або коректно обробити втрату BLE-з'єднання;
- зробити коротку паузу перед reconnect attempts, щоб контролер встиг перезавантажитися;
- через визначений інтервал спробувати повторно знайти той самий `bleDeviceId`;
- повторно підключитися через BLE;
- повернути користувача до наступного кроку onboarding.

Потрібно обмежити кількість автоматичних спроб або мати зрозумілу дію "Спробувати ще раз".

### 7. UI Wi-Fi provisioning step

Додати екран або крок onboarding для Wi-Fi.

UI має:

- показувати поточний `BleConnectionState`;
- показувати поточний SSID контролера у формі, якщо він прочитаний;
- мати поля SSID і password;
- мати дію автопідстановки поточної Wi-Fi мережі телефону, якщо платформа дозволяє отримати SSID/password;
- мати явний submit;
- показувати validation errors;
- показувати progress під час save і reconnect після scheduled reboot;
- давати повернутися до BLE discovery, якщо BLE-з'єднання втрачено;
- не показувати password після успішного збереження.

## Не входить у задачу

- читання `apiAccessToken`;
- збереження controller token;
- перевірка локального HTTPS API;
- certificate pinning;
- `GET /api/settings`;
- UI налаштування controller settings;
- сканування доступних Wi-Fi мереж, якщо firmware не має окремої BLE-характеристики для цього;
- зберігання Wi-Fi password у додатку.

## Критерії готовності

Задача готова, якщо:

- після BLE pairing користувач може перейти до Wi-Fi provisioning step;
- додаток читає поточні Wi-Fi settings через BLE;
- користувач може ввести SSID/password і пройти клієнтську валідацію;
- користувач може підставити поточну Wi-Fi мережу телефону, якщо ОС дозволяє отримати SSID/password, або вручну ввести password, якщо він недоступний;
- Wi-Fi settings записуються тільки через BLE;
- відповідь `restartScheduled` запускає reconnect flow без очікування окремого BLE-повідомлення про reboot;
- після reboot додаток може повторно знайти і підключити той самий BLE device;
- після повторного BLE-підключення flow переходить до задачі 004 для читання IP/token, а не вважає onboarding завершеним;
- password не зберігається локально і не потрапляє в logs/errors;
- проєкт проходить `flutter analyze`;
- тести покривають validation і state transitions Wi-Fi provisioning flow.
