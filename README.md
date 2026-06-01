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
- `lib/design_system`: premium design tokens (colors, typography) and core widgets
- `lib/features`: auth, dashboard, dispatch, delivery, wallet, profile, notifications
- `lib/shared`: reusable widgets, helpers, router

Main app flow:

1. `main.dart` boots app and sets initial route based on auth state.
2. `app.dart` hosts `MaterialApp.router` and theme mode binding.
3. `shared/router/app_router.dart` handles route table and route protection.

## Documentation

> **Rule 1 — API source of truth**: `docs/gdtms-v2-api/Courier-Mobile-API.postman_collection.json` is the single source of truth for all API definitions. **Update the collection first**, then `docs/gdtms-v2-api/README.md`, then the affected feature doc, then the app code. Never write or change API-related app code before the collection is updated.
>
> **Rule 2 — Code docs**: Every source file has a `// DOCS: docs/path/to/file.md` header comment. When you edit a file, open that doc and keep it up to date. When you add a new file or folder, create a matching doc, register it in `docs/index.md`, and add it below.

Full index: [docs/index.md](docs/index.md)

### API Reference

- [Postman collection README](docs/gdtms-v2-api/README.md) — full endpoint reference, changelog, development workflow (v2.3)

### Entry Points

- [Entry points](docs/entry-points.md) — `main.dart`, `app.dart`, `splash_screen.dart`

### Core

- [API client & S3 upload](docs/core/api.md)
- [Auth — provider, storage, service](docs/core/auth.md)
- [Database — SQLite schema, DAOs, cleanup](docs/core/database.md)
- [Device info & storage platform channel](docs/core/device.md)
- [Models](docs/core/models.md)
- [Providers](docs/core/providers.md)
- [Services](docs/core/services.md)
- [Settings & config](docs/core/settings.md)
- [Sync — SyncManager, bootstrap, background tasks](docs/core/sync.md)

### Features

- [Auth screens](docs/features/auth.md)
- [Dashboard](docs/features/dashboard.md)
- [Delivery — list, detail, update, signature](docs/features/delivery.md)
- [Dispatch — eligibility & list](docs/features/dispatch.md)
- [Error logs](docs/features/error-logs.md)
- [Initial sync](docs/features/initial-sync.md)
- [Legal — terms & privacy](docs/features/legal.md)
- [Location required](docs/features/location.md)
- [Notifications](docs/features/notifications.md)
- [Profile](docs/features/profile.md)
- [Report issue](docs/features/report.md)
- [Scan](docs/features/scan.md)
- [Sync history](docs/features/sync-history.md)
- [Wallet — overview, payout detail, payout request](docs/features/wallet.md)

### Shared

- [Helpers](docs/shared/helpers.md)
- [Router — full route table & guards](docs/shared/router.md)
- [Widgets](docs/shared/widgets.md)

### Design System

- [Styles & Design System](docs/styles.md) — tokens (colors, typography, spacing) and atomic widgets

### User Manual

- [Courier User Manual](docs/manual/index.html) — Beautiful, interactive, and friendly HTML user manual designed specifically for non-technical couriers.

### Legacy / Specific Reports

- [Delivery Retention Rules & API v2.0](docs/mobile-delivery-retention.md)
- [API Timestamp Bug Report](docs/api-timestamp-bug-report.md)

## Key Features

- Login and reset password
- Dashboard summary and paginated lists
- Dispatch scan, eligibility check, accept flow
- Delivery scan, details, and status update with photo attachments
- Wallet overview and payout request/detail
- Profile with settings toggles and logout

## UAT Phase 1: Essential Scenarios

For the upcoming UAT phase, we will focus specifically on the following essential scenarios for the mobile app (which connects to the central GDTMS Web API). All other features are deferred to Phase 2.

1. **Courier can login:** Test authentication flow and loading of the dashboard.
   - **UI Fields**: **Phone Number** (TextField), **Password** (TextFormField with eye visibility icon toggle), **Remember Phone Number** (saves username to SharedPreferences), circular **Theme Toggle** (sun/moon icon in the top-right corner to toggle between premium Dark and Light mode), **Forgot Password** link, and **Contact Admin** footer option (displays modal sheet with coordinator number `09213920200` to call).
2. **Courier can deliver offline:** Test completing delivery updates without internet, ensuring updates are stored in the local SQLite queue (`delivery_update_queue`).
   - **UI Fields (Delivered)**: **Recipient Name** (TextField), **Relationship** (searchable picker: OWNER, SPOUSE, SIBLING, PARENT, CHILD, HOUSEHOLD_HELP, CO_WORKER, SECURITY_GUARD, or OTHERS), **Specify Relationship** (TextField, required for OTHERS), **Placement Type** (Dropdown: RECEIVED, MAILBOX, UNDER_THE_DOOR, or NEIGHBOR), **POD Photo** (Camera photo), **Selfie Photo** (Camera photo), **Confirmation Code** (6-character alphanumeric TextField), optional **Remarks** (TextField with active preset chips), and optional **Signature** (checkbox to show signature slot, opens signature capture canvas).
   - **Offline Enforcer**: Offline time validation uses an NTP ratchet mechanism stored in SharedPreferences, preventing systemic clock rollback tampering attempts.
3. **Courier can update deliveries:** Test online status updates and verify real-time sync with geocoding to the GDTMS Web Portal.
   - **UI Fields (Failed Delivery)**: **Reason for non-delivery** (searchable picker dropdown), **Specify Reason** (TextField, required for "Others"), **Informant Name (According To)** (TextField, required for specific reasons), **Selfie Photo** (Camera photo), and optional **Remarks** (TextField with active preset chips).
   - **UI Fields (Misrouted)**: **Mailpack Photo** (Camera photo) and optional **Remarks** (TextField with active preset chips).
4. **Courier can request payout:** Test payout preview and submission based on server-calculated eligible deliveries.
   - **UI Fields**: Review read-only **Coverage Period (Date Range)**, **Eligible Deliveries Count**, **Estimated Gross Earnings**, **Estimated Total Penalties** (deductions in red), **Estimated Coordinator Incentive** (deductions in orange), **Estimated Net Payable** (large green computed balance), and scrollable **Deliveries Rundown** grouped by date.
   - **Flow**: Tapping **"Request Payout"** opens a confirmation dialog showing the **Estimated Net Payable** inside a card and a warning notification. Tap **"Confirm & Submit"** to POST the request to the central Web API for OPS review.
5. **Courier can consolidate payout:** Test automatic consolidation of new deliveries.
   - **Condition**: Consolidation only triggers if the courier has **new eligible deliveries** and the **previous payout request is still PENDING (not yet approved by OPS)**. Approved requests are strictly locked from consolidation to preserve auditing records.
   - **UI Fields**: Observe the **Consolidation Warning Banner** on the wallet screen and the request page. Merging new deliveries preserves the original unique **Reference Code** while updating total volumes, gross earnings, deductions, and net payable.

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

All environment values live in `lib/core/config.dart` and are injected atq
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
   ```

### Production Build Standard

For official releases, use these optimized commands to ensure the smallest possible size and code protection.

**For Google Play Store (App Bundle):**

```bash
flutter build appbundle --release \
  --dart-define-from-file=dart_defines.json \
  --tree-shake-icons \
  --obfuscate \
  --split-debug-info=build/app/outputs/symbols
```

**For Direct APK Distribution (Smallest APKs):**

```bash
flutter build apk --release \
  --dart-define-from-file=dart_defines.json \
  --split-per-abi \
  --tree-shake-icons \
  --obfuscate \
  --split-debug-info=build/app/outputs/symbols
```

### Available keys

| Key                     | Default                            | Description                                                  |
| ----------------------- | ---------------------------------- | ------------------------------------------------------------ |
| `API_BASE_URL`          | `http://YOUR_API_BASE_URL/api/mbl` | Backend API base URL                                         |
| `USE_S3_UPLOAD`         | `false`                            | `true` to upload media directly to S3 instead of via the API |
| `AWS_ACCESS_KEY_ID`     | _(empty)_                          | AWS IAM key ID — required when `USE_S3_UPLOAD=true`          |
| `AWS_SECRET_ACCESS_KEY` | _(empty)_                          | AWS IAM secret — required when `USE_S3_UPLOAD=true`          |
| `AWS_REGION`            | `ap-southeast-1`                   | S3 bucket region                                             |
| `AWS_BUCKET`            | `REDACTED_BUCKET_NAME`             | S3 bucket name                                               |

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
  --dart-define=API_BASE_URL=http://YOUR_API_BASE_URL/api/mbl \
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
flutter pub run flutter_launcher_icons:main
# dart run flutter_native_splash:create OR dart run flutter_native_splash:remove 2>&1 to remove the splash auto generated by flutter
flutter build apk --dart-define-from-file=dart_defines.json

```

### Icon & Asset Optimization

The project follows a strict asset optimization policy:

- **Fonts**: Handled via `google_fonts` package (no `.ttf` assets).
- **Images**: New assets should use `.webp` format.
- **Clean Code**: Redundant web assets (favicons, manifest) and manual font files are purged to keep the repository lean.

1. **Rebuild Icons**: Run `dart run flutter_launcher_icons`.
2. **Clear Cache**: Run `flutter clean` then `flutter pub get`.
3. **Full Rebuild**: For Android, delete `android/app/build` then run `flutter build apk`.

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

- [Documentation index](docs/index.md)

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

<!-- check connection:  curl -v http://YOUR_API_BASE_URL -->

in the sync page, the connect o sync should not hinder the pagination since it does not need to , i think 1 button there is good which is in the header to serve its function right?

and in the delivery details no need to show a button that it is pending sync. instead just show a ready for sync so this delivery details should not be inreacted with.

always run `dart format .` [documentation](https://dart.dev/tools/dart-format).

<!-- what to do:
find . -name "*{module_name_here}*"
example: find . -name "*profile*"

find lib -name "*{module_name_here}*"
example: find lib -name "*profile*"

grep -n "class _StatChip" "c:\Users\Joemar Jane Cardiño\Documents\FSI-Internal\fsi-courier-app\lib\features\profile\profile_screen.dart"

setup the notification - https://www.youtube.com/watch?v=k0zGEbiDJcQ

TIME:
The hardcoded 2025-01-01 floor is gone entirely. The only trusted anchor is now the persisted NTP reference — a real server timestamp written to
SharedPreferences after every successful online check.

What is now detectable offline

┌────────────────────────────────────────────────────────────┬────────────────────────────────────────────────────────────────────────────────┐
│                          Scenario                          │                                     Result                                     │
├────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────┤
│ Fresh install, never went online → set any date            │ Blocked — "Device time has not been verified yet. Connect to the internet      │
│                                                            │ once."                                                                         │
├────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────┤
│ Was online yesterday (Apr 17) → roll back to Apr 15        │ Blocked — persisted ref is Apr 17, device is 48h behind                        │
│ offline                                                    │                                                                                │
├────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────┤
│ Was online at 10pm → roll back 1 hour offline              │ Blocked — persisted ref is 10pm, device is 3600s behind                        │
├────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────┤
│ Was online, time is correct, now offline                   │ Allowed — device is ahead of ref (normal time passing)                         │
└────────────────────────────────────────────────────────────┴────────────────────────────────────────────────────────────────────────────────┘

What is fundamentally not preventable

If someone clears app data (wiping SharedPreferences) and then goes offline with a wrong clock — the reference is gone. There is no cryptographic
solution to this on a device the user physically controls without rooting or a hardware security module.

The practical mitigation: the app requires at least one online NTP check before trusting the clock at all — so a courier cannot use the app purely
offline from day one.

The offline logic now works correctly:

  ┌─────────────────────────────────────────────────────────────────────┬─────────────────────────────────────────────┐
  │                                State                                │                  Behaviour                  │                               ├─────────────────────────────────────────────────────────────────────┼─────────────────────────────────────────────┤
  │ Offline, no persisted reference (fresh install)                     │ Allowed — can't prove it's wrong, fail open │
  ├─────────────────────────────────────────────────────────────────────┼─────────────────────────────────────────────┤
  │ Offline, has reference, device time is correct (ahead of reference) │ Allowed — normal forward drift              │
  ├─────────────────────────────────────────────────────────────────────┼─────────────────────────────────────────────┤
  │ Offline, has reference, clock rolled back behind reference by > 30s │ Blocked — rollback detected                 │
  ├─────────────────────────────────────────────────────────────────────┼─────────────────────────────────────────────┤
  │ Offline, same session, monotonic watch detects in-session rollback  │ Blocked                                     │
  └─────────────────────────────────────────────────────────────────────┴─────────────────────────────────────────────┘

  The key fix was the missing if (rollbackA > allowedSkew) guard — without it, every offline check with a persisted reference was returning blocked
  regardless of whether the time was actually wrong.

How the sync anchor ratchet works
  → SyncManager.processQueue() gets ApiSuccess
  → recordSyncAnchor() stores 10:00am UTC in SharedPreferences
  → Anchor is now 10:00am

User sets device clock to 9:45am (offline tampering attempt)
  → Opens delivery update screen
  → Taps SUBMIT
  → checkSubmissionTime() reads anchor (10:00am)
  → 10:00am − 9:45am = 15 min > 30s allowedSkew
  → Returns valid: false
  → Shows error: "Device clock is behind the last sync time (10:00). Enable automatic date & time."
  → Submission blocked ✋

Key properties:
- Ratchet-only — anchor only moves forward, never back (nowMs > existing check)
- Fail open — if no anchor exists yet (first-ever use), submission is allowed
- Survives restarts — stored in SharedPreferences, not in memory
- 30s tolerance — same allowedSkew as the NTP check, accounts for minor clock drift
- Separate from NTP reference — the NTP reference guards the global time enforcer; the sync anchor guards specifically the delivery submission
gate

- works

flutter clean
flutter pub run flutter_launcher_icons:main
dart run flutter_native_splash:create
flutter run --dart-define-from-file=dart_defines.json

update app section in profile for update - and update available for click will go to profile to update the app (available only if on stable network)

-->
