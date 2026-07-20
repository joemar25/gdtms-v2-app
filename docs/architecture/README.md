<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  Architecture / ops hub for sync, coupling, performance, and accuracy.
  Register every new file here and in docs/index.md + README.md.
  ══════════════════════════════════════════════════════════════════════════════
-->

# Architecture docs

Maps how the mobile app keeps **courier-local data accurate** while the central
API holds fleet-scale data. Start here when changing sync, connectivity, or
offline write paths.

## Documents in this folder

| Doc | Purpose |
| --- | ------- |
| [system-map.md](./system-map.md) | End-to-end flow: write → queue → flush → bootstrap → UI refresh |
| [accuracy-and-scale.md](./accuracy-and-scale.md) | What “100% accurate” means on device; scale boundaries; Rules 1–4 |
| [ops-runbook.md](./ops-runbook.md) | **Support:** stuck pending, failed, conflict; never lose updates |
| [coupling-todo.md](./coupling-todo.md) | Coupling / thrash work (A2/A8 done; remaining A3/A1/…) |
| [sync-performance-todo.md](./sync-performance-todo.md) | Measured bootstrap speed plan (P1–P8; accuracy-preserving) |

## Related core docs

| Doc | Role |
| --- | ---- |
| [../core/sync.md](../core/sync.md) | `SyncManager`, bootstrap, write coordinator, WorkManager |
| [../core/providers.md](../core/providers.md) | `isOnlineProvider`, `deliveryRefreshProvider`, sync providers |
| [../core/database.md](../core/database.md) | SQLite schema, DAOs, queue tables |
| [../entry-points.md](../entry-points.md) | `app.dart` auto-sync triggers |
| [../features/sync-history.md](../features/sync-history.md) | Sync UI |
| [../features/delivery.md](../features/delivery.md) | Offline delivery submit |
| [../production-readiness-large-datasets.md](../production-readiness-large-datasets.md) | List/UI scale (50K–100K rows on device patterns) |
| [../features/timestamp-sync-contract.md](../features/timestamp-sync-contract.md) | Time / payload contract |

## Code entry points (DOCS headers)

| Source | Doc |
| ------ | --- |
| `lib/core/sync/*.dart` | `docs/core/sync.md` + this folder |
| `lib/app.dart` | `docs/entry-points.md` |
| `lib/core/providers/connectivity_provider.dart` | `docs/core/providers.md` |
| `lib/core/providers/sync_provider.dart` | `docs/core/providers.md` |
| `lib/core/providers/delivery_refresh_provider.dart` | `docs/core/providers.md` |
