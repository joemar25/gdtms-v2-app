<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/main.dart
    lib/app.dart
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
| `lib/app.dart` | Root widget — theme, router, background loops |
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
- `_AutoSyncListener`: multi-trigger full sync (flush queue then bootstrap).
- Starts `LocationPingService` after authentication when online.
- Overlay entries: sync pill, update banner, mandatory update.

### Key constants

```dart
const _kAutoSyncInterval = Duration(minutes: 3);
static const _kSyncDebounce = Duration(seconds: 30);
// Skip debounce for: reconnected, login  (offline backlog must drain)
```

Change interval/debounce here only — do not hard-code elsewhere.

### Auto-sync triggers

| Trigger | Reason | Debounce |
| ------- | ------ | -------- |
| Startup if already online | `startup` | 30s |
| Login `false→true` | `login` | **skipped** |
| Online `false→true` (network or API back) | `reconnected` | **skipped** |
| App resume | `app_resume` | 30s |
| Periodic timer while online | `periodic` | 30s |

Full sync body: `requestFlush(awaitIdle: true)` → if still `isOnline` → `syncFromApi` → list refresh → cleanup.

**Online gate:** `isOnlineProvider` = network **and** API reachable. API-down is offline for sync.

See [architecture/system-map.md](architecture/system-map.md) and [core/sync.md](core/sync.md).

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
