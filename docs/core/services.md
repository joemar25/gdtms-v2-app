<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/core/services/app_version_service.dart
    lib/core/services/error_log_service.dart
    lib/core/services/location_ping_service.dart
    lib/core/services/profile_service.dart
    lib/core/services/report_service.dart
    lib/core/services/review_prompt_service.dart
    lib/core/services/version_check_service.dart

  Time-enforcement services are documented separately:
    lib/core/services/time_validation_service.dart  →  docs/time-enforcement.md
    lib/core/services/platform_settings.dart        →  docs/time-enforcement.md

  Update this document whenever you change any of the files listed above.
  Each of those files carries a header comment: "DOCS: docs/core/services.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Core — Services

Singleton or stateless service classes that perform a focused task.

## Files

| File                         | Purpose                                                                   |
| ---------------------------- | ------------------------------------------------------------------------- |
| `app_version_service.dart`   | Reads app version from platform metadata once at boot                     |
| `error_log_service.dart`     | Writes to `error_logs` table; used across the app for error capture       |
| `location_ping_service.dart` | Periodically POSTs the courier's GPS coordinates to the server            |
| `profile_service.dart`       | Fetches and updates courier profile from/to the server                    |
| `report_service.dart`        | Submits bug/issue reports to the server                                   |
| `review_prompt_service.dart` | Decides when to show the in-app review prompt                             |
| `update_service.dart`        | Handles APK downloads, checksums, and version manifest fetching           |
| `version_check_service.dart` | Compares app version to server's minimum supported version (legacy/store) |

---

## `app_version_service.dart`

- `init()` called once in `main.dart`.
- Stores the version string in a static field — no repeated platform calls.
- Consumed by `DeviceInfoService` and bug-report payloads.

---

## `error_log_service.dart`

Thin wrapper around `ErrorLogDao.insert()`.

```dart
ErrorLogService.log(tag: 'SyncManager', message: 'Upload failed', error: e);
```

Call this wherever a catch block needs to record something reviewable in the error-log screen. Do not call `ErrorLogDao` directly from features.

---

## `location_ping_service.dart`

- Started by `app.dart` after authentication.
- Pings `PUT /couriers/{id}/location` with `{ lat, lng, accuracy }` on a fixed interval.
- Stops automatically when the user logs out or the app goes to background.
- Uses `Geolocator` stream — does **not** re-request permission; assumes `locationProvider` is `granted`.

---

## `profile_service.dart`

- `getProfile()` — GET `/couriers/{id}/profile`.
- `updateProfile(payload)` — PATCH `/couriers/{id}/profile`.
- Used by `ProfileScreen` and `ProfileEditScreen`.

---

## `report_service.dart`

- `submit(BugReportPayload)` — POST to the report endpoint.
- Called from `ReportIssueScreen`.

---

## `review_prompt_service.dart`

- Tracks successful delivery count in `SharedPreferences`.
- Triggers `in_app_review` after a threshold (e.g. every 10 successful deliveries).
- Does nothing if the platform does not support in-app review.

---

## `update_service.dart`

The core engine for the [Update System](file:///docs/core/update-system.md).

- `checkForUpdate()`: Fetches `mobile-version.json` and parses into `UpdateInfo`.
- `downloadUpdate(url, onProgress)`: Downloads APK to a temporary directory with progress tracking.
- `verifyChecksum(path, sha256)`: Ensures file integrity before installation.
- `installUpdate(path)`: Triggers `open_filex` (Android) or opens App Store (iOS).

---

## `version_check_service.dart`

- `check()` — GET `/app/version`.
- Compares server `min_version` with `AppVersionService.version`.
- If behind: shows a non-dismissible update banner on dashboard.
- **Note**: This is largely superseded by the newer `UpdateService` which supports direct APK sideloading.
