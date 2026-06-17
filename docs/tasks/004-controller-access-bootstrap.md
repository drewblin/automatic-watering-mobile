# Задача 004: Controller access bootstrap

## Мета

Завершити onboarding до стану, коли мобільний додаток має збережений `bleDeviceId`, останню відому IP-адресу контролера, controller `apiAccessToken` у захищеному сховищі та може виконати базову перевірку локального HTTPS API.

Ця задача з'єднує BLE onboarding із майбутнім HTTPS-клієнтом. Після її завершення додаток ще не синхронізує повні settings, але вже має перевірений шлях доступу до контролера.

## Контекст із ТЗ

Локальний HTTPS API використовується для основного керування контролером у локальній мережі:

- читання та збереження settings;
- отримання останніх значень сенсорів;
- ручний запуск клапана на заданий час;
- зміна Modbus slave address пристрою.

Кожен запит до контролера має використовувати bearer token, отриманий через BLE. Додаток має зберігати цей token у захищеному сховищі.

Якщо IP дорівнює `0.0.0.0`, додаток має показувати стан очікування і давати можливість повернутися до Wi-Fi settings.

BLE read results повертаються як UTF-8 JSON strings у єдиному envelope:

```json
{
  "success": true,
  "data": {},
  "error": null
}
```

HTTPS API контролера має базовий URL `https://<controller-ip>` на порту `443`. Кожен HTTPS-запит має містити `Authorization: Bearer <apiAccessToken>`, а запити з body також `Content-Type: application/json`.

## Обсяг задачі

### 1. Secure token storage

Підключити або завершити реалізацію `TokenStorage` для controller `apiAccessToken`.

Потрібно:

- зберігати token у захищеному сховищі мобільної ОС;
- не зберігати token у shared preferences;
- не показувати token у UI;
- не логувати token;
- мати методи read/write/delete token за `wateringHubId`;
- залишити можливість окремо зберігати mobile session token у майбутньому, не змішуючи його з controller token.

Якщо використовується dependency для secure storage, додати її в `pubspec.yaml` і налаштувати платформи за потреби.

### 2. BLE bootstrap characteristics

Розширити BLE service методами для читання:

- `WifiIpAddress`:
  - UUID `4d42b2d3-35ba-4b70-b8a2-d1cf01e904c1`;
  - properties `READ`, encrypted, authenticated;
  - response:

```json
{
  "success": true,
  "data": {
    "ipAddress": "192.168.1.42"
  },
  "error": null
}
```

- `ApiAccessToken`:
  - UUID `4d42b2d4-35ba-4b70-b8a2-d1cf01e904c1`;
  - properties `READ`, encrypted, authenticated;
  - response:

```json
{
  "success": true,
  "data": {
    "apiAccessToken": "64-hex-character-token"
  },
  "error": null
}
```

Parsing цих значень має бути ізольований від UI. `ipAddress` має тип string; `0.0.0.0` означає, що Wi-Fi ще не підключений. `apiAccessToken` має бути string і зберігатися як секрет; якщо token порожній або має неправильний формат, state має перейти в помилку або `tokenInvalid`.

### 3. Save controller access data

Після успішного читання IP/token потрібно:

- оновити активний `WateringHub.lastKnownIpAddress`;
- зберегти token через `TokenStorage`;
- оновити `updatedAt`;
- не дублювати token у plain local storage;
- перевести `WateringHubState` у `checkingLocalHttps` перед перевіркою HTTPS або `online` після успішної перевірки.

Якщо IP дорівнює `0.0.0.0`, token можна зберегти тільки якщо він валідний, але onboarding не має вважатися завершеним. UI має запропонувати чекати або повернутися до Wi-Fi provisioning.

### 4. HTTPS client foundation

Створити базовий local controller API client.

Мінімально потрібні:

- base URL з `https://<lastKnownIpAddress>`;
- bearer token auth header;
- timeout;
- базовий error mapping:
  - network unavailable;
  - TLS/certificate error;
  - unauthorized або `tokenInvalid`;
  - controller unavailable;
  - unexpected response;
- заборона логування token і повних auth headers.

Certificate pinning або перевірка SHA-256 fingerprint для самопідписаного endpoint є вимогою ТЗ. TLS/fingerprint перевірка має бути ізольована в HTTPS client, а не розмазана по UI або use cases.

Fingerprint самопідписаного HTTPS certificate:

```text
DE:B7:7B:DC:88:1B:09:EE:23:19:8D:72:06:FA:E6:AD:F9:E4:8A:F1:5B:1D:EE:BB:4F:58:7F:0E:2F:42:B3:AC
```

Поточні HTTP status codes API:

- `200 OK` - успішна операція;
- `400 Bad Request` - невалідний JSON або поля;
- `401 Unauthorized` - неправильний або відсутній `Authorization`;
- `404 Not Found` - ресурс не знайдено;
- `413 Content Too Large` - тіло запиту більше за 16 KiB;
- `500 Internal Server Error` - помилка збереження або внутрішня помилка;
- `503 Service Unavailable` - water hub недоступний.

### 5. Bootstrap connectivity check

Реалізувати легку перевірку локального HTTPS доступу.

Потрібно використати найменш інвазивний endpoint, який підтверджує:

- контролер доступний за IP;
- TLS/fingerprint перевірка пройдена або коректно оброблена;
- bearer token прийнятий;
- відповідь належить очікуваному контролеру.

Спеціального health endpoint немає. Для bootstrap check потрібно використати `GET /api/settings`, але parsing повного settings snapshot і побудова device objects мають залишатися в задачі 005.

Формат bootstrap `GET /api/settings`:

```http
GET /api/settings
Authorization: Bearer <apiAccessToken>
```

Очікувана форма відповіді:

```json
{
  "success": true,
  "data": {
    "settings": {},
    "controllerCurrentTimestamp": 1717245600,
    "controllerCurrentTime": "2024-06-01T12:00:00+0300"
  },
  "error": null
}
```

У задачі 004 достатньо перевірити envelope, `success`, auth/TLS/network status і наявність `data.settings`. Повний typed parsing settings виконується в задачі 005.

### 6. State transitions для recovery

Оновити app/onboarding state, щоб він використовував затверджені `WateringHubState` values:

- `ipPending`;
- `checkingLocalHttps`;
- `online`;
- `httpsUnavailable`;
- `tokenInvalid`;
- `requiresBleRecovery`;
- `reconnectingBle`.

Якщо локальний HTTPS повертає `401`, додаток має показати стан, який у майбутньому запустить повторне читання token через BLE.

### 7. UI bootstrap step

Додати завершальний крок onboarding.

UI має:

- показати IP, отриманий через BLE;
- показати стан читання token без самого token;
- показати прогрес перевірки HTTPS;
- показати зрозумілу помилку для IP `0.0.0.0`, timeout, TLS/fingerprint error і `401`;
- дати повторити BLE-read IP/token;
- дати повернутися до Wi-Fi provisioning;
- після успіху перейти до синхронізації settings або головного стану "потрібне базове налаштування".

Усі видимі користувачу тексти bootstrap step мають бути українською мовою: стани, кнопки, пояснення, помилки IP `0.0.0.0`, timeout, TLS/fingerprint error і `401`. Технічні значення token, HTTP status codes, API paths і fingerprint не перекладаються.

## Не входить у задачу

- повний parsing `GET /api/settings`;
- побудова `DeviceObject` із settings;
- UI settings;
- editor схеми;
- manual valve control;
- sensors metrics;
- server API;
- cloud mobile session token;
- live BLE logs.

## Критерії готовності

Задача готова, якщо:

- controller `apiAccessToken` читається через BLE;
- IP-адреса контролера читається через BLE і валідовується;
- token зберігається через secure `TokenStorage`, а не в plain storage;
- `WateringHub.lastKnownIpAddress` оновлюється після успішного BLE bootstrap;
- створений local HTTPS client із bearer auth, timeout і error mapping;
- bootstrap check підтверджує локальний HTTPS доступ або показує точну причину невдачі;
- IP `0.0.0.0` не вважається успішним доступом;
- `401` переводить state у `tokenInvalid` або `requiresBleRecovery`;
- token/auth headers не логуються і не показуються в UI;
- bootstrap UI не містить англомовних user-facing текстів;
- проєкт проходить `flutter analyze`;
- тести покривають token storage contract, IP validation і state transitions bootstrap flow.
