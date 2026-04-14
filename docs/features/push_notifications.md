# Push Notifications Guide (FCM)

This guide documents the Firebase Cloud Messaging (FCM) integration in GDTMS v2. It covers what is already implemented, how the system works end-to-end, and a full step-by-step checklist for re-setup or account migration.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [What Is Already Implemented](#what-is-already-implemented)
3. [Firebase Project Details](#firebase-project-details)
4. [Backend Implementation](#backend-implementation)
5. [Mobile (Flutter) Side](#mobile-flutter-side)
6. [Web UI — Delivery Reports Notification](#web-ui--delivery-reports-notification)
7. [Account Migration / Re-Setup Checklist](#account-migration--re-setup-checklist)
8. [Troubleshooting](#troubleshooting)
9. [Frequently Asked Questions (FAQ)](#frequently-asked-questions-faq)
10. [Related Files](#related-files)

---

## Architecture Overview

```
Flutter App                     Laravel API                     Firebase FCM
    │                               │                               │
    │  POST /api/mbl/login           │                               │
    │  (Sanctum token issued)        │                               │
    │◄─────────────────────────────  │ personal_access_tokens row    │
    │                               │                               │
    │  POST /api/mbl/profile/        │                               │
    │  fcm-token (device token)      │                               │
    │──────────────────────────────► │ stores in users.fcm_token     │
    │                               │                               │
    │                               │                               │
Web UI (Delivery Reports)           │                               │
    │                               │                               │
    │  POST delivery-reports/        │                               │
    │  send-courier-notification     │                               │
    │──────────────────────────────► │ PushNotificationService       │
    │                               │──────────────────────────────►│
    │                               │  CloudMessage (FCM HTTP v1)   │
    │                               │                               │──► Flutter device push
```

- The Laravel backend authenticates as a **Service Account** via a credentials JSON file — never via a browser/user login.
- The Flutter device token is stored per-user in the `users` table so the backend can target any courier at any time.
- Only the Laravel server communicates with Firebase. The Flutter app only sends its token to the backend; it never calls Firebase directly for outbound messages.
- A courier having an active Sanctum session (`personal_access_tokens` row) and having an FCM token are **separate states**. A courier can be logged in without a registered push device.

---

## What Is Already Implemented

| Component                     | File / Location                                                      | Status                                                      |
| ----------------------------- | -------------------------------------------------------------------- | ----------------------------------------------------------- |
| Composer package              | `kreait/laravel-firebase` v6.2.0                                     | ✅ installed                                                |
| Firebase config               | `config/firebase.php`                                                | ✅ published                                                |
| Env key                       | `FIREBASE_CREDENTIALS`                                               | ✅ set in `.env`, `.env.example`, `.env.production.example` |
| Credentials file              | `storage/app/firebase_credentials.json`                              | ✅ present                                                  |
| DB migration                  | `2026_04_14_000000_add_fcm_token_to_users_table.php`                 | ✅ migrated                                                 |
| Push service                  | `app/Services/PushNotificationService.php`                           | ✅ injectable                                               |
| Token sync endpoint           | `POST /api/mbl/profile/fcm-token`                                    | ✅ live                                                     |
| Notification trigger endpoint | `POST /delivery-reports/send-courier-notification`                   | ✅ live                                                     |
| User model                    | `app/Models/User.php` — `fcm_token` in `$fillable` and `$hidden`     | ✅ done                                                     |
| Web UI dialog                 | `resources/js/components/ui/reports/courier-notification-dialog.tsx` | ✅ done                                                     |
| Column action button          | `resources/js/components/columns/delivery-report-columns.tsx`        | ✅ done                                                     |
| Active-session detection      | `DeliveryRepository` — `withCount('tokens')` on courier user         | ✅ done                                                     |
| Differentiated tooltip        | `delivery-report-columns.tsx` — `courier_has_active_session` flag    | ✅ done                                                     |
| Flutter push service          | `lib/core/services/push_notification_service.dart`                   | ✅ done                                                     |
| Flutter Firebase init         | `lib/main.dart` — `Firebase.initializeApp` + background handler      | ✅ done                                                     |
| Flutter token sync on login   | `lib/app.dart` — `_AutoSyncListener` login listener                  | ✅ done                                                     |
| Flutter deep-link on tap      | `PushNotificationService` — tap-to-delivery deep link                | ✅ done                                                     |

---

## Firebase Project Details

| Property              | Value                                                          |
| --------------------- | -------------------------------------------------------------- |
| Firebase project ID   | `gdtms-v2-app`                                                 |
| Service account email | `firebase-adminsdk-fbsvc@gdtms-v2-app.iam.gserviceaccount.com` |
| Credentials file path | `storage/app/firebase_credentials.json`                        |
| Env key               | `FIREBASE_CREDENTIALS=storage/app/firebase_credentials.json`   |

> [!CAUTION]
> **Security**: `storage/app/firebase_credentials.json` is in `.gitignore`. Never commit this file. Pass it to servers via a secrets manager or secure file transfer.

---

## Backend Implementation

### 1. Package

```
kreait/laravel-firebase  v6.2.0
kreait/firebase-php      v7.24.1
```

Installed via Composer. Config published to `config/firebase.php`.

### 2. Environment

```env
FIREBASE_CREDENTIALS=storage/app/firebase_credentials.json
```

`config/firebase.php` reads `FIREBASE_CREDENTIALS` to locate the service account JSON. On the server, this path is relative to the application root (i.e. `base_path('storage/app/firebase_credentials.json')`).

### 3. Database Migration

```
database/migrations/2026_04_14_000000_add_fcm_token_to_users_table.php
```

Adds a nullable string column to the `users` table:

```php
$table->string('fcm_token')->nullable()->after('use_keyboard_shortcut_search');
```

`fcm_token` is listed in both `$fillable` (so it can be mass-assigned) and `$hidden` (so it never leaks in API JSON responses).

### 4. PushNotificationService

**File**: `app/Services/PushNotificationService.php`

Thin injectable wrapper around the kreait `Messaging` contract. Two public methods:

```php
// Target a User model (reads their stored fcm_token)
sendToUser(User $user, string $title, string $body, array $data = []): bool

// Target a raw token string
sendToToken(string $fcmToken, string $title, string $body, array $data = []): bool
```

- Returns `false` (and logs a warning) if the token is null or Firebase throws `MessagingException`.
- The `$data` array is sent as an FCM **data payload** — the Flutter app can use these key-value pairs for deep-linking or conditional UI.
- Inject this service into any controller or service via the constructor.

### 5. Token Sync Endpoint

**Route**: `POST /api/mbl/profile/fcm-token`  
**Route name**: `mobile.courier.profile.fcm-token`  
**Auth**: `auth:sanctum`  
**Controller**: `CourierMobileController@updateFcmToken`  
**FormRequest**: `UpdateFcmTokenRequest`

```json
// Request body
{
    "fcm_token": "<device FCM token string>",
    "device_type": "android" // optional: android | ios | web
}
```

```json
// Response (200)
{
    "success": true,
    "message": "FCM token updated successfully."
}
```

The Flutter app must call this endpoint on every login and every `onTokenRefresh` event from the Firebase SDK.

### 6. Notification Trigger Endpoint

**Route**: `POST /delivery-reports/send-courier-notification`  
**Route name**: `delivery-reports.send-courier-notification`  
**Auth**: web session  
**Controller**: `DeliveryReportsController@sendCourierNotification`  
**FormRequest**: `SendCourierNotificationRequest`

```json
// Request body — follow_up mode
{
  "delivery_id": 1234,
  "message_type": "follow_up"
}

// Request body — custom mode
{
  "delivery_id": 1234,
  "message_type": "custom",
  "message": "Hello {firstName}, regarding delivery {barcode}. Please action ASAP."
}
```

**Server-side message construction:**

- `follow_up`: title = `"Delivery Follow-Up"`, body = `"Hi {firstName}, this is a follow-up for delivery {barcode}. Kindly ensure prompt action. Thank you."`
- `custom`: title = `"Delivery Update"`, body = user's message with `{barcode}` replaced by the actual barcode value. `{firstName}` substitution is client-side in the preview only; the backend uses the actual `user->first_name`.

**Guards:**

1. Delivery must exist.
2. `delivery_status` must not be `DELIVERED`.
3. A courier must be assigned to the delivery batch.
4. The courier's user record must have a non-null `fcm_token`.

**FCM data payload** sent alongside every notification:

```json
{
    "barcode": "<barcode_value>",
    "delivery_id": "<id>",
    "action": "view_delivery"
}
```

---

## Mobile (Flutter) Side

**File**: `lib/core/services/push_notification_service.dart`

The Flutter app handles the full notification lifecycle via `PushNotificationService` — a singleton initialized from `app.dart`.

### Initialization Flow

```
main.dart
  └─ Firebase.initializeApp()
  └─ PushNotificationService.initBackgroundHandler()   ← registers background isolate handler

app.dart (_AutoSyncListener)
  └─ on startup (authenticated + online):
      └─ PushNotificationService.instance.init(apiClient)
  └─ on fresh login (authenticated + online):
      └─ PushNotificationService.instance.init(apiClient)
```

`init()` is idempotent — `_initialized` guard prevents double registration if called on both startup and login in the same session.

### What `init()` Does (in order)

1. **Requests permission** — `alert`, `badge`, `sound` (required on iOS; shown as rationale on Android 13+).
2. **Creates Android notification channel** — `high_importance_channel` / `Importance.max` for foreground alerts.
3. **Initializes `flutter_local_notifications`** — used to display foreground messages as system notifications.
4. **Fetches FCM token** — `FirebaseMessaging.instance.getToken()` and POSTs it to `/api/mbl/profile/fcm-token`.
5. **Listens to `onTokenRefresh`** — re-syncs token to backend whenever Firebase rotates it.
6. **Handles cold-start tap** — `getInitialMessage()` checks if the app was launched by tapping a notification; navigates to `/deliveries/:barcode` after a 500 ms delay (so the router is ready).
7. **Handles warm-start tap** — `onMessageOpenedApp` fires when a notification is tapped while the app is backgrounded; navigates immediately to `/deliveries/:barcode`.

### Background Handler

```dart
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
}
```

Registered via `FirebaseMessaging.onBackgroundMessage()` before `runApp`. Runs in a separate Dart isolate — no UI access.

### Foreground Message Handling

When a message arrives while the app is in the foreground (`FirebaseMessaging.onMessage`), `flutter_local_notifications` shows a system notification with:

- Channel: `high_importance_channel`
- Icon: `@mipmap/ic_launcher`
- iOS: `DarwinNotificationDetails`

The notification body mirrors the FCM `notification.title` / `notification.body` fields.

### Notification Tap → Deep Link

Both `getInitialMessage` and `onMessageOpenedApp` call `_navigateFromMessage(data)`:

```dart
void _navigateFromMessage(Map<String, dynamic> data) {
  if (data['action'] != 'view_delivery') return;
  final barcode = data['barcode'] as String?;
  if (barcode == null || barcode.isEmpty) return;
  GoRouter.of(rootNavigatorKey.currentContext!).push('/deliveries/$barcode');
}
```

The router navigates to `DeliveryDetailScreen` for the tapped barcode. Uses `push` (not `go`) so the courier can navigate back to whatever screen they were on.

### Token Sync to Backend

```dart
// POST /api/mbl/profile/fcm-token
{
  "fcm_token": "<token>",
  "device_type": "android" | "ios" | "web"
}
```

Errors are silently swallowed and logged to `ErrorLogService` — a token sync failure must never block login or the delivery flow.

### Required Flutter Files

| File                                               | Role                                                   |
| -------------------------------------------------- | ------------------------------------------------------ |
| `lib/core/services/push_notification_service.dart` | Full FCM lifecycle: permission, token, foreground, tap |
| `lib/firebase_options.dart`                        | Auto-generated by `flutterfire configure`              |
| `lib/main.dart`                                    | `Firebase.initializeApp` + background handler          |
| `lib/app.dart`                                     | Calls `init()` on startup and on fresh login           |
| `android/app/google-services.json`                 | Android Firebase config (public, safe to commit)       |
| `ios/Runner/GoogleService-Info.plist`              | iOS Firebase config (public, safe to commit)           |

> [!NOTE]
> `google-services.json` and `firebase_options.dart` contain only public routing identifiers (Project ID, App ID, Messaging Sender ID). They are safe to commit. The `firebase_credentials.json` server-side file is **never** in the Flutter project.

---

## Web UI — Delivery Reports Notification

A **Bell (🔔 Notify)** button appears in the courier column of the Delivery Reports table for rows where:

- A courier is assigned.
- The delivery is **not** in `DELIVERED` status.

### Notify Button States

The button has three possible states driven by two backend-provided flags: `courier_has_fcm_token` and `courier_has_active_session`.

| `courier_has_fcm_token` | `courier_has_active_session` | Button State       | Tooltip message                                                                                                  |
| ----------------------- | ---------------------------- | ------------------ | ---------------------------------------------------------------------------------------------------------------- |
| `true`                  | (any)                        | **Enabled** (blue) | — (no tooltip needed)                                                                                            |
| `false`                 | `false`                      | Disabled (grey)    | "Courier hasn't logged in to the mobile app yet. No device registered."                                          |
| `false`                 | `true`                       | Disabled (grey)    | "Courier is logged in but hasn't registered a device for push notifications. Ask them to reopen the mobile app." |

**`courier_has_fcm_token`** — whether `users.fcm_token` is non-null.  
**`courier_has_active_session`** — whether the courier's user has any active Sanctum tokens (`personal_access_tokens` rows), i.e. they are logged in to the mobile app.

### How These Flags Are Populated

Both flags originate from `DeliveryReportResource` (used by `DeliveryReportService`).

The repository eager-loads the courier's user with:

```php
// DeliveryRepository::withRelations()
'user' => fn ($q) => $q->withTrashed()
    ->select('id', 'name', 'first_name', 'last_name', 'fcm_token')
    ->withCount('tokens')
```

`withCount('tokens')` produces a `tokens_count` virtual attribute on the User model (counts rows in `personal_access_tokens`).

The resource then maps these to the API response:

```php
'courier_has_fcm_token'      => ($courier?->user?->getAttributes()['fcm_token'] ?? null) !== null,
'courier_has_active_session' => ($courier?->user?->tokens_count ?? 0) > 0,
```

### Data Flow for the Notify Button

```
DeliveryRepository::withRelations()
  └─ user: select(fcm_token) + withCount('tokens')
      │
      ▼
DeliveryReportResource::toArray() / transformDeliveryItem()
  └─ courier_has_fcm_token       ← fcm_token IS NOT NULL
  └─ courier_has_active_session  ← tokens_count > 0
      │
      ▼
DeliveryBatchMasterlist TypeScript type (batch.d.ts)
  └─ courier_has_fcm_token?: boolean
  └─ courier_has_active_session?: boolean
      │
      ▼
NotifyActionCell (delivery-report-columns.tsx)
  └─ renders button / disabled+tooltip based on both flags
```

Clicking the button opens the `CourierNotificationDialog` component (`resources/js/components/ui/reports/courier-notification-dialog.tsx`).

### Dialog Modes

| Mode        | Description                                                                             |
| ----------- | --------------------------------------------------------------------------------------- |
| `select`    | User picks between Quick Follow-Up or Custom Message                                    |
| `follow_up` | Shows a preview of the pre-defined follow-up message. One-click send.                   |
| `custom`    | Textarea with `{barcode}` auto-inserted, 500-char limit. User writes free-form message. |

### Column Implementation

`resources/js/components/columns/delivery-report-columns.tsx` — The courier name cell is rendered by the `CourierCellWithNotification` component, which owns the dialog open/close state via `useState`. This pattern is required because React hooks cannot be called inside column `cell` render functions directly.

---

## Account Migration / Re-Setup Checklist

Follow this checklist when:

- Moving to a new Firebase project / account
- Rotating the service account credentials
- Setting up on a new server

### Step 1 — Create or Locate the Firebase Project

1. Log in to [Firebase Console](https://console.firebase.google.com/).
2. Create a new project or select the existing one (`gdtms-v2-app`).
3. Enable **Cloud Messaging** (it is enabled by default for all projects).

### Step 2 — Generate a New Service Account Key

1. Go to **Project Settings → Service Accounts**.
2. Under **Firebase Admin SDK**, click **Generate new private key**.
3. Download the JSON file. It will look like:

    ```json
    {
      "type": "service_account",
      "project_id": "gdtms-v2-app",
      "private_key_id": "...",
      "private_key": "-----BEGIN RSA PRIVATE KEY-----\n...",
      "client_email": "firebase-adminsdk-fbsvc@gdtms-v2-app.iam.gserviceaccount.com",
      "client_id": "...",
      "auth_uri": "...",
      "token_uri": "...",
      ...
    }
    ```

4. Rename it to `firebase_credentials.json`.

### Step 3 — Place the Credentials File

Place the file at:

```
storage/app/firebase_credentials.json
```

> [!CAUTION]
> This path is already in `.gitignore`. Do not commit the file.

For production servers, transfer the file securely (SCP, secrets manager, or environment-injected file).

### Step 4 — Set the Environment Variable

Ensure `.env` contains:

```env
FIREBASE_CREDENTIALS=storage/app/firebase_credentials.json
```

For production (absolute path recommended):

```env
FIREBASE_CREDENTIALS=/var/www/gdtms-v2-web/storage/app/firebase_credentials.json
```

### Step 5 — Clear Config Cache

After placing the credentials file or changing the env key:

```bash
php artisan config:clear
php artisan cache:clear
```

If running under systemd, restart the queue worker so the new config is picked up:

```bash
sudo systemctl restart gdtms-queue-worker
```

### Step 6 — Update the Flutter App (If Changing Firebase Projects)

If the Firebase project changes (not just rotating service account keys), you must also update the Flutter app:

1. Download the new `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) from **Project Settings → Your Apps**.
2. Replace `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`.
3. Re-run `flutterfire configure --project=<new-project-id>` to overwrite `lib/firebase_options.dart`.
4. Rebuild and re-deploy the Flutter app.

> [!NOTE]
> If only rotating the service account key within the same `gdtms-v2-app` project on the backend, the Flutter app does **not** need to be updated. Device tokens remain valid.

### Step 7 — Verify

Test the token sync endpoint from a device running the Flutter app:

```bash
# Check that a courier's fcm_token is populated
php artisan tinker --execute "echo \App\Models\User::whereNotNull('fcm_token')->count() . ' users have FCM tokens';"
```

Send a test notification from the web UI (Delivery Reports → any non-delivered row with a courier → Bell icon).

---

## Troubleshooting

### "Courier hasn't logged in to the mobile app yet. No device registered."

Both `courier_has_fcm_token` and `courier_has_active_session` are `false`. The courier has never logged in to the Flutter app, or they logged in but the FCM token sync failed. They should open the mobile app and log in.

### "Courier is logged in but hasn't registered a device for push notifications."

`courier_has_active_session` is `true` (Sanctum token exists) but `courier_has_fcm_token` is `false`. This typically happens when:

- The courier logged in before the `fcm_token` column existed (migrated `2026_04_14`), so the initial login never synced a token.
- The `POST /api/mbl/profile/fcm-token` call failed or was not made by the mobile app on login.

**Resolution**: Ask the courier to close and reopen the mobile app. The Flutter app calls `/api/mbl/profile/fcm-token` on every login and on `onTokenRefresh`. Verify the mobile app is running a build that includes `PushNotificationService`.

### "Notification could not be delivered. The device token may be stale."

The FCM token stored in the DB is no longer valid (device uninstalled the app, cleared app data, or reinstalled without re-syncing). The courier must re-login on the mobile app to refresh the token.

### `MessagingException` in logs

Check `storage/logs/laravel.log` for entries tagged `FCM push notification failed`. Common causes:

- Invalid or expired credentials file.
- Wrong `project_id` in `firebase_credentials.json` (mismatch between file and `.env`).
- Firebase project has Cloud Messaging API disabled (enable it in Google Cloud Console).

### Config not reading new credentials file

```bash
php artisan config:clear
php artisan config:cache   # optional — only run in production
```

The `kreait/laravel-firebase` package reads the credentials path at boot time via `config/firebase.php`. A stale config cache will point to the old file.

### `courier_has_active_session` is always `false` even for logged-in couriers

The Sanctum `tokens_count` comes from `withCount('tokens')` in `DeliveryRepository::withRelations()`. If this is missing from the eager-load chain, `tokens_count` will always be `null` → treated as `0`. Check that `withCount('tokens')` is present on the user relationship in that method.

### Notification tap does nothing on Android/iOS

The Flutter `_navigateFromMessage` requires `rootNavigatorKey.currentContext` to be non-null. This is only set after the Flutter widget tree is rendered. On a cold-start tap, navigation is delayed 500 ms. If it still fails, check that `rootNavigatorKey` is set as the `navigatorKey` on `GoRouter` and that the app fully initialised before the delay elapsed.

### Google Cloud API Quota / Billing

The Firebase HTTP v1 API (used by kreait) communicates with `fcm.googleapis.com`. For high-volume notification sending, check the Cloud Messaging API quotas in the Google Cloud Console under **APIs & Services → Firebase Cloud Messaging API**.

---

## Frequently Asked Questions (FAQ)

**Q: Do I need a `.env` file or `firebase_credentials.json` in the Flutter Mobile App?**  
**A:** No. The mobile app acts strictly as the "Client". It only needs to receive push notifications and generate its own token, which it accomplishes using the public identifiers in `firebase_options.dart` and `google-services.json`. Sending the actual push notifications requires administrative access, which is why the `firebase_credentials.json` Service Account key is safely isolated on the Laravel server.

**Q: Is it safe to commit `google-services.json` and `firebase_options.dart` to the Flutter repository?**  
**A:** Yes. These files contain only public routing identifiers (Project ID, App ID, Messaging Sender ID) that instruct the Firebase SDK where to connect. You must **never** commit the `firebase_credentials.json` server-side file — that contains private root credentials.

**Q: What happens if a courier has multiple devices?**  
**A:** Currently, the system stores a single `fcm_token` as a nullable string column on the `users` table. Only the most recently synced device token will receive push notifications. If multi-device support is needed, the backend would need to migrate to a `user_device_tokens` one-to-many table.

**Q: Why is `courier_has_active_session` `true` but `courier_has_fcm_token` `false`?**  
**A:** The courier has a valid Sanctum session (they are logged in) but the FCM token sync never completed. This typically happens when the courier logged in before the `fcm_token` column was migrated (`2026_04_14`), or when the `POST /api/mbl/profile/fcm-token` call failed silently. Ask the courier to close and reopen the app to trigger a fresh token sync.

**Q: Does tapping a push notification work if the app was fully closed?**  
**A:** Yes. `PushNotificationService` calls `FirebaseMessaging.instance.getInitialMessage()` during `init()`. If the app was launched by tapping a notification, this returns the message and the app navigates to `/deliveries/:barcode` after a 500 ms delay (to ensure the router is mounted).

---

## Related Files

### Backend (Laravel — gdtms-v2-web)

| File                                                                           | Purpose                                                                 |
| ------------------------------------------------------------------------------ | ----------------------------------------------------------------------- |
| `app/Services/PushNotificationService.php`                                     | Injectable FCM service                                                  |
| `app/Http/Requests/UpdateFcmTokenRequest.php`                                  | Mobile token sync validation                                            |
| `app/Http/Requests/SendCourierNotificationRequest.php`                         | Web notification trigger validation                                     |
| `app/Http/Controllers/Dashboard/CourierManagement/CourierMobileController.php` | Mobile token sync handler (`updateFcmToken`)                            |
| `app/Http/Controllers/Dashboard/Reports/DeliveryReportsController.php`         | Web notification trigger handler                                        |
| `app/Repositories/DeliveryRepository.php`                                      | Eager-loads `fcm_token` + `withCount('tokens')` on user                 |
| `app/Http/Resources/DeliveryReportResource.php`                                | Maps `courier_has_fcm_token` and `courier_has_active_session`           |
| `app/Models/User.php`                                                          | `fcm_token` field (`$fillable`, `$hidden`)                              |
| `config/firebase.php`                                                          | kreait package config                                                   |
| `database/migrations/2026_04_14_000000_add_fcm_token_to_users_table.php`       | DB migration                                                            |
| `resources/js/types/modules/batch.d.ts`                                        | TypeScript type — `courier_has_fcm_token`, `courier_has_active_session` |
| `resources/js/components/ui/reports/courier-notification-dialog.tsx`           | Notification dialog (web)                                               |
| `resources/js/components/columns/delivery-report-columns.tsx`                  | Courier column with Notify button & differentiated tooltip              |
| `storage/app/firebase_credentials.json`                                        | Service account key (not in git)                                        |

### Mobile (Flutter — fsi-courier-app)

| File                                               | Purpose                                                           |
| -------------------------------------------------- | ----------------------------------------------------------------- |
| `lib/core/services/push_notification_service.dart` | Full FCM lifecycle: permission, token sync, foreground, deep-link |
| `lib/firebase_options.dart`                        | Auto-generated Firebase config (safe to commit)                   |
| `lib/main.dart`                                    | `Firebase.initializeApp` + background handler registration        |
| `lib/app.dart`                                     | Calls `init()` on startup and on fresh login                      |
| `android/app/google-services.json`                 | Android Firebase config (safe to commit)                          |
| `ios/Runner/GoogleService-Info.plist`              | iOS Firebase config (safe to commit)                              |

---

## FCM Token Resilience Contract

> Covers the scenario: **a courier has an active Sanctum session but their FCM token is stale, null, or permanently invalid.**

### Why Tokens Go Stale

FCM device tokens are not permanent. A courier's stored token becomes invalid when:

| Scenario                                                            | Effect on stored token                                               |
| ------------------------------------------------------------------- | -------------------------------------------------------------------- |
| App uninstalled / reinstalled                                       | Firebase deregisters the old token (UNREGISTERED)                    |
| Firebase internally rotates the token                               | Old token stops working; `onTokenRefresh` fires on device            |
| Courier denies notification permission on first run                 | Token is never generated; `users.fcm_token` stays `null`             |
| Token was never synced (app opened before backend endpoint existed) | `users.fcm_token` is `null` despite courier being logged in          |
| Courier hasn't opened the app since a token rotation                | Stored token is stale; device has the new one but hasn't sent it yet |

### What the Backend Does Automatically

`PushNotificationService::sendToUser()` handles each scenario:

| Condition                                                          | Behaviour                                                                                                                                                   |
| ------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `users.fcm_token` is `null`                                        | Skips FCM silently (returns `false`). Notification is **still stored** in the `database` channel.                                                           |
| FCM responds `UNREGISTERED` or `registration-token-not-registered` | **Clears `users.fcm_token` to `null`** so no further retries waste FCM quota. Logs a `warning`. Notification is **still stored** in the `database` channel. |
| Any other `MessagingException` (network, quota, misconfiguration)  | Logs a `warning`, returns `false`. Token is **not** cleared (transient error). Notification is **still stored** in the `database` channel.                  |
| FCM send succeeds                                                  | Returns `true`. Notification is stored **and** FCM delivery is confirmed.                                                                                   |

Key invariant: **the `database` channel notification (`$user->notify(...)`) is always written first, before the FCM call.** A broken FCM token can never drop a notification — the courier will always see it in the in-app notification list on their next app open.

### Mobile App Contract (required from `fsi-courier-app`)

The mobile app MUST uphold this contract to keep the token current:

1. **On every app startup** (not just first login) — call `POST /api/mbl/profile/fcm-token` with the result of `FirebaseMessaging.instance.getToken()`.
    ```dart
    // lib/app.dart — _AutoSyncListener
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await apiClient.post('/api/mbl/profile/fcm-token', body: {
        'fcm_token':   token,
        'device_type': Platform.isIOS ? 'ios' : 'android',
      });
    }
    ```
2. **On `onTokenRefresh`** — re-POST whenever Firebase rotates the token in the background.
    ```dart
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await apiClient.post('/api/mbl/profile/fcm-token', body: {
        'fcm_token':   newToken,
        'device_type': Platform.isIOS ? 'ios' : 'android',
      });
    });
    ```
3. **On fresh login** — `init()` always calls `getToken()` and POSTs even if the courier was previously logged in. This covers the case where the app was reinstalled between sessions.
4. **Errors are swallowed** — A failed token sync must never block login or any delivery workflow. Log to `ErrorLogService` and continue.

### Token Validity Diagnostic (Web Dashboard)

The Delivery Reports table exposes two flags per courier row for diagnosing push delivery issues:

| Flag                                                                 | Value                   | Meaning                                                                                                                                     |
| -------------------------------------------------------------------- | ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `courier_has_fcm_token: true`                                        | Token in DB             | FCM delivery will be attempted                                                                                                              |
| `courier_has_fcm_token: false` + `courier_has_active_session: true`  | No token, logged in     | Courier is online but notification permission was denied, or `onTokenRefresh` hasn't fired yet. Ask them to fully close and reopen the app. |
| `courier_has_fcm_token: false` + `courier_has_active_session: false` | No token, not logged in | Courier hasn't logged in to the mobile app yet.                                                                                             |

If `fcm_token` was cleared by the UNREGISTERED handler and the courier subsequently reopens the app, the startup token sync will re-populate `users.fcm_token` automatically — no manual intervention required.

### Source: `app/Services/PushNotificationService.php`

- `sendToUser(User, title, body, data)` — checks null → sends → catches UNREGISTERED → clears token
- `isTokenPermanentlyInvalid(string)` — private; matches `UNREGISTERED`, `registration-token-not-registered`, `Requested entity was not found`
- Token-sync endpoint: `POST /api/mbl/profile/fcm-token` → `CourierMobileController@updateFcmToken` → `UpdateFcmTokenRequest`

---

## Notification API Response Shape (v2.4)

> **Reference**: `GET /api/mbl/notifications` — `app/Http/Controllers/Dashboard/CourierManagement/CourierNotificationController.php`

Every item in the `data[]` array has this shape. Fields null when not applicable to the notification type.

```jsonc
{
    "id": "UUID", // use for mark-as-read
    "type": "string", // see type table below
    "message": "string", // human-readable
    "transaction_reference": "string|null",
    "delivery_references": ["string"], // barcodes, may be empty
    "amount": 1234.5, // float | null
    // Payout approval / rejection only:
    "stage": "ops|hr|null",
    "rejection_reason": "string|null",
    // Dispatch (new_dispatch type) only:
    "dispatch_code": "string|null",
    "partial_code": "string|null",
    "delivery_count": 15, // int | null
    "action": "new_dispatch|null",
    // Read state:
    "date": "2026-04-14T08:00:00.000000Z",
    "read": false,
    "read_at": "ISO 8601|null",
}
```

### Notification Types

| `type`                  | Trigger                                  | Key fields                                                     |
| ----------------------- | ---------------------------------------- | -------------------------------------------------------------- |
| `new_dispatch`          | DOP batch dispatched to courier          | `dispatch_code`, `partial_code`, `delivery_count`, `action`    |
| `payout_requested`      | Courier submits payout request           | `transaction_reference`, `delivery_references`, `amount`       |
| `payout_approved`       | OPS or HR approves payout                | `transaction_reference`, `amount`, `stage` (`ops`\|`hr`)       |
| `payout_rejected`       | OPS or HR rejects payout                 | `transaction_reference`, `amount`, `stage`, `rejection_reason` |
| `payout_paid`           | HR marks payout as paid (money released) | `transaction_reference`, `delivery_references`, `amount`       |
| `transaction_due_today` | Deliveries due today                     | `delivery_references`                                          |
| `transaction_due_soon`  | Deliveries due soon                      | `delivery_references`                                          |

### Notification Endpoints

| Method | Path                                       | Description                                                                                                        |
| ------ | ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------ |
| `GET`  | `/api/mbl/notifications`                   | Paginated list (most recent first). Query: `page`, `per_page` (max 50). Response includes `unread_count` + `meta`. |
| `GET`  | `/api/mbl/notifications/unread-count`      | Badge count — `{ success, count }`                                                                                 |
| `POST` | `/api/mbl/notifications/{id}/mark-as-read` | Mark single by UUID                                                                                                |
| `POST` | `/api/mbl/notifications/mark-all-as-read`  | Mark all unread as read                                                                                            |
