# Close All Valves Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Immediately stop current watering from the home dashboard.

**Architecture:** Extend the existing HTTPS API client and dashboard controller.
Keep close-all progress separate from individual opening progress.
Opening and closing run independently; the hub handles conflicts.

**Tech Stack:** Flutter, Dart, flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-27-close-all-valves-design.md`

## Global Constraints

- POST `/api/valves/close-all` with bearer authorization and no body.
- Use the Ukrainian copy in the spec; no confirmation dialog or persistent valve status.
- No new dependencies, automation changes, or metrics prerequisites.

## Review Focus

- Duplicate taps must produce only one request.
- Opening and closing must each execute while the other request is pending.
- Failed requests must restore controls and allow retry.
- Cached empty valve configuration or failed refresh must not hide the action.
- Narrow phone layouts must fit the full-width button and its progress label.

### Task 1: API and dashboard behavior

**Files:** API client, home dashboard controller, API/controller tests, existing API test doubles.

**Interfaces:** `LocalControllerApiClient.closeAllValves({required String ipAddress, required String apiAccessToken}) -> Future<void>`;
`HomeDashboardController.closeAllValves() -> Future<bool>`,
`closeAllValvesState -> ManualValveCommandState`, `isClosingAllValves -> bool`.

- [x] Add API contract tests and controller tests for success, failure/retry, duplicates, and in-flight openings; watch them fail.
- [x] Implement the API and controller interfaces; update existing API test doubles.
- [x] Verify API and controller behavior; both are included in the passing full suite.

### Task 2: Dashboard action

**Files:** home_dashboard.dart, home_device_cards.dart, new home_dashboard_test.dart.

**Interfaces:** Consume Task 1 command state; keep ValveCard opening independent.

- [x] Add widget tests for immediate execution, progress/disabled controls, success, retry after error, empty configuration and narrow layout; watch them fail.
- [x] Add the red outlined button, explanatory text, and snackbar feedback.
- [x] Run targeted widget tests, then `flutter test`, `flutter analyze`, and `git diff --check`; all 100 suite tests passed, analysis and whitespace checks passed. Formatting check reported zero changes.
- [x] Review the final diff against the spec and record results here.

## Review

Initial independent read-only review found no concrete correctness issues.
The user's follow-up simplified the design: removed opening serialization
and lockout. Updated controller and widget tests verify both directions of
independent execution. All 11 targeted controller/widget tests passed, followed
by the full 100-test suite, static analysis, formatting and whitespace checks.
Changes remain uncommitted in the user's current checkout. Physical-controller
operation was not exercised in this workspace.
