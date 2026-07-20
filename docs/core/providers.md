<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/core/providers/connectivity_provider.dart
    lib/core/providers/delivery_refresh_provider.dart
    lib/core/providers/location_provider.dart
    lib/core/providers/notifications_provider.dart
    lib/core/providers/sync_provider.dart

  Update this document whenever you change any of those files.
  Each of those files carries a header comment: "DOCS: docs/core/providers.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Core — Providers

Global Riverpod providers that are not feature-specific.

## Files

| File | Provider | Type |
|------|----------|------|
| `connectivity_provider.dart` | `isOnlineProvider` | `StreamProvider<bool>` |
| `delivery_refresh_provider.dart` | `deliveryRefreshProvider` | `StateProvider<int>` |
| `location_provider.dart` | `locationProvider` | `StateNotifierProvider<LocationNotifier, LocationState>` |
| `notifications_provider.dart` | `notificationsProvider` | `StateNotifierProvider` |
| `sync_provider.dart` | `syncManagerProvider` | `NotifierProvider<SyncManagerNotifier, SyncState>` |
| `../sync/sync_write_coordinator.dart` | `syncWriteCoordinatorProvider` | `Provider<SyncWriteCoordinator>` |
| `update_provider.dart` | `updateProvider` | `NotifierProvider<UpdateNotifier, UpdateState>` |

---

## `connectivity_provider.dart` — online gate for sync

| Provider | Meaning |
| -------- | ------- |
| `isNetworkOnlineProvider` | Device has a network interface |
| `apiReachabilityProvider` | Periodic ping to API base URL (~10s) |
| `connectionStatusProvider` | `online` \| `networkOffline` \| `apiUnreachable` |
| **`isOnlineProvider`** | **`true` only when network + API OK** |

- Defaults to offline while loading/error → offline cold-start works.
- `app.dart` auto-sync and `requestFlush` / `completeWrite` use **`isOnlineProvider`**.
- **API unreachable** is treated like offline for flush and bootstrap (queue retained).

> Do not default `isOnlineProvider` to `true`.  
> System map: [../architecture/system-map.md](../architecture/system-map.md).

---

## `delivery_refresh_provider.dart` — `deliveryRefreshProvider`

Generation counter that signals delivery lists to reload (A3).

```dart
// Preferred after writes (via coordinator):
ref.read(deliveryRefreshProvider.notifier).invalidate(barcodes: {'BC1'});
// Full refresh (bootstrap):
ref.read(deliveryRefreshProvider.notifier).increment(); // == invalidate()
```

- Bumps are **debounced (~80ms)** so queue flush + completeWrite in one tick
  collapse to one UI rebuild.
- `lastDeliveryRefreshBarcodesProvider` stores optional scope (`null` = full).
- Prefer `syncWriteCoordinatorProvider.completeWrite(..., barcodes: …)`.

---

## `location_provider.dart` — `locationProvider`

Tracks GPS permission and current location state.

| `LocationState` | Meaning |
|----------------|---------|
| `LocationState.unknown` | Permission not yet checked |
| `LocationState.denied` | Permission denied — router redirects to `/location-required` |
| `LocationState.granted` | Permission OK — lat/lng available |

Router guards read this to block authenticated routes until location is granted.

---

## `notifications_provider.dart`

Manages local notification state. Currently reserved; `flutter_local_notifications` is initialized but not actively scheduling user-facing notifications.

---

## `sync_provider.dart` / write coordinator

- Watch `syncManagerProvider` for queue UI state (`isSyncing`, entries, progress).
- Kick the queue with `requestFlush(reason:, awaitIdle:)` (not raw parallel `processQueue`).
- After feature writes: `syncWriteCoordinatorProvider.completeWrite(...)`.

See [sync.md](sync.md) and [../architecture/system-map.md](../architecture/system-map.md).

---

## `update_provider.dart` — `updateProvider`

Manages the lifecycle of in-app updates. See [Update System](update-system.md) for a detailed breakdown of the update workflow.

| Property | Description |
|----------|-------------|
| `updateInfo` | Metadata about the available update (version, notes, etc.) |
| `showBanner` | True if an update is available and hasn't been dismissed |

`openUpdate()` opens the platform store listing (Play Store/App Store) via `UpdateService.launchStoreListing()` — there is no in-app download/install state.
