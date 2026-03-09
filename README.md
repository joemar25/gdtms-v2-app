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
- `lib/features`: auth, dashboard, dispatch, delivery, wallet, profile
- `lib/shared`: reusable widgets, helpers, router

Main app flow:

1. `main.dart` boots app and sets initial route based on auth state.
2. `app.dart` hosts `MaterialApp.router` and theme mode binding.
3. `shared/router/app_router.dart` handles route table and route protection.

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

## API Base URL Configuration

This project uses `--dart-define` for environment switching.

- Base URL handling is defined in `lib/core/config.dart`.
- Use your team-approved environment value at build/run time.

Examples:

```bash
flutter run --dart-define=API_BASE_URL=<your-approved-api-base-url>
flutter build apk --dart-define=API_BASE_URL=<your-approved-api-base-url>
```

## Useful Commands

```bash
flutter analyze
flutter run -d emulator-5554 -v
adb -s emulator-5554 logcat -d | tail -n 300
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

Use credentials provided privately by your team leads or secure vault. Do not commit account credentials in repository files.

## Reference Documentation

- `.documentation/FLUTTER_MIGRATION.md`
- `.documentation/TODO.md`
- `.documentation/FRONTEND_STRUCTURE.md`

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

<!--
REDACTED_TEST_NUMBER
flutter clean - to
dart run flutter_native_splash:create - to replace assets with new one
-->
