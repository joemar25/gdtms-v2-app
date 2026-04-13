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
- Listens to `isOnlineProvider`; triggers `DeliveryBootstrapService` on the **first `false → true` transition** per session.
- Runs an auto-sync timer every **3 minutes** (`_kAutoSyncInterval`) when online.
- Starts `LocationPingService` after authentication.
- Runs `CleanupService` once per calendar day on app launch.

### Key constant

```dart
const _kAutoSyncInterval = Duration(minutes: 3);
```

Change this value here only — do not hard-code it elsewhere.

### Bootstrap trigger rule

Bootstrap fires **only** on the connectivity transition `false → true`. It will not re-fire if the app is already online when it starts.

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
