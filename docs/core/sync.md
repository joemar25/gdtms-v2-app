<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/core/sync/sync_manager.dart
    lib/core/sync/sync_write_coordinator.dart
    lib/core/sync/delivery_bootstrap_service.dart
    lib/core/sync/workmanager_setup.dart

  Update this document whenever you change any of those files.
  Each of those files carries a header comment: "DOCS: docs/core/sync.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Core — Sync

> **Architecture hub:** [../architecture/README.md](../architecture/README.md)  
> **System map:** [../architecture/system-map.md](../architecture/system-map.md)  
> **Accuracy (Rules 1–4):** [../architecture/accuracy-and-scale.md](../architecture/accuracy-and-scale.md)

## Files

| File | Role |
|------|------|
| `lib/core/sync/sync_manager.dart` | Processes offline queue; coalesced `requestFlush` (A8) |
| `lib/core/sync/sync_write_coordinator.dart` | Shared post-write queue kick + list refresh (A2) |
| `lib/core/sync/delivery_bootstrap_service.dart` | Pull + reconcile `local_deliveries` (Rules 1–4) |
| `lib/core/sync/sync_upsert_policy.dart` | Pure P5/P1 helpers (unit-tested; used by DAO + bootstrap) |
| `lib/core/sync/workmanager_setup.dart` | Registers WorkManager (Android) / BGTaskScheduler (iOS) background tasks |

---

## `sync_manager.dart`

`SyncManagerNotifier` is a `Notifier` exposed via `syncManagerProvider`.

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

### Coalesced flush (`requestFlush`) — A8

Preferred entry point for kicking the offline queue:

```dart
await ref.read(syncManagerProvider.notifier).requestFlush(
  reason: 'submit_delivery', // diagnostic label
  awaitIdle: false,          // UI: start/join and return
);
await ref.read(syncManagerProvider.notifier).requestFlush(
  reason: 'auto_sync_full',
  awaitIdle: true,           // auto-sync / Sync screen: wait until drained
);
```

- Concurrent callers share one in-flight run.
- Extra kicks set a re-run flag so items enqueued mid-pass are not stranded.
- **Offline / API unreachable:** new flushes are skipped when
  `isOnlineProvider` is false (network down **or** API unreachable). In-flight
  passes finish; further re-runs abort if the API drops mid-loop. Queued work
  waits until online again (reconnect / login skip the 30s auto-sync debounce).
- `processQueue()` routes through `requestFlush` (same online gate).

### Write side effects (`sync_write_coordinator.dart`) — A2

After feature screens persist local work (queue insert, DAO update), use:

```dart
await ref.read(syncWriteCoordinatorProvider).completeWrite(
  reason: 'submit_delivery',
  awaitIdle: false,       // true when UI must wait for server remap
  kickQueue: true,        // skipped automatically when offline
  refreshDeliveries: true,
);
```

Do not hand-roll `processQueue()` + `deliveryRefreshProvider.increment()` pairs in new code.

### Triggering sync

- Auto: `app.dart` `_AutoSyncListener` → `requestFlush(reason: auto_sync_full, awaitIdle: true)` then bootstrap pull.
- Feature writes: `syncWriteCoordinatorProvider.completeWrite`.
- Manual: Sync screen / Sync Now overlay → `requestFlush`.
- Background: `BackgroundSyncSetup` via WorkManager / BGTaskScheduler.

---

## `delivery_bootstrap_service.dart`

Seeds / reconciles `local_deliveries` from the server for **this courier’s scope**.

- Called from auto-sync after queue flush (`app.dart` `_runFullSync`), initial sync, and related online paths.
- Pull is **aborted** if `isOnlineProvider` becomes false after the flush (API dropped mid-cycle).
- Fetches assigned deliveries (status sweeps / delta) and upserts into SQLite.
- **Does not blindly overwrite** rows with in-flight queue work — see Rules 1–4.

### Performance (P1 / P2 / P5)

| Knob | Value / behavior |
| ---- | ---------------- |
| `kSyncPerPage` | **150** (was 50) — fewer list RTTs |
| Status sweeps | **Parallel** (`Future.wait` on 4 statuses) |
| Pages within status | Page 1 serial, then concurrency **3** |
| Unchanged rows | Skip SQLite write when `data_checksum` matches (not dirty) |
| Phase-2 cleanup | Still after **all** statuses complete (Rule 4 safe) |

### Reconciliation Rules 1–4 (summary)

Full text: [../architecture/accuracy-and-scale.md](../architecture/accuracy-and-scale.md) and the header of `delivery_bootstrap_service.dart`.

1. **Priority reconcile** local pending against the server first.  
2. **Never downgrade** courier local terminal status to pending.  
3. **Server wins** on terminal status changes.  
4. **Remove** local pending items gone from all server lists after full sweep.

**Do not weaken these rules** for speed (see [../architecture/sync-performance-todo.md](../architecture/sync-performance-todo.md)).

---

## `workmanager_setup.dart`

Registers one repeating background task:

- **Android**: WorkManager periodic task, minimum 15-minute interval (OS enforced).
- **iOS**: BGTaskScheduler task registered in `AppDelegate.swift`.

Runs bootstrap-style pull when the device has network (WorkManager constraint). Foreground auto-sync remains the primary path for push-before-pull.

---

## Related

| Doc | Why |
| --- | --- |
| [../architecture/system-map.md](../architecture/system-map.md) | End-to-end diagram |
| [../architecture/accuracy-and-scale.md](../architecture/accuracy-and-scale.md) | Accuracy + scale contract |
| [../architecture/ops-runbook.md](../architecture/ops-runbook.md) | Support: never lose updates |
| [../architecture/coupling-todo.md](../architecture/coupling-todo.md) | Coupling plan status |
| [../entry-points.md](../entry-points.md) | Auto-sync triggers |
| [../core/providers.md](../core/providers.md) | Online gate + refresh |
| [../features/sync-history.md](../features/sync-history.md) | Sync UI |
