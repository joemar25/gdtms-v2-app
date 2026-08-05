<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/core/settings/app_settings.dart
    lib/core/settings/compact_mode_provider.dart
    lib/core/settings/debug_ui_provider.dart
    lib/core/config.dart
    lib/core/constants.dart
    lib/shared/widgets/debug_ui_toggle.dart

  Update this document whenever you change any of those files.
  Each of those files carries a header comment: "DOCS: docs/core/settings.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Core — Settings & Config

## Files

| File | Role |
|------|------|
| `lib/core/config.dart` | Build-time dart-define values |
| `lib/core/constants.dart` | App-wide constants |
| `lib/core/settings/app_settings.dart` | User preferences stored in `SharedPreferences` |
| `lib/core/settings/compact_mode_provider.dart` | Riverpod provider for compact-mode toggle |
| `lib/core/settings/debug_ui_provider.dart` | Debug chrome preference + `showDebugUiProvider` |
| `lib/shared/widgets/debug_ui_toggle.dart` | Top-left chip (debug/dev only) |

---

## `config.dart`

All values come from `--dart-define` / `--dart-define-from-file`. They are compile-time constants — **not** runtime-readable from the environment.

| Constant | dart-define key | Default |
|----------|----------------|---------|
| `apiBaseUrl` | `API_BASE_URL` | `http://YOUR_API_BASE_URL/api/mbl` |
| `useS3Upload` | `USE_S3_UPLOAD` | `false` |
| `awsAccessKeyId` | `AWS_ACCESS_KEY_ID` | _(empty)_ |
| `awsSecretAccessKey` | `AWS_SECRET_ACCESS_KEY` | _(empty)_ |
| `awsRegion` | `AWS_REGION` | `ap-southeast-1` |
| `awsBucket` | `AWS_BUCKET` | `REDACTED_BUCKET_NAME` |
| `sentryDsn` | `SENTRY_DSN` | _(empty)_ |
| `kEnableProfileEdit` | `ENABLE_PROFILE_EDIT` | `false` |

---

## `constants.dart`

App-wide magic numbers and strings. Change values here — never inline them in feature code.

Key constants:

| Constant | Value | Purpose |
|----------|-------|---------|
| `kLocalDataRetentionDays` | 7 | Days before local delivery records are pruned |
| `kImageMaxWidth` | 600 | Max pixel width for compressed photos |
| `kImageQuality` | 70 | JPEG quality for `FlutterImageCompress` |
| `kStorageWarningGb` | 2.0 | Free-storage threshold for the warning banner |

---

## `app_settings.dart`

User preferences persisted via `SharedPreferences`.

| Key | Type | Default | Purpose |
|-----|------|---------|---------|
| `sync_history_days` | `int` | 3 | Days of sync history to keep |
| `compact_mode` | `bool` | `false` | Compact delivery card layout |
| `last_cleanup_date` | `String` | — | Tracks when `CleanupService` last ran |

---

## `compact_mode_provider.dart`

`compactModeProvider` — `StateNotifierProvider<CompactModeNotifier, bool>`.

Reads initial value from `AppSettings.compactMode`. Toggled from Profile → Preferences. Delivery list screens watch this to switch between normal and compact `DeliveryCard` variants.

---

## Debug UI chrome (global)

Works in **debug builds** and **release + developer mode**. Top-left chip opens a **dev shortcuts** sheet (not a mode switch).

| API | Role |
|-----|------|
| `computeDebugToolsAvailable` / `computeShowDebugUi` | Pure gates (unit-tested) |
| `debugToolsProvider` | Reactive tools gate — `syncFromRuntime()` after init / dev-mode flip |
| `debugUiProvider` | Preference (default true, key `debug_ui_visible`) |
| `showDebugUiProvider` | **Screens use this** — tools && preference |
| `DebugUiToggle` | Chip watches **tools** (not show) so it stays when chrome is off |

### DEBUG chip → Dev shortcuts

Floating fixed-size **DSGlassCard** chip (drag anywhere; clamped to safe area). Chrome-on uses warning accent on glass; chrome-off is muted glass. Tap → bottom sheet with hard-to-reach screens (develop only):

| Shortcut | Route | Notes |
|----------|-------|--------|
| Splash screen | `/splash` | Allowed even when authenticated (preview) |
| Initial sync | `/initial-sync` | Requires sign-in; allowed after sync completed |
| Edit profile | `/profile/edit` | Requires sign-in; bypasses `kEnableProfileEdit` |
| Theme | — | Light / System / Dark via `authProvider.setThemeMode` (same as Profile) |
| Hide / show debug chrome | — | Toggles `debugUiProvider` (labels / API panels) |

Router: when `debugToolsProvider` is true, those three routes skip normal guards (auth→dashboard bounce, post-sync redirect, profile-edit feature flag, terms/permissions gates for the preview).

```dart
if (ref.watch(showDebugUiProvider)) ...[ /* debug-only */ ],
```

Splash loads `RuntimeEnvironmentService` early then `debugToolsProvider.syncFromRuntime()`. Profile after developer-mode flip: same sync.
