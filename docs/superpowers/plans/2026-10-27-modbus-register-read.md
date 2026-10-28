# Modbus Register Read Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Read arbitrary holding registers from a separate service-console tab.

**Architecture:** Extend LocalControllerApiClient with typed read request/result
models. Inject a dedicated ChangeNotifier into the existing service console.
Widgets retain only form inputs and render controller state, like the write tab.
Inject AppStateStore directly, following the dashboard and settings controllers;
look up active controller access before every request.

**Tech Stack:** Dart, Flutter Material, flutter_test; no new dependencies.

**Spec:** `docs/superpowers/specs/2026-10-27-modbus-register-read-design.md`

## Global Constraints

- POST `/api/modbus/register/get` using existing authentication and transport.
- Ukrainian UI; quantity defaults to 1; existing write form preserved.
- Delegate numeric validation to the hub; new constructors have only required arguments.
- Connection-specific exceptions are handled in the shared API client only.
- Use existing feature folders, dependency injection, immutable state and diagnostics.
- Work in the current checkout; leave changes uncommitted, as in preceding tasks.

## Review Focus

- Nonzero status or malformed payload must never display a successful result.
- Repeated submission must not issue concurrent read requests.
- Numeric values, including out-of-range inputs, must reach the hub unchanged.
- Failure must restore form controls and permit retry without losing input.
- Four tabs and multi-register results must fit a narrow phone screen.

### Task 1: Typed HTTP read operation

**Files:** local_controller/modbus_register_read_models.dart,
local_controller/local_controller_api_client.dart, test/local_controller_api_client_test.dart,
existing LocalControllerApiClient test doubles.

**Interfaces:** `readModbusRegisters({required String hostname, required String apiAccessToken,
required ModbusRegisterReadRequest request}) -> Future<ModbusRegisterReadResult>`.
Request: slaveAddress, registerAddress, quantity. Result adds status and immutable values.

- [x] Add failing tests for authenticated body, returned values, malformed and failed results.
- [x] Implement models and read operation through `_send`; extend test doubles.
- [x] Run API tests; included in the passing targeted suite.

### Task 2: Read controller and form

**Files:** service_console/modbus_register_read/modbus_register_read_controller.dart,
modbus_register_read_tab.dart, service_console_dependencies.dart, service_console_tabs.dart,
service_console_screen.dart, main.dart, app_controller.dart, test/app_test_composition.dart,
test/modbus_register_read_controller_test.dart, test/service_console_screen_test.dart.

**Interfaces:** `ModbusRegisterReadController.submit({required String slaveAddressText,
required String registerAddressText, required String quantityText}) -> Future<bool>`;
state with status, message, result, and isSubmitting.

- [x] Add failing controller tests for numeric passthrough, duplicates, success, failure/retry, and disposal.
- [x] Implement read controller with fresh active hub access per submission.
- [x] Add failing widget tests for separate tab, defaults, loading, numeric passthrough, results and retry.
- [x] Implement styled form, scrollable tab bar, composition and disposal.
- [x] Run targeted tests, full `flutter test`, `flutter analyze`, formatting and `git diff --check`.
- [x] Review final changes against the spec and record verification below.

## Verification and review

- Baseline: 129 tests passed before implementation.
- New API and controller tests first failed because the feature interfaces were missing.
- The new tab test first failed because the tab was absent.
- Initial implementation: all 32 API tests and all 22 read-controller tests passed.
- Narrow-phone result assertions initially also matched the register input;
  restricting the address assertion to the result table fixed the test selector.
- Initial implementation: 173 tests passed; `flutter analyze`: no issues.
- Formatting check: 19 Dart files, zero changes. `git diff --check` passed.
- Independent read-only code review found no actionable correctness issues and
  confirmed consistency with the existing write feature and dependency lifecycle.
- Live firmware and physical-device rendering were not exercised. Automated
  widget coverage includes a 320-pixel phone layout, loading, numeric passthrough, results,
  retry, missing controller access, and continued access to the write tab.
- Changes remain uncommitted in the current checkout.

## User review corrections — 2026-10-28

- Removed local numeric and response range validation; retained integer parsing
  and typed JSON deserialization. Tests now verify numeric passthrough.
- Removed validation-only state, messages and input filtering from the read form.
- Made nullable state fields and the public read widget key required arguments.
- Removed feature-level connection exception handling; all read failures use the
  same operation error. Connection recovery remains in the shared API client.
- Updated tests first; the old implementation failed the new passthrough and
  uniform-error expectations. After implementation, all 65 targeted tests passed.
- Final verification after corrections: all 160 tests passed; `flutter analyze`
  found no issues; formatting check reported zero changes in 7 Dart files;
  `git diff --check` passed. Follow-up independent review found no actionable
  correctness issues or unmet user requirements.

## Align dependency injection with existing controllers — 2026-10-28

- Compared the read controller with dashboard, settings save, Modbus write,
  BLE logs, onboarding, and app controllers. Dashboard and settings save use
  direct AppStateStore injection for current controller access.
- Replaced the read controller's callback dependency with required AppStateStore
  and LocalControllerApiClient dependencies, matching that existing pattern.
- Read access from app state on each submission; preserve nullable access for
  service-console use before onboarding. No new provider type or abstraction.
- Updated production and test composition. Added a test that changes hostname
  and token between reads and verifies the next request uses updated access.
- All 40 targeted tests and all 161 full-suite tests passed. Static analysis
  found no issues; formatting check reported zero changes in 5 Dart files;
  `git diff --check` passed. Focused independent review found no issues.
