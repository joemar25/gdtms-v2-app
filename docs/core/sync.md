<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/core/sync/sync_manager.dart
    lib/core/sync/delivery_bootstrap_service.dart
    lib/core/sync/workmanager_setup.dart

  Update this document whenever you change any of those files.
  Each of those files carries a header comment: "DOCS: docs/core/sync.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Core — Sync

## Files

| File | Role |
|------|------|
| `lib/core/sync/sync_manager.dart` | Processes `delivery_update_queue`; uploads media + PATCHes server |
| `lib/core/sync/delivery_bootstrap_service.dart` | Seeds `local_deliveries` from the server on first online |
| `lib/core/sync/workmanager_setup.dart` | Registers WorkManager (Android) / BGTaskScheduler (iOS) background tasks |

---

## `sync_manager.dart`

`SyncManagerNotifier` is a `StateNotifier` exposed via `syncManagerProvider`.

### Sync flow (per queued item)

1. Read next `pending` row from `delivery_update_queue`.
2. Mark row as `processing` in `sync_operations`.
3. Upload any `_pending_media` images (base64 → multipart or S3 PUT).
4. **Guard**: if **all** media uploads fail, do not mark the sync as success — leave as `failed`.
5. PATCH `/deliveries/{barcode}` with the update payload + uploaded media URLs.
6. On HTTP 2xx: mark `sync_operations` row as `synced`, update `local_deliveries.status`.
7. On failure: mark as `failed`, store error message.

### Key rule

Never mark a delivery sync as complete when all media uploads failed. The guard is in `sync_manager.dart` — do not remove it.

### Triggering sync

- Auto: `app.dart` timer fires every 3 minutes when online.
- Manual: "SYNC" button on `SyncScreen` (history screen).
- Background: `BackgroundSyncSetup` via WorkManager / BGTaskScheduler.

---

## `delivery_bootstrap_service.dart`

Seeds `local_deliveries` table from the server.

- Called by `app.dart` on the first `false → true` connectivity transition per session.
- Also called by `SplashScreen` when the user is authenticated and online.
- Fetches the courier's assigned deliveries from the server and upserts them into SQLite.
- **Does not overwrite** records that have active `sync_operations` rows — those are in-flight.

---

## `workmanager_setup.dart`

Registers one repeating background task:

- **Android**: WorkManager periodic task, minimum 15-minute interval (OS enforced).
- **iOS**: BGTaskScheduler task registered in `AppDelegate.swift`.

The task calls `SyncManagerNotifier.runSync()` in an isolate. It does **not** show a notification unless there are failures.

> The background task fires only when the device has network connectivity (WorkManager constraint).
