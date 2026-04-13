<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/core/database/app_database.dart
    lib/core/database/cleanup_service.dart
    lib/core/database/error_log_dao.dart
    lib/core/database/local_delivery_dao.dart
    lib/core/database/sync_operations_dao.dart

  Update this document whenever you change any of those files.
  Each of those files carries a header comment: "DOCS: docs/core/database.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Core — Database

SQLite is the source of truth. Network is secondary.

## Files

| File | Role |
|------|------|
| `lib/core/database/app_database.dart` | Singleton SQLite instance, schema, migrations |
| `lib/core/database/cleanup_service.dart` | Periodic old-record pruning |
| `lib/core/database/error_log_dao.dart` | DAO for `error_logs` table |
| `lib/core/database/local_delivery_dao.dart` | DAO for `local_deliveries` table |
| `lib/core/database/sync_operations_dao.dart` | DAO for `sync_operations` table |

---

## `app_database.dart`

- Opened once in `main.dart` via `AppDatabase.getInstance()`.
- Singleton — call `AppDatabase.getInstance()` anywhere; it returns the same instance.
- **Schema migrations**: increment `_kDbVersion` and add a migration block when you alter any table. Never drop columns without a migration.

### Tables

| Table | Purpose |
|-------|---------|
| `local_deliveries` | Mirror of server delivery records, seeded by `DeliveryBootstrapService` |
| `delivery_update_queue` | Offline delivery updates waiting to sync; includes `_pending_media` (base64) |
| `sync_operations` | Tracks each sync attempt: status, error, timestamps |
| `error_logs` | App-level error events for the error-log screen |

---

## `local_delivery_dao.dart`

CRUD for `local_deliveries`.

- `getByBarcode(barcode)` → single delivery row.
- `getAll(courierId)` → full list for the courier.
- `upsert(delivery)` — insert or replace on conflict.
- `updateStatus(barcode, status)` — called after a successful sync.

---

## `sync_operations_dao.dart`

Tracks per-delivery sync state.

- `getSyncQueuedBarcodes(courierId)` → `List<String>` — barcodes with active (`pending`, `processing`, `failed`, `conflict`) rows. Used by list screens to show "PENDING SYNC" badge.
- `insert(op)`, `updateStatus(id, status, error)`.

### Sync-lock rule

A delivery with **any** active `sync_operations` row must not be re-updated. The list screen injects `_in_sync_queue: true` into those delivery maps; the detail screen disables the UPDATE FAB.

---

## `cleanup_service.dart`

Runs at most once per calendar day (tracked via `SharedPreferences`).

- Deletes `local_deliveries` older than `kLocalDataRetentionDays`.
- Deletes `sync_operations` history beyond the courier's configured retention (1, 3, or 5 days — set in Profile → Preferences).
- Deletes `error_logs` beyond a fixed window.

Do not call this manually from screens — `app.dart` triggers it on startup.

---

## `error_log_dao.dart`

Write-only from normal app code; read by `ErrorLogsScreen`.

- `insert(ErrorLog)` — called by `ErrorLogService`.
- `getAll()` → paginated list for the error-log screen.
- `deleteAll()` — user-triggered clear from the error-log screen.
