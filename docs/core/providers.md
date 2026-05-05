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
| `sync_provider.dart` | `syncManagerProvider` | `StateNotifierProvider<SyncManagerNotifier, SyncState>` |
| `update_provider.dart` | `updateProvider` | `NotifierProvider<UpdateNotifier, UpdateState>` |

---

## `connectivity_provider.dart` — `isOnlineProvider`

- Wraps `connectivity_plus` stream.
- **Defaults to `false`** while the stream is loading or on error. This enables offline cold-start without blocking the UI.
- `app.dart` watches this to trigger bootstrap on the first `false → true` transition.

> Do not change the default to `true` — that would block offline cold-start.

---

## `delivery_refresh_provider.dart` — `deliveryRefreshProvider`

Simple counter. Increment it to signal that any screen watching deliveries should reload:

```dart
ref.read(deliveryRefreshProvider.notifier).state++;
```

Used after a successful sync or delivery update to refresh list/detail screens without full navigation.

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

## `update_provider.dart` — `updateProvider`

Manages the lifecycle of in-app updates. See [Update System](file:///docs/core/update-system.md) for a detailed breakdown of the update workflow.

| Property | Description |
|----------|-------------|
| `updateInfo` | Metadata about the available update (version, notes, etc.) |
| `showBanner` | True if an update is available and hasn't been dismissed/downloaded |
| `downloadStatus` | `idle`, `downloading`, `completed`, or `error` |
| `downloadProgress`| Progress value from 0.0 to 1.0 |
