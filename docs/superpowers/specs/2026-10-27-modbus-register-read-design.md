# Read Modbus registers

The user selected a separate service-console tab on 2026-10-27 and requested
the existing project architecture. Implement `Читання Modbus` alongside the
current write tab, using the same Material form styling and Ukrainian copy.
Make the tab bar scrollable so all four tabs remain accessible on phones.

The form contains `Адреса пристрою`, `Адреса регістра` (default 0), and
`Кількість регістрів` (default 1), followed by `Прочитати`.
Convert entered text to integers and pass the values to the hub. Per the user's
2026-10-28 review, validation belongs to the hub: do not enforce address,
quantity, value ranges, or range overflow locally. While reading, disable the
form and show a spinner. Preserve inputs after failure for retry.
Show returned device address and a table of register addresses and values.
Show concise inline Ukrainian errors. Handle transport-specific connection
exceptions only in the shared API client, not in feature controllers.

Use authenticated POST `/api/modbus/register/get` with `slaveAddress`,
`registerAddress`, and `quantity`, as documented by the firmware. Parse
`status`, `slaveAddress`, `registerAddress`, `quantity`, and `values` into a
typed immutable result. Reject failed status and JSON that cannot be decoded
into these types; trust the hub's returned numeric values and quantity/value
count. All constructor parameters in the new feature must be required,
including nullable state fields and the widget key. Reuse the shared HTTP transport, address
resolution/recovery, certificate pinning, and DiagnosticsLog. Keep transport
out of widgets and use a dedicated ChangeNotifier with immutable state,
injected through ServiceConsoleDependencies and disposed by AppController.
Like HomeDashboardController and ControllerSettingsSaveController, inject
AppStateStore directly and read current controller access from it for each
operation. Do not introduce an access-provider callback or another abstraction.

## Approaches

Chosen by the user: separate read tab; keeps the two service operations explicit.
Alternative: read/write switch inside the existing tab; saves tab-bar space.

No dependencies, automatic polling, register writes, settings changes, or
persistent operation history are required. Verify API, controller, and widget
behavior with flutter_test, then run the full suite and static analysis.
