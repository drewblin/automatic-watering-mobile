# Controller contract fixes

Scope: user-requested audit items 1, 4, 7 and request-only Modbus read
validation. Other audit findings and Modbus response handling are unchanged.

## Tasks

1. [x] Preserve and edit `globalSettings.modbusWarmupMs`.
   - Add regression tests for snapshot/form round trips and rejection when
     required `modbusWarmupMs` is absent. Require it in the model constructor
     and JSON parser; all controller settings are assumed to include it.
   - Add the model field, JSON mapping, form draft, and Ukrainian number field.
   - Validate integer input in 0..60000 ms and test both boundaries.
2. [x] Propagate Wi-Fi save failures.
   - Test the real BLE service with a fake BLE transport: controller rejection,
     malformed response, read failure, write failure, and confirmed success.
   - Remove the optimistic restart fallback; require the actual response.
3. [x] Require a confirmed restart after PUT settings.
   - Test the HTTP client plus save controller with false/missing/malformed
     restart data: report save failure without entering reboot/reconnect.
   - Parse `restartScheduled: true` specifically for PUT settings; preserve
     empty responses used by valve commands and the existing public interface.
4. [x] Validate outgoing Modbus read requests.
   - Replace tests that forward invalid input with rejection tests, including
     nonnumeric input and exact valid boundaries; update the form test.
   - Validate slaveAddress 0..255, registerAddress 0..65535, quantity 1..64.
   - Do not add range, count, or request/response consistency checks to results.

For each task, run regression tests before implementation (expected failure),
then after implementation (expected success). Final verification:
`dart format` on modified Dart files, `flutter analyze`, `flutter test`,
and `git diff --check`. Review the final diff for unrelated behavior changes.

## Verification

- Regression tests reproduced the missing warmup field, swallowed BLE errors,
  unconfirmed reboot flow, and invalid outgoing Modbus read requests before
  the respective fixes. Targeted tests pass after each fix.
- `flutter test --reporter expanded`: 193 tests passed.
- `flutter analyze`: no issues found.
- `dart format` applied to changed Dart files; `git diff --check` passed.
