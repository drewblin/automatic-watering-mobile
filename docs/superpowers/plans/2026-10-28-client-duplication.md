# Client duplication cleanup implementation plan

**Goal:** Implement review items 1–3, with independent HTTP and BLE parsing and matching envelope semantics.

**Spec:** User instructions in this conversation: keep HTTP and BLE independent; extract shared Modbus validation and address fields; reduce HTTP response-handler duplication; leave remaining review items untouched.

**Architecture:** Keep parsing inside each transport. Check envelope success before parsing data. Share only service-console Modbus form components and numeric validation. Keep read/write controllers and result models separate. Consolidate HTTP body reading and envelope handling behind a private response-parser factory.

**Tech stack:** Dart, Flutter, existing flutter_test infrastructure; no new dependencies.

## Constraints and review focus

- Preserve transport-specific exceptions, diagnostics, timeouts, pinning, and address recovery.
- Reject failed envelopes before parsing absent or malformed data; ignore unused error fields on successful envelopes.
- Preserve Modbus address ranges 0–255 and 0–65535, read quantity 1–64, and existing input behavior and messages.
- Ignore completion and submission after controller disposal, including failed requests.
- Keep controller subscriptions correct when a tab receives a replacement controller.
- No changes to onboarding UI, date formatting, settings models, or unrelated test utilities.

## Task 1: Independent envelope behavior

- [x] Add BLE rejection tests for all envelope operations, including absent data and fallback messages; assert controller errors survive parsing.
- [x] Run tests and confirm the existing data-first parsing fails those assertions.
- [x] Replace BLE's shared ApiEnvelope dependency with local decoding and success-first parsing.
- [x] Run BLE tests and existing HTTP envelope tests.

## Task 2: Modbus extraction and disposal safety

- [x] Add write-controller regression tests for late success/failure and submission after disposal; observe failures.
- [x] Extract numeric validation into service-console/modbus_register_validation.dart and use it in both controllers.
- [x] Guard the write controller before submission, after await, and before notification.
- [x] Extract address fields and numeric field rendering into service-console/modbus_register_fields.dart, preserving input policies.
- [x] Use ListenableBuilder in read/write tabs to manage controller subscriptions.
- [x] Run controller and service-console widget tests, preserving defaults, validation, pending-state blocking, and result rendering.

## Task 3: HTTP response handling

- [x] Run existing API and address-recovery tests as the behavior baseline.
- [x] Add a private _responseParser<T> factory to centralize body reading and envelope invocation; keep endpoint-specific data parsers and labels explicit.
- [x] Run API and address-recovery tests, then flutter analyze and the complete flutter test suite.
- [x] Review the final diff against scope and record verification.

## Execution notes

- Execute in the user's current workspace; leave changes available for review without commits or publishing.
- Existing baseline from the preceding review: flutter analyze clean; 194 tests passing; working tree clean at implementation start.

## Verification

- Red regression run: 19 expected failures (16 BLE envelope cases and 3 write-controller disposal cases).
- Green behavior run: 81 targeted tests passed.
- Refactor verification: 133 targeted tests passed, including HTTP and address recovery.
- Final verification after adding controller replacement coverage: 215 tests passed; flutter analyze reported no issues; git diff --check passed.
- Independent read-only review: no actionable findings.
