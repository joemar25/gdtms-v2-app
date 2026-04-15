<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/core/services/time_validation_service.dart
    lib/core/services/platform_settings.dart
    lib/shared/widgets/time_enforcer.dart

  Update this document whenever you change any of those files.
  Each of those files carries a header comment: "DOCS: docs/time-enforcement.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Time enforcement: Philippine Standard Time (PHT / UTC+8)

## Overview

The mobile app MUST run using Philippine Standard Time (UTC+8 / Asia/Manila). To guarantee data integrity (timestamps, delivery cutoffs, reconciliation) the app strictly validates device time and timezone at startup and on every relevant trigger.

---

## Trigger points

| Event                                        | Action                                              |
| -------------------------------------------- | --------------------------------------------------- |
| App startup (first frame)                    | Full HTTP time + timezone check                     |
| App resume from background                   | Full HTTP time + timezone check                     |
| Connectivity restored (offline → online)     | Full HTTP time + timezone check                     |
| Periodic timer (every 5 minutes, foreground) | Full HTTP time + timezone check                     |
| User taps Retry                              | Cache invalidated, fresh HTTP time + timezone check |

---

## Validation logic

1. **Timezone check** — always performed, even offline. Device UTC offset must equal `+08:00`. Any other offset immediately blocks the app.
2. **HTTP clock-skew check** — only when the device is **online**. A HEAD request is made to `https://clients3.google.com/generate_204`; the RFC 7231 `Date` response header is parsed to get the trusted server UTC time. Default max skew: **30 seconds**. Configurable via `allowedSkew`.

### Why HTTP instead of NTP

The `ntp` package was replaced with an HTTP-based check for reliability reasons. The `ntp` package threw `NoSuchMethodError: No static method 'now' declared in class 'null'` on certain devices/builds, causing the app to incorrectly block all users via the "fail closed" error path.

The replacement uses `Dio` (already a project dependency) + `http_parser.parseHttpDate()` to read the `Date` header from Google's zero-byte connectivity endpoint. This endpoint is:

- Used by Android itself for network detection — always reachable when the device is online
- Zero-content response (204 No Content) — minimal overhead
- Returns a `Date` header in RFC 7231 format that `http_parser.parseHttpDate()` can parse directly

### Offline-safe behaviour

When the device has no network connection, the HTTP check is **skipped** and only the timezone is validated. This prevents blocking couriers during short connectivity gaps while still catching deliberate timezone spoofing. The full check resumes automatically when connectivity is restored.

### Network error handling

`DioException` errors are split into two categories:

| Error type                                                                                    | Behaviour                        | Reason                                                                                                                                          |
| --------------------------------------------------------------------------------------------- | -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| TLS / handshake failure (`badCertificate`, `HandshakeException`, `CERTIFICATE_VERIFY_FAILED`) | **Fail closed** — block the user | Wrong device time is the most common cause of TLS failures. The OS rejects certificates whose validity period doesn't overlap the device clock. |
| Genuine connectivity failure (timeout, no route, DNS error)                                   | **Fail open** — allow the user   | The device is simply offline or can't reach Google. Timezone already confirmed as PST.                                                          |

This means an attacker cannot bypass enforcement by blocking network access — the TLS failure itself becomes the signal that something is wrong.

---

## Result cache

A successful validation is cached for **15 minutes** so the app is never stalled by network latency on every resume. The cache is automatically invalidated when the user taps **Retry**.

---

## UI states

| State                   | What the user sees                                                                                   |
| ----------------------- | ---------------------------------------------------------------------------------------------------- |
| First check in progress | Branded loading screen with spinner ("Verifying device time…")                                       |
| Valid                   | Normal app                                                                                           |
| Invalid                 | Full-screen blocking overlay with orange icon, error detail, **Open Settings** and **Retry** buttons |
| Retry in progress       | Retry button shows inline spinner                                                                    |

---

## Blocking screen — user guidance

The blocking card shows the exact failure reason and two actions:

- **Open Settings** — on Android, calls `openDateTimeSettings` on the `fsi_courier/storage` `MethodChannel`. The Kotlin side launches `Settings.ACTION_DATE_SETTINGS` with `FLAG_ACTIVITY_NEW_TASK`; falls back to `Settings.ACTION_SETTINGS` if the manufacturer restricts the direct intent. On iOS, opens app settings (iOS does not allow deep-linking to Date & Time).
- **Retry** — invalidates the cache and runs a fresh validation.

Hint text: _"Enable 'Automatic date & time' and set timezone to Asia/Manila."_

---

## Implementation files

| File                                             | Purpose                                                                |
| ------------------------------------------------ | ---------------------------------------------------------------------- |
| `lib/core/services/time_validation_service.dart` | HTTP + timezone check, result cache, Sentry reporting                  |
| `lib/shared/widgets/time_enforcer.dart`          | Loading/blocking UI, periodic timer, connectivity listener             |
| `lib/core/services/platform_settings.dart`       | Platform-specific Date & Time settings deep link                       |
| `lib/app.dart`                                   | Integration point — root `builder` wraps all screens in `TimeEnforcer` |

---

## Sentry / audit trail

On every validation failure, `TimeValidationService` adds a Sentry `Breadcrumb` (category: `time_enforcement`, level: `warning`) containing:

- `reason` — human-readable failure message
- `skew_seconds` — measured clock skew in seconds (0 if timezone-only failure)
- `device_offset` — formatted UTC offset string (e.g. `+09:00`)

Breadcrumbs are only submitted in **release mode** to avoid noise during development.

---

## Configuration and tuning

| Parameter                  | Default                                    | Constant / location                                                                    |
| -------------------------- | ------------------------------------------ | -------------------------------------------------------------------------------------- |
| Allowed clock skew         | 30 s                                       | `TimeEnforcer(allowedSkew: ...)` or `TimeValidationService.validate(allowedSkew: ...)` |
| HTTP timeout               | 5 s                                        | `_kHttpTimeout` in `time_validation_service.dart`                                      |
| Time check URL             | `https://clients3.google.com/generate_204` | `_kTimeCheckUrl` in `time_validation_service.dart`                                     |
| Cache TTL                  | 15 min                                     | `_kCacheTtl` in `time_validation_service.dart`                                         |
| Periodic re-check interval | 5 min                                      | `_kPeriodicInterval` in `time_enforcer.dart`                                           |

---

## Security and privacy

- Only the RFC 7231 `Date` header is read from the response. No user data is transmitted to Google.
- Apps cannot programmatically change system date/time without privileged device access; the app asks the user to fix their settings instead.
- Network-level failures (fail open) are safe: a real attacker manipulating their clock remains online and will be caught when the HTTP check succeeds and returns the wrong skew.

---

## Future improvements

- Add a backend `/time` endpoint fallback so the time source is entirely within the FSI infrastructure (no Google dependency).
- Consider using `flutter_timezone` to read the IANA timezone ID directly (more precise than checking the raw UTC offset, which has edge cases for other UTC+8 zones).
