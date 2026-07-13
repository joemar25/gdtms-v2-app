<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This document tracks the migration from GDTMS v2 to ITMS.

  When any step is completed, mark it [x].
  When new steps are discovered, add them here.
  ══════════════════════════════════════════════════════════════════════════════
-->

# GDTMS → ITMS Migration Sequence

> **Status**: IN PROGRESS — some steps completed, others pending.
> **Last updated**: July 13, 2026

This document lists every item that must change when migrating from the GDTMS v2 branding/infrastructure to ITMS. Steps are ordered by dependency — complete them in sequence.

---

## Table of Contents

1. [Overview — What Changes](#overview--what-changes)
2. [Phase 1 — Google Firebase (NEW Google Project)](#phase-1--google-firebase-new-google-project)
3. [Phase 2 — Google Play Console](#phase-2--google-play-console)
4. [Phase 3 — Backend API URL](#phase-3--backend-api-url)
5. [Phase 4 — Flutter App Code](#phase-4--flutter-app-code)
6. [Phase 5 — Documentation](#phase-5--documentation)
7. [Phase 6 — iOS (App Store Connect)](#phase-6--ios-app-store-connect)
8. [Summary Checklist](#summary-checklist)

---

## Overview — What Changes

| Asset | GDTMS (old) | ITMS (new) | Status |
|-------|-------------|------------|--------|
| Firebase project | `gdtms-v2-app` | `itms-mobile-254ce` | ✅ Done |
| Android package ID | `com.fsi.gdtms` | `itms.fsi.com.ph` | ✅ Done |
| iOS bundle ID | `com.fsi.gdtms` | `itms.fsi.com.ph` | ✅ Done |
| API base URL (prod) | `https://gdtms.fsi.com.ph/api/mbl` | `https://itms.fsi.com.ph/api/mbl` | ❌ Pending |
| API base URL (demo) | `https://gdtms.demo.fsi.com.ph/api/mbl` | `https://itms.demo.fsi.com.ph/api/mbl` | ❌ Pending |
| App display name | `GDTMS V2 Mobile App` | `ITMS` | ✅ Done |
| App title in `app.dart` | `'GDTMS V2 Mobile App'` | `'ITMS'` | ✅ Done |
| Google Play listing | GDTMS v2 | ITMS | ❌ Pending |
| Docs folder | `docs/gdtms-v2-api/` | `docs/itms-api/` | ❌ Pending |
| Code comments | `GDTMS` references | `ITMS` | ✅ Done |

---

## Phase 1 — Google Firebase (NEW Google Project)

The Firebase project was migrated from `gdtms-v2-app` to `itms-mobile-254ce`. This phase is **complete**.

### 1.1 Create new Firebase project in Google Cloud Console

- [x] Go to [console.firebase.google.com](https://console.firebase.google.com)
- [x] Create project: `itms-mobile-254ce`
- [x] Enable Analytics (optional, but recommended)

### 1.2 Register Android app in new Firebase project

- [x] Add Android app with package `itms.fsi.com.ph`
- [x] Download `google-services.json` → place in `android/app/google-services.json`
- [x] SHA-1 fingerprint from keystore: get it via `keytool -list -v -keystore upload-keystore.jks -alias upload`

### 1.3 Register iOS app in new Firebase project

- [x] Add iOS app with bundle ID `itms.fsi.com.ph`
- [x] Download `GoogleService-Info.plist` → place in `ios/Runner/`

### 1.4 Register Web app in new Firebase project

- [x] Add Web app for Windows/macOS support
- [x] Firebase config auto-generated into `lib/firebase_options.dart` via FlutterFire CLI

### 1.5 Update FlutterFire configuration

Run the FlutterFire CLI to regenerate `lib/firebase_options.dart`:
```bash
flutterfire configure \
  --project=itms-mobile-254ce \
  --platforms=android,ios,web,macos,windows
```

- [x] `lib/firebase_options.dart` regenerated with new project
- [x] `firebase.json` updated with new project ID and app IDs

### 1.6 Update dart_defines.json — Firebase keys

All four platform API keys must be from the NEW Firebase project:
```json
{
  "FIREBASE_API_KEY_WEB":      "<from itms-mobile-254ce>",
  "FIREBASE_API_KEY_ANDROID":  "<from itms-mobile-254ce>",
  "FIREBASE_API_KEY_IOS":      "<from itms-mobile-254ce>",
  "FIREBASE_API_KEY_WINDOWS":  "<from itms-mobile-254ce>"
}
```

- [x] Keys updated (see `dart_defines.json`)

### 1.7 Backend: Update Firebase credentials

The **Laravel backend** needs the new service account JSON:

- [ ] Generate new private key in Firebase Console → Project Settings → Service Accounts
- [ ] Place new JSON at `storage/app/firebase_credentials.json` on the server
- [ ] Update `.env`: `FIREBASE_CREDENTIALS=storage/app/firebase_credentials.json`
- [ ] Update `FCM_SENDER_ID` / `FCM_PROJECT_ID` if they exist in `.env`
- [ ] Verify push notifications still work end-to-end

### 1.8 Rebuild and test push notifications

- [ ] Build APK with new Firebase config
- [ ] Log in, verify FCM token is registered (`POST /profile/fcm-token` succeeds)
- [ ] Send test push from backend → verify receipt on device

---

## Phase 2 — Google Play Console

When the app goes from GDTMS to ITMS on the Play Store, you must create a **new app listing** because the package ID changed (`com.fsi.gdtms` → `itms.fsi.com.ph`). Android treats a different package ID as a completely different app.

### 2.1 Create new Play Console listing

- [ ] Go to [play.google.com/console](https://play.google.com/console)
- [ ] Create new app: name = `ITMS`, language = default
- [ ] Set app type: App (not Game)
- [ ] Declare free/paid

### 2.1.1 Generate upload keystore (ITMS signing key)

The upload keystore signs every App Bundle before upload to Google Play.
Google then re-signs with the Play App Signing key for distribution.

> 📝 **Private documentation**: `note.mar` (gitignored) contains the full keystore
> generation command, credentials, certificate details, and SHA-1 fingerprint.
> Keep this file — it is referenced for future key rotation, CI setup, and rebuilds.

```bash
keytool -genkey -v \
  -keystore upload-keystore.jks \
  -storetype JKS \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload
```

- [x] Keystore generated at `android/upload-keystore.jks` (gitignored)
- [x] `android/key.properties` updated with store/key passwords and alias (gitignored)
- Store password: `fsi-itms-2026`
- Key alias: `upload`
- Validity: 10,000 days (~27 years)

**Important**: Get the SHA-1 fingerprint for Firebase registration:
```bash
keytool -list -v -keystore android/upload-keystore.jks -alias upload
```
Add the SHA-1 to the Firebase Android app config (Phase 1.2).

### 2.1.2 Gitignored private files — do not delete

These files contain credentials/secrets and are **never committed**.
They are listed in `.gitignore` and referenced here so future maintainers know what they are.

| File | Purpose | Gitignore line |
|------|---------|---------------|
| `android/upload-keystore.jks` | Upload signing key for Google Play App Bundles | `# mar-playstore-prod-conf` |
| `android/key.properties` | Keystore passwords + alias (read by Gradle at build) | same block |
| `dart_defines.json` | API base URLs, AWS keys, Firebase keys, feature flags | `# Local environment / dart-define values` |
| `note.mar` | Private operational notes (keystore creds, CI encoding, SHA-1) | `# mar — private operational notes` |
| `android/app/google-services.json` | Firebase Android config (auto-downloaded from console) | *(handled by `.gitignore` template)* |

> ⚠️ **Loss of `upload-keystore.jks` = cannot update the app on Google Play.**
> Back up this file off-repo (secure file share, password manager, hardware token).
> Without it, you must contact Google Play support to reset the signing key — a multi-week process.

### 2.2 Set up store listing

- [ ] App name: `ITMS`
- [ ] Short description (≤80 chars)
- [ ] Full description (≤4000 chars)
- [ ] Screenshots: phone (2–8), tablet 7" (up to 8), tablet 10" (up to 8)
- [ ] Feature graphic (1024×500 px)
- [ ] App icon (512×512 px)
- [ ] Privacy policy URL
- [ ] Category: Business / Productivity
- [ ] Content rating questionnaire

### 2.3 Upload first release

- [ ] Build signed App Bundle:
  ```bash
  flutter build appbundle --release --dart-define-from-file=dart_defines.json
  ```
- [ ] Upload to Play Console → Testing → Internal/Closed/Open track
- [ ] Roll out to testers, verify everything works

### 2.4 Manage old GDTMS listing

- [ ] Once ITMS is live, update old GDTMS listing description: "This app has been replaced by ITMS. Please download ITMS instead."
- [ ] Unpublish old GDTMS app (don't delete — existing users who don't update still have it installed)

---

## Phase 3 — Backend API URL

The API base URL must switch from `gdtms.fsi.com.ph` to `itms.fsi.com.ph`.

### 3.1 Confirm new API domain is live

- [ ] Verify `https://itms.fsi.com.ph/api/mbl` resolves and responds
- [ ] Verify `https://itms.demo.fsi.com.ph/api/mbl` resolves and responds
- [ ] Confirm all endpoints work under the new domain (run the Postman collection against it)

### 3.2 Update dart_defines.json

```json
{
  "API_BASE_URL_PROD": "https://itms.fsi.com.ph/api/mbl",
  "API_BASE_URL_DEMO": "https://itms.demo.fsi.com.ph/api/mbl",
  "API_BASE_URL_LOCAL": "http://<YOUR_IP>:8080/api/mbl",
  "API_BASE_URL": "http://<YOUR_IP>:8080/api/mbl"
}
```

- [ ] Update `dart_defines.json`
- [ ] Update `dart_defines.example.json` (if it exists)

### 3.3 Update lib/core/config.dart

- [ ] Update the `defaultValue` in `apiBaseUrl` if it references the old domain:
  ```dart
  const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://YOUR_API_BASE_URL/api/mbl', // keep as placeholder
  );
  ```
  (Actually the default is already a placeholder — no change needed unless it hardcoded `gdtms`.)

### 3.4 Update Postman collection

- [ ] Open `docs/gdtms-v2-api/Courier-Mobile-API.postman_collection.json`
- [ ] Update `{{baseURL}}` variable or all instance URLs from `gdtms.fsi.com.ph` to `itms.fsi.com.ph`
- [ ] Search-and-replace throughout the collection file

---

## Phase 4 — Flutter App Code

### 4.1 lib/app.dart — App title

- [ ] Change line 49:
  ```dart
  // Before:
  title: 'GDTMS V2 Mobile App',
  // After:
  title: 'ITMS',
  ```

### 4.2 Code comments — replace GDTMS references

Files with `GDTMS` in comments (no functional change, just clarity):

| File | Line | Current Text |
|------|------|-------------|
| `lib/features/delivery/delivery_update_screen.dart` | 669 | `// Send the informant as a STRUCTURED field so GDTMS persists it into` |
| `lib/features/delivery/helpers/delivery_update_helper.dart` | 43 | `/// and must NEVER be concatenated into the free-text note/remarks. GDTMS stores` |
| `lib/services/update_service.dart` | 19 | `/// mobile endpoints (see docs/gdtms-v2-api/mobile-api-requirements.md).` |
| `lib/shared/helpers/string_helper.dart` | 34 | `/// GDTMS may store multiple numbers using...` |

- [ ] Replace `GDTMS` → `ITMS` in all above comments
- [ ] Update doc reference in `update_service.dart` if folder is renamed

### 4.3 lib/core/config.dart — verify

- [x] `appName = 'ITMS'` — already correct
- [x] `packageId = 'itms.fsi.com.ph'` — already correct
- [x] `deviceName = 'Mobile App'` — already correct

### 4.4 Translations — verify

- [x] `assets/translations/en.json` — uses "ITMS"
- [x] `assets/translations/fil.json` — uses "ITMS"

### 4.5 Android-side verification

- [x] `android/app/build.gradle.kts` — `applicationId = "itms.fsi.com.ph"`
- [x] `android/app/src/main/AndroidManifest.xml` — `${applicationId}.fileProvider`
- [ ] Verify `android/app/google-services.json` package name matches `itms.fsi.com.ph`

### 4.6 iOS-side verification

- [ ] `ios/Runner.xcodeproj/project.pbxproj` — PRODUCT_BUNDLE_IDENTIFIER = `itms.fsi.com.ph`
- [ ] `ios/Runner/Info.plist` — CFBundleDisplayName = `ITMS`
- [ ] `ios/Runner/GoogleService-Info.plist` — BUNDLE_ID = `itms.fsi.com.ph`

### 4.7 Rebuild and smoke test

- [ ] `flutter clean`
- [ ] `flutter pub get`
- [ ] `flutter run --dart-define-from-file=dart_defines.json`
- [ ] Verify login, sync, delivery update, push notification all work

---

## Phase 5 — Documentation

### 5.1 Rename docs/gdtms-v2-api/ → docs/itms-api/

- [ ] Rename folder:
  ```bash
  mv docs/gdtms-v2-api docs/itms-api
  ```
- [ ] Update all cross-references:
  - `docs/index.md` — update links from `gdtms-v2-api/` to `itms-api/`
  - `docs/core/api.md` — update header comment reference
  - `README.md` — update all `gdtms-v2-api/` links
  - `docs/development-standards.md` — update any `gdtms-v2-api/` references

### 5.2 Update docs/index.md

- [x] Already says "ITMS mobile app" in maintenance notice — ✅
- [ ] Update all `gdtms-v2-api/` links → `itms-api/`

### 5.3 Update docs/development-standards.md

- [ ] Title: `Development Standards for GDTMS v2 Mobile App` → `Development Standards for ITMS Mobile App`
- [ ] System Overview section: `GDTMS v2 Courier Mobile App` → `ITMS Courier Mobile App`

### 5.4 Update docs/gdtms-v2-api/README.md → docs/itms-api/README.md

- [ ] Title: `GDTMS v2 API` → `ITMS API`
- [ ] All `gdtms.fsi.com.ph` URLs → `itms.fsi.com.ph`

### 5.5 Update docs/features/push_notifications.md

- [ ] Line 3: `GDTMS v2` → `ITMS`
- [ ] Firebase project details table (line 83–84): update to `itms-mobile-254ce` and new service account
- [ ] Line 417: `gdtms-v2-app` → `itms-mobile-254ce`

### 5.6 Update Postman collection metadata

- [ ] Collection name: `GDTMS v2 API` → `ITMS API`
- [ ] All `gdtms.fsi.com.ph` URLs → `itms.fsi.com.ph`

### 5.7 Update this migration doc in docs/index.md

- [ ] Add entry: `- [gdtms-to-itms-migration.md](gdtms-to-itms-migration.md) — GDTMS → ITMS migration sequence and checklist`

---

## Phase 6 — iOS (App Store Connect)

If the iOS build is also being migrated:

### 6.1 Create new App Store Connect record

- [ ] Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
- [ ] Create new app: bundle ID = `itms.fsi.com.ph`, name = `ITMS`
- [ ] Set up SKU, user access, etc.

### 6.2 Build and upload

- [ ] `flutter build ipa --release --dart-define-from-file=dart_defines.json`
- [ ] Upload via Xcode or Transporter

### 6.3 Manage old listing

- [ ] Update old GDTMS listing description to point to ITMS
- [ ] Optionally remove old app from sale

---

## Summary Checklist

### ✅ Already Done
- [x] New Firebase project `itms-mobile-254ce` created
- [x] `google-services.json` updated with new Firebase project
- [x] `lib/firebase_options.dart` regenerated for new project
- [x] `firebase.json` updated
- [x] `dart_defines.json` Firebase keys updated
- [x] Android `applicationId` = `itms.fsi.com.ph`
- [x] Upload keystore generated (`android/upload-keystore.jks`, gitignored) with key alias `upload`
- [x] `android/key.properties` configured with ITMS keystore credentials (gitignored)
- [x] `lib/core/config.dart` — `appName`, `packageId` set to ITMS
- [x] Translation files use "ITMS"

### ❌ Pending — High Priority
- [x] Update `lib/app.dart` title from `'GDTMS V2 Mobile App'` to `'ITMS'` ✅
- [x] Update `dart_defines.json` API URLs: `gdtms.fsi.com.ph` → `itms.fsi.com.ph` ✅
- [ ] Backend: new Firebase service account credentials
- [ ] End-to-end push notification test with new Firebase project

### ❌ Pending — Medium Priority
- [ ] Rename `docs/gdtms-v2-api/` → `docs/itms-api/` and update all cross-references
- [x] Update code comments (4 files) replacing `GDTMS` → `ITMS` ✅
- [x] Update `docs/development-standards.md` title and overview ✅
- [ ] Update `docs/features/push_notifications.md` Firebase project details
- [ ] Update Postman collection URLs and name
- [ ] Create new Google Play Console listing for ITMS
- [ ] Upload first ITMS App Bundle to Play Console

### ❌ Pending — Low Priority (nice-to-have)
- [ ] iOS App Store Connect new listing
- [ ] Old GDTMS Play Store listing: add deprecation notice
- [ ] Update `README.md` any remaining GDTMS references
- [ ] Register this doc in `docs/index.md`

---

## Rollback Plan

If the new ITMS API domain or Firebase project has issues:

1. **API rollback**: Change `API_BASE_URL` in `dart_defines.json` back to the old GDTMS URL, rebuild, redistribute.
2. **Firebase rollback**: Swap `google-services.json` and `firebase_options.dart` back to the old project. The backend must also switch FCM credentials back.
3. **Play Store rollback**: Keep the old GDTMS listing published until ITMS is fully validated.
