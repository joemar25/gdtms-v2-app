<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  System map for offline write + sync. Update when triggers, gates, or
  coordinator APIs change. Cross-link from docs/core/sync.md and entry-points.md.
  ══════════════════════════════════════════════════════════════════════════════
-->

# System map — offline write & sync

How the courier app stays consistent with the server when the API is available
**or** unavailable. Accuracy rules live in
[accuracy-and-scale.md](./accuracy-and-scale.md).

---

## One-picture flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│  FEATURE WRITE (delivery / bagsakan / …)                                  │
│  Always local first: SyncOperationsDao + LocalDeliveryDao                 │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  SyncWriteCoordinator.completeWrite(reason, awaitIdle, kickQueue)  [A2]   │
│  • refreshDeliveries → deliveryRefreshProvider++                          │
│  • kickQueue only if isOnlineProvider (network + API)                     │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │ online
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  SyncManager.requestFlush(reason, awaitIdle)  [A8]                        │
│  • Skip if !isOnline (API down / no network)                              │
│  • Coalesce concurrent kicks; re-run if ops arrive mid-pass (max 5)       │
│  • Per op: media upload → PATCH → synced | failed | conflict              │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │ auto-sync only (after flush)
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  DeliveryBootstrapService.syncFromApi  (Rules 1–4)                        │
│  Phase-0 verify-status → status sweeps / delta → bagsakan → cleanup       │
│  Aborted if isOnline flips false after flush                              │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  UI: lists watch deliveryRefreshProvider / providers / DAO queries        │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Connectivity gate

| Provider | Meaning |
| -------- | ------- |
| `isNetworkOnlineProvider` | Device has a network interface |
| `apiReachabilityProvider` | Periodic ping to API base URL (~10s) |
| `connectionStatusProvider` | `online` \| `networkOffline` \| `apiUnreachable` |
| **`isOnlineProvider`** | **`true` only when both network and API are OK** |

**Rule:** treat `apiUnreachable` like offline for **flush and auto-sync**. Couriers
still write to the queue; nothing is lost.

Source: `lib/core/providers/connectivity_provider.dart` → [../core/providers.md](../core/providers.md).

---

## Auto-sync triggers (`lib/app.dart`)

| Trigger | Reason string | Debounce 30s |
| ------- | ------------- | ------------ |
| Startup (already online) | `startup` | Yes |
| Login `false→true` auth | `login` | **No** (drain backlog) |
| Reconnect `false→true` online | `reconnected` | **No** (drain backlog) |
| App resume | `app_resume` | Yes |
| Periodic (3 min) | `periodic` | Yes |

Full sync order: **`requestFlush(awaitIdle: true)` → (if still online) `syncFromApi` → list refresh → cleanup**.

Details: [../entry-points.md](../entry-points.md).

---

## Component index

| Piece | File | Doc |
| ----- | ---- | --- |
| Write side effects | `lib/core/sync/sync_write_coordinator.dart` | [../core/sync.md](../core/sync.md) |
| Queue flush | `lib/core/sync/sync_manager.dart` | [../core/sync.md](../core/sync.md) |
| Pull / reconcile | `lib/core/sync/delivery_bootstrap_service.dart` | [accuracy-and-scale.md](./accuracy-and-scale.md) |
| Auto-sync shell | `lib/app.dart` | [../entry-points.md](../entry-points.md) |
| Background pull | `lib/core/sync/workmanager_setup.dart` | [../core/sync.md](../core/sync.md) |
| Delivery submit | `lib/features/delivery/delivery_update_screen.dart` | [../features/delivery.md](../features/delivery.md) |
| Sync UI | `lib/features/sync/*` | [../features/sync-history.md](../features/sync-history.md) |

---

## Plans / TODOs

| Plan | Focus |
| ---- | ----- |
| [coupling-todo.md](./coupling-todo.md) | Coupling, thrash, A2/A8 status |
| [sync-performance-todo.md](./sync-performance-todo.md) | Measured speed (P1–P8); never weaken Rules 1–4 |

---

## Logging (ops visibility)

Search device logs for:

- `[SYNC] requestFlush reason=…` — who kicked the queue  
- `[SYNC] requestFlush skipped — offline/API unreachable`  
- `[SYNC] _runFullSync start/after reason=…`  
- `[SYNC] _runFullSync: abort pull — API no longer online`  
- `[SYNC] priority reconciliation` — bootstrap Rule 1  

Use `reason` values (`submit_delivery`, `auto_sync_reconnected`, `bagsakan_form_save`, …) to correlate user actions with sync activity.

**Support playbooks (stuck pending, conflict, device wipe risk):**
[ops-runbook.md](./ops-runbook.md).
