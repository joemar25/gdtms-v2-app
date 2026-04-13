<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/core/settings/app_settings.dart
    lib/core/settings/compact_mode_provider.dart
    lib/core/config.dart
    lib/core/constants.dart

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
