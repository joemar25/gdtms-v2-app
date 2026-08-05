<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/main.dart
    lib/app.dart
    lib/core/sync/auto_sync_coordinator.dart
    lib/splash_screen.dart

  Update this document whenever you change any of those files.
  Each of those files carries a header comment: "DOCS: docs/entry-points.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Entry Points

Covers the three files that boot the app and hand control to the router.

## Files

| File | Role |
|------|------|
| `lib/main.dart` | Process entry point — boot sequence |
| `lib/app.dart` | Root widget — theme, router, overlay entries |
| `lib/core/sync/auto_sync_coordinator.dart` | Sync trigger policy, debounce, `_runFullSync` (A1) |
| `lib/splash_screen.dart` | First screen — decides initial route |

---

## `lib/main.dart`

### Boot sequence (in order)

1. `WidgetsFlutterBinding.ensureInitialized()` — Flutter engine ready.
2. Lock orientation to portrait-up.
3. `AppVersionService.init()` — reads version from platform metadata once; cached for the session.
4. `AppDatabase.getInstance()` — opens SQLite before the first frame renders.
5. `BackgroundSyncSetup.init()` — registers WorkManager (Android) / BGTaskScheduler (iOS) tasks.
6. `SentryFlutter.init(...)` — crash monitoring; only active when `SENTRY_DSN` dart-define is provided at build time.
7. `runApp(ProviderScope(child: FsiCourierApp()))` — hands off to `app.dart`.

### Notes

- SQLite must be open before `runApp` because providers depend on it immediately.
- Sentry is skipped when `sentryDsn.isEmpty` — no need to guard call sites.

---

## `lib/app.dart`

### Responsibilities

- Hosts `MaterialApp.router` bound to `AppRouter`.
- Theme via `authProvider.select(themeMode)` (avoids full app rebuild on courier field updates).
- `_AutoSyncListener`: thin shell — `WidgetsBindingObserver` registration,
  root overlay insertion (sync pill, update banner, mandatory update), and
  `ref.listen(isOnlineProvider)` / `ref.listen(authProvider)` wiring that
  calls into `AutoSyncCoordinator` (see below) for the actual trigger policy.
  **A1 (2026-08-05):** trigger policy, debounce, `_runFullSync`, the
  periodic timer, and location-ping start/stop used to live directly in
  `_AutoSyncListenerState` — extracted out so the widget shell only owns
  widget-tree-bound concerns.

See [architecture/system-map.md](architecture/system-map.md) and [core/sync.md](core/sync.md).

---

## `lib/core/sync/auto_sync_coordinator.dart`

### Responsibilities

- Owns the 5 auto-sync triggers, debounce, `_runFullSync`, the periodic
  timer, and delegates location-ping start/stop to `LocationPingService`.
- Provider-scoped (`autoSyncCoordinatorProvider`), not widget-scoped — lives
  for the app session, torn down via `ref.onDispose`. Uses a `_disposed`
  flag (same pattern as `SyncManagerNotifier._disposed`) instead of a widget
  `mounted` check, since `Future.delayed` continuations (e.g. the reconnect
  trigger's 2s delay) outlive any single call and aren't tied to widget
  lifecycle.
- Also fires push-notification init and unread-count loads at each trigger
  point (they've always run alongside sync, not a separate concern).

### Key constants

```dart
static const _kAutoSyncInterval = Duration(minutes: 3);
static const _kSyncDebounce = Duration(seconds: 30);
// Skip debounce for: reconnected, login  (offline backlog must drain)
```

Change interval/debounce here only — do not hard-code elsewhere.

### Entry points → triggers

| Method | Reason | Debounce |
| ------ | ------ | -------- |
| `onStartup()` | `startup` | 30s |
| `onLogin()` | `login` | **skipped** |
| `onReconnect()` | `reconnected` | **skipped** |
| `onResume()` | `app_resume` | 30s |
| periodic timer (started by `onLogin`/`onReconnect`/`onResume`'s callers) | `periodic` | 30s |

`onLogout()` / `onOffline()` / `onPause()` / `onDetached()` cancel the
periodic timer and stop the location ping without triggering a sync.

Full sync body: `requestFlush(awaitIdle: true)` → if still `isOnline` →
`syncFromApi` → list refresh → cleanup.

**Online gate:** `isOnlineProvider` = network **and** API reachable. API-down is offline for sync.

---

## `lib/splash_screen.dart`

### Purpose

Shows the app logo while checking auth state. Redirects based on outcome:

| Condition | Redirect |
|-----------|----------|
| No stored token | `/login` |
| Token present, location not granted | `/location-required` |
| Token present, location OK, deliveries not seeded | `/initial-sync` |
| Token present, location OK, deliveries seeded | `/dashboard` |

### Notes

- Auth check uses `AuthStorage` (secure storage) — no network call.
- Route guards in `app_router.dart` enforce these same rules on every navigation.
- Visual system shares auth language but **quieter**: `DsBrandBackdrop(intensity: quiet)`, `AuthLogoMark(pulse: false)`, glass chips, DS stagger. Do not reuse login `standard` intensity on splash.
