# Close all valves

Approved in conversation on 2026-10-27.

Add a full-width red outlined `Закрити всі клапани` button before the valve
list on the home dashboard. Execute immediately without confirmation. While
sending, show `Закриваємо клапани…` and a spinner; disable repeated closing.
Keep the action available independently of metrics refresh
and the locally configured valve list.

Show `Автоматичний полив може знову відкрити клапани` below the button.
On success show a snackbar: `Команду закриття всіх клапанів виконано`.
On failure show `Не вдалося закрити клапани. Перевірте з’єднання з контролером і спробуйте ще раз`.
Do not infer persistent valve state from the command response.

Use authenticated `POST /api/valves/close-all` without a request body through
the existing API client. Track command progress in HomeDashboardController.
Opening and closing are independent operations, as requested by the user.
Send each command immediately, without waiting for or blocking the other.
The hub handles conflicts between commands.

## Approaches

Chosen: visible button above the valve list, for quick access.
Alternative: app bar action saves vertical space but is less discoverable.
No automation settings, BLE flow, or live valve-state API changes are needed.
