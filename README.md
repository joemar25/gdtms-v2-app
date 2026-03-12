# FSI Courier App

Courier mobile application for dispatch, delivery updates (POD), wallet, and profile management.

## Overview

- Platform: Flutter (Android and iOS)
- Backend API: from `lib/core/config.dart` via `--dart-define=API_BASE_URL`
- Auth: Bearer token (stored in secure storage)
- Routing: `go_router` with auth guard
- State: `flutter_riverpod`
- Scanner: `mobile_scanner`

## Architecture

Project follows a feature-first structure with shared core infrastructure:

- `lib/core`: config, constants, auth, API client, settings, device, models
- `lib/features`: auth, dashboard, dispatch, delivery, wallet, profile, notifications
- `lib/shared`: reusable widgets, helpers, router

Main app flow:

1. `main.dart` boots app and sets initial route based on auth state.
2. `app.dart` hosts `MaterialApp.router` and theme mode binding.
3. `shared/router/app_router.dart` handles route table and route protection.

## Documentation

- [Delivery Retention Rules & API v2.0](docs/mobile-delivery-retention.md)

## Key Features

- Login and reset password
- Dashboard summary and paginated lists
- Dispatch scan, eligibility check, accept flow
- Delivery scan, details, and status update with photo attachments
- Wallet overview and payout request/detail
- Profile with settings toggles and logout

## Dependencies

Primary runtime dependencies:

- `dio`
- `flutter_secure_storage`
- `shared_preferences`
- `go_router`
- `flutter_riverpod`
- `device_info_plus`
- `permission_handler`
- `mobile_scanner`
- `image_picker`
- `cached_network_image`
- `uuid`
- `intl`
- `lottie`
- `flutter_local_notifications` (reserved for future use)

## Getting Started

### 1. Install dependencies

```bash
flutter pub get
```

### 2. Static checks

```bash
flutter analyze
```

### 3. Run on Android emulator

```bash
flutter run -d emulator-5554
```

## Environment Configuration

All environment values live in `lib/core/config.dart` and are injected at
build/run time via `--dart-define` or `--dart-define-from-file`.

> **Flutter does NOT support `.env` files natively.**
> Use `dart_defines.json` (the recommended approach below) instead.

### Recommended: `dart_defines.json`

1. Copy the example file and fill in your values:

   ```bash
   cp dart_defines.example.json dart_defines.json
   ```

2. `dart_defines.json` is **git-ignored** — never commit it.

3. Run or build with:

   ```bash
   flutter run --dart-define-from-file=dart_defines.json
   flutter build apk --dart-define-from-file=dart_defines.json
   ```

### Available keys

| Key                     | Default                           | Description                                                  |
| ----------------------- | --------------------------------- | ------------------------------------------------------------ |
| `API_BASE_URL`          | `http://YOUR_API_BASE_URL/api/mbl` | Backend API base URL                                         |
| `USE_S3_UPLOAD`         | `false`                           | `true` to upload media directly to S3 instead of via the API |
| `AWS_ACCESS_KEY_ID`     | _(empty)_                         | AWS IAM key ID — required when `USE_S3_UPLOAD=true`          |
| `AWS_SECRET_ACCESS_KEY` | _(empty)_                         | AWS IAM secret — required when `USE_S3_UPLOAD=true`          |
| `AWS_REGION`            | `ap-southeast-1`                  | S3 bucket region                                             |
| `AWS_BUCKET`            | `REDACTED_BUCKET_NAME`        | S3 bucket name                                               |

### Media upload modes

**API mode** (`USE_S3_UPLOAD=false`, default)

- App POSTs `{ file_data, mime_type, type }` JSON to `/deliveries/{barcode}/media`.
- Server handles S3 storage and returns the object URL.

**S3 direct mode** (`USE_S3_UPLOAD=true`)

- App signs and PUTs the image directly to S3 using AWS Signature V4.
- S3 key structure: `deliveries/{barcode}/images/{type}_{timestamp}.{ext}`
- No PHP upload buffering; the URL is returned immediately and included in the PATCH.
- **Offline behaviour**: images are queued as base64 in the local SQLite
  `delivery_update_queue` table under `_pending_media`. On reconnect,
  `SyncManagerNotifier` uploads each pending image using the same
  `deliveries/{barcode}/images/` path before sending the PATCH.

### Single-pass (no file) — local dev only

```bash
# API mode, local dev server
flutter run --dart-define=API_BASE_URL=http://YOUR_API_BASE_URL/api/mbl

# S3 direct upload, staging API
flutter run \
  --dart-define=API_BASE_URL=https://staging-gdtms-v2.skyward.com.ph/api/mbl \
  --dart-define=USE_S3_UPLOAD=true \
  --dart-define=AWS_ACCESS_KEY_ID=<key_id> \
  --dart-define=AWS_SECRET_ACCESS_KEY=<secret>
```

## Useful Commands

```bash
flutter analyze
flutter run -d emulator-5554 -v
adb -s emulator-5554 logcat -d | tail -n 300
```

### Reset App Environment

```bash
flutter clean
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

### Wireless Pairing

```bash
# On phone (dev mode): wireless debugging = true
# On PC:
adb pair REDACTED_ADB_HOST
# Enter pairing code from device
```

## Android Notes

### Desugaring requirement

`flutter_local_notifications` requires core library desugaring. This is already configured in:

- `android/app/build.gradle.kts`

If needed, verify these exist:

- `isCoreLibraryDesugaringEnabled = true`
- `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`

### VM service attach issue on emulator

If `flutter run` fails with:

- `Error connecting to the service protocol`
- `Connection closed before full header was received`
- repeated `Width is zero` logs

```bash
flutter run --no-enable-impeller
```

Use this sequence:

```bash
adb -s emulator-5554 shell input keyevent KEYCODE_WAKEUP
adb -s emulator-5554 shell wm dismiss-keyguard
adb -s emulator-5554 shell input keyevent 82
flutter run -d emulator-5554
```

If still unstable:

```bash
adb kill-server
adb start-server
adb -s emulator-5554 emu kill
flutter emulators --launch <your_emulator_id>
flutter run -d emulator-5554
```

## Credentials

Use credentials provided privately by the programmer leads or secure vault. Do not commit account credentials in repository files.

## Reference Documentation

- `.documentation/architecture.md`
- `.documentation/sync_logic_state.md`

## Future Enhancements

### Sync Data Retention

Synced delivery-update queue history is configurable per-courier in
**Profile → Preferences → Sync history** (1, 3, or 5 days).
Cleanup runs automatically at most once per calendar day on app launch.

Possible future improvements:

- [ ] Per-batch sync history grouping with labels and timestamps
- [ ] Export sync history to CSV for operational audit trails
- [ ] Configurable retention for local delivery records (currently fixed at `kLocalDataRetentionDays`)
- [ ] Background periodic cleanup using WorkManager (Android) / BGTaskScheduler (iOS)
- [ ] Push-notification digest of daily sync failures sent to a supervisor endpoint

### Mobile App Deliveries

- [ ] Determine who received the delivery in the update payload.
- [ ] Make signature optional for certain scenarios.
- [ ] DFAMCI special case: include courier reference number upon updating submission status.

<!-- check connection:  curl -v https://staging-gdtms-v2.skyward.com.ph -->
