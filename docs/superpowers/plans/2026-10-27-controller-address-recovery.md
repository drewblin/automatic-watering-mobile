# Controller Address Recovery Implementation Plan

> **For agentic workers:** Execute inline with superpowers:executing-plans and test-driven-development.

**Goal:** Keep IP only in a runtime cache and recover any HTTP operation once after a network failure.
**Architecture:** Required ControllerAddressService resolves and caches by hostname. API methods take hostname and retry centrally. Startup uses the normal API path.
**Tech Stack:** Dart, Flutter, existing mDNS resolver. No new dependencies.
**Spec:** docs/superpowers/specs/2026-10-27-controller-address-recovery-design.md

## Global Constraints

No IP on WateringHub or ReadyWateringHubAccess. No optional production service dependencies. No coordination of parallel searches. Retry any method once, retaining body and authorization. No recovery after HTTP/TLS/parsing failures.

## Review Focus

- POST/PUT preserve method, payload and token on the second attempt.
- One retry only, including when mDNS returns the same IP.
- Initial or refreshed mDNS failure must not send to a hostname as if it were a resolved IP.
- Old persisted hub JSON remains readable and no IP is written by recovery.
- Startup and onboarding use hostname access without optional dependency fallbacks.

### Task 1: Runtime address cache and hostname access

**Files:** controller_address_service.dart, watering_hub.dart, API interface/callers and test doubles.
**Interfaces:** ControllerAddressService.resolve({required String hostname, bool refresh = false}) returns Future<String?>. LocalControllerApiClient methods accept required hostname and apiAccessToken.

- [x] Rewrite regression tests for runtime caching, hostname access, legacy JSON and retry behavior; observe old interfaces fail.
- [x] Remove hub IP field/serialization, move cached addresses into a small resolver-only service, migrate API interfaces and fixtures.
- [x] With request retry absent, observe nine behavior tests fail; implement centralized retry and confirm focused tests pass.

### Task 2: Startup integration and verification

**Files:** app_startup_service.dart, main.dart, onboarding bootstrap, startup and onboarding tests.

- [x] Remove startup's independent address lookup and optional dependency creation.
- [x] Remove IP writes during BLE onboarding; retain transient UI address data.
- [x] Verify startup uses the real HTTP resolution path and leaves persisted hub unchanged.
- [x] Run flutter test, flutter analyze and git diff --check after final edits.
- [x] Perform independent review of simplified implementation and address material findings.

Execution stays in the supplied checkout, uncommitted. Final verification: 119 tests passed; flutter analyze reported no issues; git diff --check passed. Independent review found no material issues. No physical-controller DHCP test was performed.
