# TASK.md — GDTMS v2 Courier Mobile App

## NativePHP v3 | Laravel 12 | FSI Courier

> **Project**: Greenfield NativePHP v3 mobile application for FSI couriers.
> **Purpose**: Courier-facing mobile client that consumes the existing GDTMS v2 web app's dedicated mobile REST API (`/api/mbl`).
> **Approach**: No server-side logic is duplicated. The mobile app is purely an API consumer.

---

## Table of Contents

1. [Project Context](#1-project-context)
2. [Project Setup](#2-project-setup)
3. [Folder & File Structure](#3-folder--file-structure)
4. [Shared Infrastructure](#4-shared-infrastructure)
5. [Screen Implementation Tasks](#5-screen-implementation-tasks)
6. [Navigation Architecture](#6-navigation-architecture)
7. [Build Order](#7-build-order)
8. [API Integration Checklist](#8-api-integration-checklist)
9. [Testing Plan](#9-testing-plan)
10. [Environment & Deployment](#10-environment--deployment)
11. [Future Backlog](#11-future-backlog)
12. [Web App Reference Files](#12-web-app-reference-files)

---

## 1. Project Context

### Existing Web App Stack

| Layer          | Technology                                       |
| -------------- | ------------------------------------------------ |
| Framework      | Laravel 12 + PHP 8.3                             |
| Frontend       | React 19 + TypeScript + Inertia v2 + Tailwind v4 |
| Database       | MySQL                                            |
| Auth           | Laravel Sanctum (web sessions + mobile tokens)   |
| Testing        | Pest v3                                          |
| Base URL (dev) | `http://web-admin-fsi-courier-internal.test`     |

### Mobile App Stack (This Project)

| Layer      | Technology                                     |
| ---------- | ---------------------------------------------- |
| Framework  | NativePHP v3                                   |
| Language   | PHP 8.3                                        |
| UI         | Blade + NativePHP Mobile Components            |
| Storage    | NativePHP Secure Storage (Keychain / Keystore) |
| HTTP       | Laravel HTTP Client (Guzzle)                   |
| Auth       | Sanctum Bearer Token                           |
| Navigation | Bottom Tab Bar (5 tabs)                        |

### Why NativePHP v3?

The team uses Laravel/PHP across the stack. NativePHP allows Blade + PHP UI, access to native device APIs (camera, secure storage, device info), and eliminates JS framework overhead entirely.

### API Overview

- All mobile endpoints: `/api/mbl` prefix
- Auth: `Authorization: Bearer {token}` on all authenticated requests
- Backend identifies the courier from the token — **no courier ID is ever needed in the URL**
- Token expiry: 30 days (auto-pruned weekly)

### Critical Pre-Work: Real API Field Names

> ⚠️ The `DeliveryStatusUpdateRequest.php` in the web app uses **different field names** than the original spec document. Always use the real fields below.

**Real POD Update Fields (`DeliveryStatusUpdateRequest.php`):**

| Field                 | Type   | Notes                                                                                                |
| --------------------- | ------ | ---------------------------------------------------------------------------------------------------- |
| `delivery_status`     | enum   | `delivered` \| `osa` \| `rts`                                                                        |
| `note`                | text   | Optional                                                                                             |
| `recipient`           | string | **Required** if `delivery_status = delivered`                                                        |
| `relationship`        | string | Optional (e.g. "spouse", "guard")                                                                    |
| `reason`              | string | Optional — for `rts`/`osa`                                                                           |
| `placement_type`      | string | Optional (e.g. "door", "reception")                                                                  |
| `delivery_images`     | array  | Up to 10 items: `{type, base64_image}`. Types: `package \| recipient \| location \| damage \| other` |
| `recipient_signature` | base64 | Optional                                                                                             |

---

## 2. Project Setup

### 2.1 Initialize Project

```bash
# Create fresh Laravel 12 project (separate from web admin)
composer create-project laravel/laravel gdtms-courier-mobile

cd gdtms-courier-mobile

# Install NativePHP for Mobile (v3)
composer require nativephp/mobile

# Publish NativePHP config and scaffolding
php artisan native:install --mobile

# Install required packages
composer require ramsey/uuid       # UUID v4 for idempotency keys
# guzzlehttp/guzzle is already bundled with Laravel
```

### 2.2 Required Packages

| Package             | Purpose                                                |
| ------------------- | ------------------------------------------------------ |
| `nativephp/mobile`  | Core mobile framework — native bridge, storage, camera |
| `ramsey/uuid`       | UUID v4 generation for idempotency keys                |
| `guzzlehttp/guzzle` | HTTP client (already bundled with Laravel)             |

### 2.3 Environment Variables (`.env`)

```env
APP_NAME="FSI Courier"
APP_ENV=local
APP_DEBUG=true

# Mobile API — switch between dev/prod here
MOBILE_API_BASE_URL=http://web-admin-fsi-courier-internal.test/api/mbl
MOBILE_APP_VERSION=1.0.0

# NativePHP app identity
NATIVEPHP_APP_ID=com.fsi.courier
NATIVEPHP_APP_NAME="FSI Courier"
NATIVEPHP_APP_VERSION=1.0.0
NATIVEPHP_APP_BUILD=1
```

### 2.4 NativePHP Config (`config/nativephp.php`)

Key values to configure:

- `app_id` → `NATIVEPHP_APP_ID`
- `version` → `NATIVEPHP_APP_VERSION`
- `permissions` → `camera`, `secure_storage`
- `orientations` → portrait only (courier field use)

### 2.5 Custom App Config (`config/mobile.php`)

```php
return [
    'api_base_url' => env('MOBILE_API_BASE_URL', 'https://fsi-courier.com/api/mbl'),
    'app_version'  => env('MOBILE_APP_VERSION', '1.0.0'),
    'app_debug'    => env('APP_DEBUG', false),
    'per_page'     => 20,
    'token_key'    => 'courier_token',
    'courier_key'  => 'courier_data',
    'settings_key' => 'app_settings',
];
```

### 2.6 Navigation Shell

**Decision: Bottom Tab Bar (5 tabs)**

> Justification: Couriers use the app one-handed in the field. Bottom tab bar thumbs-accessible layout is standard for task-focused delivery apps (same pattern as Lalamove, Grab Express).

| Tab        | Icon      | Route         |
| ---------- | --------- | ------------- |
| Home       | Dashboard | `/dashboard`  |
| Dispatches | Inbox     | `/dispatches` |
| Deliveries | Package   | `/deliveries` |
| Wallet     | Wallet    | `/wallet`     |
| Profile    | Person    | `/profile`    |

Auth screens (Login, Reset Password) → Full-screen stack, **no tab bar**.

---

## 3. Folder & File Structure

```
gdtms-courier-mobile/
├── app/
│   ├── Http/
│   │   ├── Controllers/
│   │   │   ├── Auth/
│   │   │   │   ├── LoginController.php
│   │   │   │   └── ResetPasswordController.php
│   │   │   ├── Dashboard/
│   │   │   │   └── DashboardController.php
│   │   │   ├── Dispatch/
│   │   │   │   ├── DispatchListController.php
│   │   │   │   ├── DispatchEligibilityController.php
│   │   │   │   └── DispatchAcceptController.php
│   │   │   ├── Delivery/
│   │   │   │   ├── DeliveryListController.php
│   │   │   │   ├── DeliveryDetailController.php
│   │   │   │   ├── DeliveryUpdateController.php
│   │   │   │   └── CompletedDeliveryController.php
│   │   │   ├── Wallet/
│   │   │   │   ├── WalletController.php
│   │   │   │   ├── PayoutRequestController.php
│   │   │   │   └── PayoutDetailController.php
│   │   │   └── Profile/
│   │   │       └── ProfileController.php
│   │   └── Middleware/
│   │       └── AuthMiddleware.php
│   └── Services/
│       ├── ApiClient.php           # HTTP client with auth + error handling
│       ├── AuthStorage.php         # Secure token + courier persistence
│       ├── IdempotencyKey.php      # UUID v4 generator
│       ├── DeviceInfo.php          # NativePHP device bridge
│       └── AppSettings.php         # User preferences (auto-accept, etc.)
├── resources/
│   └── views/
│       ├── layouts/
│       │   ├── app.blade.php       # Authenticated shell with bottom tabs
│       │   └── auth.blade.php      # Full-screen auth layout (no tabs)
│       ├── components/
│       │   ├── bottom-tab-bar.blade.php
│       │   ├── earnings-breakdown.blade.php  # Reusable 3-line rate/fee/net display
│       │   ├── status-badge.blade.php
│       │   ├── loading-spinner.blade.php
│       │   ├── error-state.blade.php
│       │   └── empty-state.blade.php
│       ├── auth/
│       │   ├── login.blade.php
│       │   └── reset-password.blade.php
│       ├── dashboard/
│       │   └── index.blade.php
│       ├── dispatch/
│       │   ├── index.blade.php       # Pending dispatches list
│       │   ├── eligibility.blade.php # Scan + eligibility check
│       │   └── accept.blade.php      # Manual accept/reject screen
│       ├── delivery/
│       │   ├── index.blade.php       # Active (pending) deliveries
│       │   ├── detail.blade.php      # Single delivery full view
│       │   ├── update.blade.php      # Update status + POD
│       │   └── completed.blade.php   # Debug-only completed list
│       ├── wallet/
│       │   ├── index.blade.php       # Wallet overview + history
│       │   ├── request.blade.php     # Create payout request
│       │   └── detail.blade.php      # Payout request detail
│       └── profile/
│           └── index.blade.php
├── routes/
│   └── mobile.php                  # All app routes
└── tests/
    ├── Unit/
    │   ├── ApiClientTest.php
    │   ├── AuthStorageTest.php
    │   ├── IdempotencyKeyTest.php
    │   └── AppSettingsTest.php
    └── Feature/
        ├── Auth/
        │   ├── LoginTest.php
        │   └── ResetPasswordTest.php
        ├── Dispatch/
        │   ├── DispatchListTest.php
        │   └── DispatchAcceptTest.php
        ├── Delivery/
        │   └── DeliveryUpdateTest.php
        └── Wallet/
            └── PayoutRequestTest.php
```

---

## 4. Shared Infrastructure

> Build ALL of these before starting any screen. Every screen depends on at least one of these services.

### 4.1 `ApiClient` — `app/Services/ApiClient.php`

**Purpose:** Single HTTP client for all API calls. Auto-attaches token, handles all errors centrally.

**Key responsibilities:**

- Base URL from `config('mobile.api_base_url')`
- Always send `Accept: application/json` and `Authorization: Bearer {token}` headers
- `401` → call `AuthStorage::clearAll()` + redirect to `/login` with flash `"You've been logged out"`
- `422` → return `['errors' => [...]]` structured array for field-level display
- `429` → return `['rate_limited' => true, 'message' => 'Too many attempts, please wait']`
- `500/503` → return `['server_error' => true, 'message' => 'Something went wrong, try again']`
- `ConnectionException` → return `['network_error' => true, 'message' => 'No connection']`

**Interface:**

```php
class ApiClient {
    public function get(string $endpoint, array $query = []): array
    public function post(string $endpoint, array $data = []): array
    public function patch(string $endpoint, array $data = []): array
    public function postMultipart(string $endpoint, array $fields, array $files = []): array
    private function buildHeaders(): array
    private function handleError(Response $response): array
}
```

**- [x] Task:** Implement `ApiClient` with all error handling cases above.

---

### 4.2 `AuthStorage` — `app/Services/AuthStorage.php`

**Purpose:** Secure persistent storage of token and courier data using NativePHP's native secure storage (Keychain on iOS, Keystore on Android). Never use plain `session()` or files.

**Interface:**

```php
class AuthStorage {
    public function setToken(string $token): void
    public function getToken(): ?string
    public function setCourier(array $courier): void
    public function getCourier(): ?array
    public function isAuthenticated(): bool
    public function clearAll(): void  // Called on 401 or explicit logout
}
```

**Storage:** Uses `Native::secureStorage()->set(key, value)`

**- [x] Task:** Implement `AuthStorage` using NativePHP secure storage.

---

### 4.3 `IdempotencyKey` — `app/Services/IdempotencyKey.php`

**Purpose:** Generate UUID v4 keys to prevent duplicate operations on retry.

**Interface:**

```php
class IdempotencyKey {
    public static function generate(): string        // Returns Str::uuid()->toString()
    public static function forDispatch(string $dispatchCode): string  // Cached per dispatch
}
```

**Used by:** `check-dispatch-eligibility`, `accept-dispatch`

> ⚠️ A **new** `client_request_id` must be generated for the accept call — it must be different from the eligibility check key.

**- [x] Task:** Implement `IdempotencyKey` service.

---

### 4.4 `DeviceInfo` — `app/Services/DeviceInfo.php`

**Purpose:** Provide device metadata for the `accept-dispatch` payload via NativePHP native bridge.

**Interface:**

```php
class DeviceInfo {
    public function toArray(): array {
        return [
            'os'           => System::isAndroid() ? 'android' : 'ios',
            'app_version'  => config('mobile.app_version'),
            'device_model' => json_decode(Device::getInfo())->model ?? 'Unknown',
            'device_id'    => Device::getId(),
        ];
    }
}
```

> **NativePHP v3 note:** `System::os()`, `System::deviceModel()`, and `System::deviceId()` do not exist in v3.
> Use `System::isAndroid()` / `System::isIos()` for OS detection, `Device::getInfo()` (returns JSON string) for model, and `Device::getId()` for device ID.

**- [x] Task:** Implement `DeviceInfo` service using NativePHP system bridge.

---

### 4.5 `AppSettings` — `app/Services/AppSettings.php`

**Purpose:** Persist user preferences using NativePHP storage.

**Interface:**

```php
class AppSettings {
    public function setAutoAcceptDispatch(bool $value): void
    public function getAutoAcceptDispatch(): bool  // Default: false
    public function set(string $key, mixed $value): void
    public function get(string $key, mixed $default = null): mixed
}
```

> Auto-accept is **OFF by default**. Courier must explicitly enable it in Profile settings.

**- [x] Task:** Implement `AppSettings` service.

---

### 4.6 `AuthMiddleware` — `app/Http/Middleware/AuthMiddleware.php`

**Purpose:** Guard all authenticated routes. Redirect unauthenticated users to login.

```php
class AuthMiddleware {
    public function handle($request, $next) {
        if (!app(AuthStorage::class)->isAuthenticated()) {
            return redirect('/login')->with('message', 'Please log in to continue.');
        }
        return $next($request);
    }
}
```

Applied to all routes **except** `/login` and `/reset-password`.

**- [x] Task:** Implement and register `AuthMiddleware`.

---

### 4.7 Shared Blade Components

| Component                      | Purpose                                                         |
| ------------------------------ | --------------------------------------------------------------- |
| `earnings-breakdown.blade.php` | Reusable 3-line earnings display (rate / coordinator fee / net) |
| `status-badge.blade.php`       | Colored badge for delivery/wallet statuses                      |
| `loading-spinner.blade.php`    | Loading state indicator                                         |
| `error-state.blade.php`        | Error state with retry button                                   |
| `empty-state.blade.php`        | Empty list state with icon + message                            |
| `bottom-tab-bar.blade.php`     | 5-tab bottom navigation bar                                     |

> The `earnings-breakdown` component must always display:
>
> ```
> Delivery Rate:     ₱150.00
> Coordinator Fee:  -₱15.00
> Net Amount:        ₱135.00
> ```

**- [x] Task:** Create all shared Blade components listed above.

---

## 5. Screen Implementation Tasks

### Phase 1 — Authentication

---

#### Screen 1.1 — Login

**Route:** `GET|POST /login`
**Controller:** `Auth/LoginController.php`
**View:** `auth/login.blade.php`
**Layout:** `auth.blade.php` (no tab bar)

**API Call:** `POST /login`

```json
{
    "phone_number": "09xxxxxxxxx",
    "password": "...",
    "device_name": "Mobile App",
    "device_identifier": "<DeviceInfo::deviceId()>",
    "device_type": "android|ios",
    "app_version": "1.0.0"
}
```

**UI Elements:**

- Phone number input field
- Password field with show/hide toggle
- "Login" button
- "Forgot Password?" link → `/reset-password`

**States:**
| State | Behavior |
|---|---|
| Loading | Spinner on button, inputs disabled |
| 401 | Inline error: "Invalid phone or password" |
| 422 | Field-level inline validation errors |
| 429 | "Too many attempts, please wait" + countdown timer |
| Success | Store token + courier via `AuthStorage` → redirect `/dashboard` |

**Business Rules:**

- Rate limit: 5 attempts / 5 min
- On success: replace navigation history (no back button to login)
- Session is revoked on new login — backend handles, no client action needed

**- [x] Task:** Build Login screen with all states above.

---

#### Screen 1.2 — Reset Password

**Route:** `GET|POST /reset-password`
**Controller:** `Auth/ResetPasswordController.php`
**View:** `auth/reset-password.blade.php`
**Layout:** `auth.blade.php`

**API Call:** `POST /reset-password`

```json
{
    "courier_code": "CC99999",
    "new_password": "...",
    "new_password_confirmation": "..."
}
```

**UI Elements:**

- Courier code input (e.g. CC99999)
- New password field
- Confirm password field
- "Reset Password" button

**States:**
| State | Behavior |
|---|---|
| Loading | Spinner, inputs disabled |
| 422 | Field-level inline errors |
| 404 | "Courier not found" error |
| Success | Flash success message → redirect to `/login` |

**- [x] Task:** Build Reset Password screen.

---

### Phase 2 — Dashboard

---

#### Screen 2.1 — Dashboard

**Route:** `GET /dashboard`
**Controller:** `Dashboard/DashboardController.php`
**View:** `dashboard/index.blade.php`
**Layout:** `app.blade.php`

**API Call:** `GET /dashboard-summary`

**UI Sections:**

1. Courier greeting: `"Good morning, {first_name}"`
2. Stats grid (2×2):
    - Total Deliveries | Pending Deliveries
    - Total Earnings (₱) | Pending Payouts (₱)
3. Status chips: pending / delivered / rts / osa counts
4. Recent Deliveries: last 5 items — tracking number, status badge, recipient name (tappable → `/deliveries/{id}`)
5. Quick action buttons: `"View Dispatches"` → `/dispatches` | `"View Deliveries"` → `/deliveries`

**Earnings display (summary area):**

```
Total Earnings:    ₱67,500.00
Pending Payouts:   ₱5,000.00
Approved Payouts:  ₱62,500.00
```

**States:** Loading skeleton cards, error state with retry, pull-to-refresh.

**- [x] Task:** Build Dashboard screen with stats, recent deliveries, quick actions.

---

### Phase 3 — Dispatches

---

#### Screen 3.1 — Pending Dispatches List

**Route:** `GET /dispatches`
**Controller:** `Dispatch/DispatchListController.php`
**View:** `dispatch/index.blade.php`

**API Call:** `GET /pending-dispatches`

**UI Elements:**

- List of dispatch cards:
    - `dispatch_code`
    - `total_items` count
    - Status badge
    - `dispatched_at` date
- **"Scan Dispatch" button** (prominent, top-right) → opens NativePHP barcode scanner → scanned code passed to `/dispatches/eligibility?dispatch_code={code}`
- Empty state: `"No pending dispatches"`

**Navigation:**

- Tap card → `/dispatches/eligibility?dispatch_code={code}`
- Scan button → barcode scan → same eligibility route

**States:** Loading, empty, error with retry, pull-to-refresh.

**- [x] Task:** Build Dispatches list with barcode scan integration.

---

#### Screen 3.2 — Dispatch Eligibility Check

**Route:** `GET|POST /dispatches/eligibility`
**Controller:** `Dispatch/DispatchEligibilityController.php`
**View:** `dispatch/eligibility.blade.php`

**API Call:** `POST /check-dispatch-eligibility`

```json
{
    "dispatch_code": "DISPATCH-001",
    "client_request_id": "<uuid-v4>"
}
```

**Flow:**

```
Arrive at screen (from list tap or barcode scan)
        ↓
Generate idempotency key → call check-dispatch-eligibility
        ↓
   [Not Eligible]                      [Eligible]
   Show error: "Not eligible: {reason}"     ↓
   Back button only              Check AppSettings::getAutoAcceptDispatch()
                                          ↓
                           [Auto-Accept = ON]         [Auto-Accept = OFF]
                                  ↓                          ↓
                       Show "Accepting..." overlay    Show manual screen
                       Auto-call accept-dispatch       with dispatch details
                       (new idempotency key)           Accept / Reject buttons
                                  ↓
                       "Dispatch Accepted!" overlay
                                  ↓
                       Navigate to /deliveries
```

**Manual Accept Screen UI (auto-accept OFF):**

- Dispatch details: code, total items, client name, area
- Scrollable earnings preview for dispatch items (3-line breakdown per item)
- Green **"Accept Dispatch"** button
- Grey/Red **"Reject"** button → confirmation modal: `"Are you sure you want to reject?"`

**Business Rules:**

- New `client_request_id` generated per eligibility check
- Separate new `client_request_id` generated for the accept call (never reuse)
- If auto-accept ON: courier cannot intervene after eligibility confirmed
- `device_info` payload must use `DeviceInfo::toArray()`

**States:** Loading eligibility check, auto-accepting state, manual review state, success overlay, error.

**- [x] Task:** Build Eligibility screen with both auto-accept and manual flows.

---

#### Screen 3.3 — Accept Dispatch (Manual Path)

**Route:** `POST /dispatches/accept`
**Controller:** `Dispatch/DispatchAcceptController.php`
**View:** `dispatch/accept.blade.php`

**API Call:** `POST /accept-dispatch`

```json
{
    "dispatch_code": "DISPATCH-001",
    "client_request_id": "<new-uuid-v4>",
    "device_info": {
        "os": "android|ios",
        "app_version": "1.0.0",
        "device_model": "...",
        "device_id": "..."
    }
}
```

**On Success:**

- Display accepted dispatch summary (item count + total earnings preview)
- Navigate to `/deliveries` (refresh delivery list)

**Error Handling:**
| Error | Message |
|---|---|
| 409 / already accepted | `"Dispatch already accepted"` toast → navigate to `/deliveries` |
| 403 | `"You are not eligible for this dispatch"` |
| 400 | Show message from API `message` field |

**- [x] Task:** Build Accept Dispatch screen for manual path; handle all error cases.

---

### Phase 4 — Deliveries

---

#### Screen 4.1 — Active Deliveries List

**Route:** `GET /deliveries`
**Controller:** `Delivery/DeliveryListController.php`
**View:** `delivery/index.blade.php`

**API Call:** `GET /deliveries?status=pending&per_page=20&page={n}`

> ⚠️ This screen shows **ONLY pending deliveries**. No status filter tabs. Completed deliveries are debug-only.

**Sorting:** `created_at ASC` — oldest undelivered at top = most urgent first.

**UI Elements:**

- Delivery cards:
    - Tracking number
    - Recipient name (truncated)
    - Address (truncated)
    - Status badge
    - Age indicator (how old the delivery is)
- Search bar (client-side filter on loaded data — by tracking number or recipient name)
- Infinite scroll / pagination
- Pull-to-refresh
- Empty state: `"All deliveries completed! ✓"`

**Navigation:** Tap card → `/deliveries/{id}`

**- [x] Task:** Build Active Deliveries list — pending only, urgency sorted, paginated.

---

#### Screen 4.2 — Delivery Detail

**Route:** `GET /deliveries/{id}`
**Controller:** `Delivery/DeliveryDetailController.php`
**View:** `delivery/detail.blade.php`

**API Call:** `GET /deliveries/{id}`

**UI Sections:**

1. Header: tracking number + large status badge
2. Recipient section: name, address, phone (tap-to-call via NativePHP)
3. Package: item description, dispatch code, rate type label (Express Metro / Express Province / Traditional Metro / Traditional Province)
4. Earnings Breakdown (always shown, use `earnings-breakdown` component):
    ```
    Delivery Rate:     ₱150.00
    Coordinator Fee:  -₱15.00
    Net Amount:        ₱135.00
    ```
5. Remarks (if any)
6. POD section (if delivered): delivery images + recipient name + relationship
7. Delivered At timestamp (if delivered)
8. **"Update Status" button** — only shown if `status === pending`

**Navigation:**

- "Update Status" → `/deliveries/{id}/update`
- Back → `/deliveries`

**- [x] Task:** Build Delivery Detail screen with all sections including tap-to-call.

---

#### Screen 4.3 — Update Delivery Status + POD

**Route:** `GET|PATCH /deliveries/{id}/update`
**Controller:** `Delivery/DeliveryUpdateController.php`
**View:** `delivery/update.blade.php`

**API Call:** `PATCH /deliveries/{id}` (multipart/form-data for images)

**Real Request Fields:**
| Field | Requirement |
|---|---|
| `delivery_status` | Required: `delivered` \| `rts` \| `osa` |
| `note` | Optional |
| `recipient` | **Required** when `delivered` |
| `relationship` | Optional |
| `reason` | Required when `rts` or `osa` |
| `placement_type` | Optional |
| `delivery_images[]` | Array: `{type, base64_image}` — up to 10, at least 1 required when `delivered` |
| `recipient_signature` | Optional base64 |

**UI — Status Selector (segmented control):**

```
[ Delivered ] [ Return to Sender ] [ Out of Service Area ]
```

**UI when "Delivered" selected:**

- Recipient name field (required)
- Relationship field (optional)
- Placement type picker (optional): `door`, `reception`, etc.
- Note/remarks field (optional)
- Photo section: up to 10 photos via NativePHP camera
    - Each photo tagged by type: `Package | Recipient | Location | Damage | Other`
    - At least 1 photo required before submit
- Signature pad (optional — NativePHP canvas)

**UI when "RTS" or "OSA" selected:**

- Reason field (required)
- Note field (optional)
- Photos optional

**Client-side Validation (before API call):**

- `delivered` → recipient name filled AND at least 1 delivery image → else: `"Recipient name and at least 1 photo are required"`
- `rts`/`osa` → reason field filled

**Image Upload:** Use multipart/form-data for large images to avoid payload size issues.

**States:** Loading, inline validation errors, success overlay → back to `/deliveries`.

**- [x] Task:** Build Update Delivery screen — all three status paths, photo capture, client-side validation.

---

#### Screen 4.4 — Completed Deliveries (Debug Only)

**Route:** `GET /deliveries/completed`
**Controller:** `Delivery/CompletedDeliveryController.php`
**View:** `delivery/completed.blade.php`

> 🔒 **Access Guard:** Only accessible when `config('mobile.app_debug') === true`. If `APP_DEBUG=false`, redirect to `/deliveries` with message `"Not available in production."`

**Purpose:** Developer view — shows delivered/rts/osa deliveries that would be included in a payout request.

**API Call:** `GET /deliveries?status=delivered&per_page=50`

**UI Elements:**

- Red **"⚠️ DEBUG VIEW"** banner at top
- `"This data is for development preview only"` notice
- List: status, tracking number, net amount per delivery
- Running total of earnings at bottom (sum of `net_amount`)

> Tab bar entry for this screen is **hidden when `APP_DEBUG=false`**.

**- [x] Task:** Build Completed Deliveries debug screen with access guard.

---

### Phase 5 — Wallet

---

#### Screen 5.1 — Wallet Overview + History

**Route:** `GET /wallet`
**Controller:** `Wallet/WalletController.php`
**View:** `wallet/index.blade.php`

**API Calls:**

- `GET /dashboard-summary` — for balance summary at top
- `GET /payment-requests` — for history list (see note below)

> ⚠️ **Note:** The current API spec only shows `POST /payment-request` for creating but **no `GET /payment-requests` list endpoint**. This screen assumes the backend will add a `GET /payment-requests` endpoint for history. If unavailable at time of build, the Wallet screen shows the creation form only and uses locally-cached request data post-creation. Flag this to the backend team.

**UI Sections:**

**1. Balance Summary Card:**

```
Total Earnings:    ₱XX,XXX.XX
Pending Payouts:   ₱X,XXX.XX
Approved Payouts:  ₱XX,XXX.XX
```

**2. `"+ Request Payout"` button** → `/wallet/request`

**3. Payout History List** (sorted newest first):

- Per card: `request_code`, date range, status badge (color-coded), `total_deliveries` count, `net_amount`
- Tap → `/wallet/{id}`

**4. Empty state:** `"No payout requests yet."`

**Status Badge Colors:**
| Status | Color |
|---|---|
| `pending` | Yellow / Amber |
| `ops_approved` | Blue |
| `hr_approved` | Purple |
| `paid` | Green |
| `rejected` | Red |

**- [x] Task:** Build Wallet overview with balance summary and payout history list. Flag missing GET endpoint to backend team.

---

#### Screen 5.2 — Create Payout Request

**Route:** `GET|POST /wallet/request`
**Controller:** `Wallet/PayoutRequestController.php`
**View:** `wallet/request.blade.php`

**API Call:** `POST /payment-request`

```json
{
    "from_date": "2025-01-01",
    "to_date": "2025-01-31"
}
```

**UI Elements:**

1. From Date picker (NativePHP native date picker)
2. To Date picker
3. **Required Disclaimer Banner** (must always be visible before submit):

    > ⚠️ **Note:** The payout amount shown is an estimate based on current delivery data. The final amount may be adjusted due to pending penalties, rate corrections, or deductions applied by Operations. The amount is subject to change until HR approval is complete.

4. **"Submit Payout Request"** button

**Validation:**

- `from_date` must be before `to_date`
- Both dates required

**States:**
| State | Behavior |
|---|---|
| 422 | Inline field errors |
| 400 | `"No eligible deliveries found for the specified date range"` |
| Success | Navigate to `/wallet/{new_request_id}` (payout detail) |

**- [x] Task:** Build Create Payout Request screen with disclaimer banner.

---

#### Screen 5.3 — Payout Request Detail

**Route:** `GET /wallet/{id}`
**Controller:** `Wallet/PayoutDetailController.php`
**View:** `wallet/detail.blade.php`

**Data source:** Locally cached response from creation, or fetched from history endpoint when available.

**UI Sections:**

1. Header: `request_code`, status badge, submitted date
2. Date range: `"Jan 1 – Jan 31, 2025"`
3. Summary:
    ```
    Total Deliveries:        100
    Gross Amount:            ₱15,000.00
    Coordinator Deductions:  -₱1,500.00
    Net Amount:              ₱13,500.00
    ```
4. **Disclaimer** (shown while `status !== paid`):
    > ⚠️ Amount may change pending penalty reviews and operations approval.
5. Items list: per-delivery breakdown (tracking number, rate, coordinator fee, net)
6. Approval timeline: OPS and HR approval steps (if available in response)

**- [x] Task:** Build Payout Request Detail screen with disclaimer and items list.

---

### Phase 6 — Profile

---

#### Screen 6.1 — Profile + Settings

**Route:** `GET|POST /profile`
**Controller:** `Profile/ProfileController.php`
**View:** `profile/index.blade.php`

**Data source:** From `AuthStorage::getCourier()` — no API call needed.

**UI Sections:**

**1. Courier Info:**

- Full name
- Courier code (e.g. CC99999)
- Phone number
- Email (if available)
- Branch
- Account status badge

**2. App Settings:**

- **Auto-Accept Dispatch toggle** (ON/OFF)
    - Label: `"Auto-Accept Eligible Dispatches"`
    - Description: `"When enabled, eligible dispatches will be accepted automatically when scanned. When disabled, you will be prompted to accept or reject."`
    - Stored via `AppSettings::setAutoAcceptDispatch()` — persists across sessions

**3. Logout Button** (destructive style):

- Confirmation modal: `"Are you sure you want to log out?"`
- On confirm: `POST /logout` → `AuthStorage::clearAll()` → navigate to `/login` (replace entire stack)

**- [x] Task:** Build Profile screen with courier info, auto-accept toggle, and logout.

---

## 6. Navigation Architecture

### Route File (`routes/mobile.php`)

```php
// Public routes (no auth required)
Route::get('/login', [LoginController::class, 'show']);
Route::post('/login', [LoginController::class, 'login']);
Route::get('/reset-password', [ResetPasswordController::class, 'show']);
Route::post('/reset-password', [ResetPasswordController::class, 'reset']);

// Authenticated routes
Route::middleware(AuthMiddleware::class)->group(function () {
    Route::get('/dashboard', [DashboardController::class, 'index']);

    Route::get('/dispatches', [DispatchListController::class, 'index']);
    Route::get('/dispatches/eligibility', [DispatchEligibilityController::class, 'show']);
    Route::post('/dispatches/eligibility', [DispatchEligibilityController::class, 'check']);
    Route::post('/dispatches/accept', [DispatchAcceptController::class, 'accept']);

    Route::get('/deliveries', [DeliveryListController::class, 'index']);
    Route::get('/deliveries/completed', [CompletedDeliveryController::class, 'index']); // debug gate inside
    Route::get('/deliveries/{id}', [DeliveryDetailController::class, 'show']);
    Route::get('/deliveries/{id}/update', [DeliveryUpdateController::class, 'show']);
    Route::patch('/deliveries/{id}', [DeliveryUpdateController::class, 'update']);

    Route::get('/wallet', [WalletController::class, 'index']);
    Route::get('/wallet/request', [PayoutRequestController::class, 'show']);
    Route::post('/wallet/request', [PayoutRequestController::class, 'create']);
    Route::get('/wallet/{id}', [PayoutDetailController::class, 'show']);

    Route::get('/profile', [ProfileController::class, 'index']);
    Route::post('/profile', [ProfileController::class, 'update']);
    Route::post('/logout', [ProfileController::class, 'logout']);
});
```

### Navigation Flow

```
[Login] ───────────────────────────────────────────────────────────────┐
   ↓ success                                                             │
[Dashboard] ←─────────────── Bottom Tab Bar ──────────────────────→    │
     │              │               │              │           │        │
[Dashboard]  [Dispatches]    [Deliveries]      [Wallet]   [Profile]    │
                   │                │               │           │       │
             [Eligibility]    [Detail]          [Create]   [Logout] ───┘
                   │                │               │
        [Auto-Accept OR      [Update/POD]      [Detail]
         Manual Accept]
                   │
            [Deliveries ←── refresh]
```

### Back Navigation Rules

| Action                   | Back Behavior                                               |
| ------------------------ | ----------------------------------------------------------- |
| After login              | Replace stack — no back to login                            |
| After accepting dispatch | Navigate to Deliveries (replace eligibility/accept screens) |
| After POD update         | Back to Deliveries list                                     |
| After logout             | Replace entire stack with Login                             |
| Between tabs             | No history stack — tabs are always root                     |

---

## 7. Build Order

> Each step is independently testable. Complete each step fully before proceeding.

| Step | Task                                                          | Testable Milestone                                               |
| ---- | ------------------------------------------------------------- | ---------------------------------------------------------------- |
| 1    | Init NativePHP v3 project, install deps, configure `.env`     | `php artisan serve` shows NativePHP default screen               |
| 2    | Implement `AuthStorage` service                               | Unit test: set/get/clear token works                             |
| 3    | Implement `ApiClient` service with full error handling matrix | Unit test: mock 401/422/429/500 responses all handled            |
| 4    | Implement `IdempotencyKey` service                            | Unit test: generates valid UUID v4                               |
| 5    | Implement `DeviceInfo` service                                | Unit test: returns all required fields                           |
| 6    | Implement `AppSettings` service                               | Unit test: auto-accept toggle persists                           |
| 7    | Register `AuthMiddleware` + route file                        | Unauthenticated redirect to `/login` works                       |
| 8    | Create auth layout + Login screen                             | Can submit login, token stored, redirected                       |
| 9    | Create Reset Password screen                                  | Can reset password via courier code                              |
| 10   | Create app layout + bottom tab bar                            | Tabs render, navigation between tabs works                       |
| 11   | Create all shared Blade components                            | Components render correctly in isolation                         |
| 12   | Create Dashboard screen                                       | Stats display correctly from API                                 |
| 13   | Create Pending Dispatches List screen                         | List populates from API, pull-to-refresh works                   |
| 14   | Create Dispatch Eligibility screen (auto-accept logic)        | Both auto and manual flows tested                                |
| 15   | Create Accept Dispatch screen (manual path)                   | Full accept flow with device info                                |
| 16   | Create Active Deliveries List screen                          | Pending only, paginated, ascending urgency order                 |
| 17   | Create Delivery Detail screen                                 | Full delivery info with 3-line earnings breakdown                |
| 18   | Create Update Delivery Status — RTS/OSA path                  | Can update without POD                                           |
| 19   | Add POD photo capture to Update screen — Delivered path       | Camera, up to 10 images, recipient fields, client validation     |
| 20   | Create Wallet Overview + History screen                       | Balance summary and history list                                 |
| 21   | Create Create Payout Request screen                           | Form submits, disclaimer always visible                          |
| 22   | Create Payout Request Detail screen                           | Full breakdown with conditional disclaimer                       |
| 23   | Create Profile + Settings screen                              | Auto-accept toggle persists across sessions                      |
| 24   | Create Completed Deliveries debug screen + access gate        | Hidden in production, visible in debug                           |
| 25   | Logout flow — full session clear                              | Clears storage, replaces stack with Login                        |
| 26   | Integration testing against real dev API                      | All flows verified against `web-admin-fsi-courier-internal.test` |
| 27   | iOS/Android device build and testing                          | App installs and runs on physical device                         |

---

## 8. API Integration Checklist

| Endpoint                           | Screen(s)                            | Auth | Idempotency Key                  | POD Upload                                |
| ---------------------------------- | ------------------------------------ | ---- | -------------------------------- | ----------------------------------------- |
| `POST /login`                      | Login                                | ❌   | ❌                               | ❌                                        |
| `POST /reset-password`             | Reset Password                       | ❌   | ❌                               | ❌                                        |
| `POST /logout`                     | Profile                              | ✅   | ❌                               | ❌                                        |
| `GET /pending-dispatches`          | Dispatches List                      | ✅   | ❌                               | ❌                                        |
| `POST /check-dispatch-eligibility` | Eligibility                          | ✅   | ✅ `client_request_id`           | ❌                                        |
| `POST /accept-dispatch`            | Eligibility (auto) + Accept (manual) | ✅   | ✅ `client_request_id` (new key) | ❌                                        |
| `GET /deliveries`                  | Deliveries List, Completed (debug)   | ✅   | ❌                               | ❌                                        |
| `GET /deliveries/{id}`             | Delivery Detail                      | ✅   | ❌                               | ❌                                        |
| `PATCH /deliveries/{id}`           | Update Delivery                      | ✅   | ❌                               | ✅ (delivered status)                     |
| `POST /payment-request`            | Create Payout                        | ✅   | ❌                               | ❌                                        |
| `GET /payment-requests`            | Wallet History                       | ✅   | ❌                               | ❌ _(endpoint pending — flag to backend)_ |
| `GET /dashboard-summary`           | Dashboard, Wallet                    | ✅   | ❌                               | ❌                                        |

### POD Upload Detail

- Send as `multipart/form-data`
- `delivery_images[]` array with `{type, base64_image}` per item
- Max 10 images per delivery update
- `recipient` field required when `delivery_status = delivered`
- Image types: `package | recipient | location | damage | other`

### Error Handling Matrix

| HTTP Status | Meaning                          | Mobile Action                                                                          |
| ----------- | -------------------------------- | -------------------------------------------------------------------------------------- |
| 200         | Success                          | Process data normally                                                                  |
| 400         | Bad request                      | Show `message` field from API response                                                 |
| 401         | Unauthorized / token revoked     | `AuthStorage::clearAll()` → redirect to `/login` with flash `"You've been logged out"` |
| 403         | Forbidden                        | Show `"Access denied"`                                                                 |
| 404         | Not found                        | Show not found state                                                                   |
| 409         | Conflict (e.g. already accepted) | Show graceful message                                                                  |
| 422         | Validation error                 | Show field-level inline errors from `errors` object                                    |
| 429         | Rate limited                     | Show `"Too many attempts, please wait"` + countdown timer                              |
| 500         | Server error                     | Show `"Something went wrong, try again"` + retry button                                |
| 503         | Maintenance                      | Show `"App is under maintenance"`                                                      |
| Network     | No connection                    | Show `"No connection"` offline message                                                 |

---

## 9. Testing Plan

### Unit Tests

| File                 | What to Test                                                                                                   |
| -------------------- | -------------------------------------------------------------------------------------------------------------- |
| `AuthStorageTest`    | `set/get/clear` token; `isAuthenticated()` correct bool; secure storage used (not session)                     |
| `ApiClientTest`      | 401 clears storage; 422 returns errors array; 429 rate-limit flag; 500 server-error flag; network error caught |
| `IdempotencyKeyTest` | `generate()` returns valid UUID v4 format; two calls return different keys                                     |
| `AppSettingsTest`    | Auto-accept default is `false`; toggle persists after set                                                      |

### Feature Tests

| File                 | Scenarios                                                                                                                                           |
| -------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `LoginTest`          | Valid credentials → token stored, redirected; Invalid → error shown; 429 → rate limit message with timer                                            |
| `ResetPasswordTest`  | Valid reset → success flash; Invalid code → "Courier not found" error                                                                               |
| `DispatchListTest`   | Empty list → empty state; Items present → rendered correctly                                                                                        |
| `DispatchAcceptTest` | Auto-accept ON + eligible → auto-accept called; Auto-accept OFF → manual screen shown; Not eligible → error shown                                   |
| `DeliveryUpdateTest` | Delivered without photo → client validation error; Delivered with photo + recipient → success; RTS with reason → success; OSA with reason → success |
| `PayoutRequestTest`  | Disclaimer always visible; Date validation (from before to); Success → redirects to detail                                                          |

### Edge Cases

- [ ] 401 mid-session (token expired) on any protected screen → clear storage → Login with message
- [ ] Network error (no connectivity) → friendly offline message, no crash
- [ ] 429 on login → countdown timer displayed
- [ ] Dispatch already accepted (409) → graceful toast, navigate to deliveries
- [ ] Delivery images > 10 → UI prevents adding more (hard cap at 10)
- [ ] Empty deliveries list → no crash, empty state shown with icon
- [ ] Large delivery list → pagination load more on scroll
- [ ] App opened with expired token → AuthMiddleware catches → Login

### Testing Against Real API

1. Set `MOBILE_API_BASE_URL=http://web-admin-fsi-courier-internal.test/api/mbl` in `.env`
2. Create test courier account in GDTMS v2 web admin
3. Run through all flows manually on dev device/simulator
4. Use `APP_DEBUG=true` to access Completed Deliveries debug screen
5. Test credentials: `Phone: 09123456789 | Password: Test@123 | Courier Code: CC99999`

---

## 10. Environment & Deployment

### Dev vs Production

| Key                   | Dev                                                  | Production                        |
| --------------------- | ---------------------------------------------------- | --------------------------------- |
| `MOBILE_API_BASE_URL` | `http://web-admin-fsi-courier-internal.test/api/mbl` | `https://fsi-courier.com/api/mbl` |
| `APP_DEBUG`           | `true`                                               | `false`                           |
| `APP_ENV`             | `local`                                              | `production`                      |

### API URL Switching

NativePHP bundles the `.env` at build time. CI/CD pipeline injects the correct `MOBILE_API_BASE_URL` per target environment. Never hardcode URLs.

### App Versioning

| Key                     | Purpose                                                     |
| ----------------------- | ----------------------------------------------------------- |
| `NATIVEPHP_APP_VERSION` | Semantic version (e.g. `1.0.0`, `1.1.0`)                    |
| `NATIVEPHP_APP_BUILD`   | Monotonically increasing integer for App Store / Play Store |
| `MOBILE_APP_VERSION`    | Sent as `device_info.app_version` to the API                |

### Build Commands

```bash
# iOS build
php artisan native:build ios --env=production

# Android build
php artisan native:build android --env=production

# Dev run (simulator)
php artisan native:run ios
php artisan native:run android
```

---

## 11. Future Backlog

> Not in scope for v1. Log as issues for future sprints.

| Feature                   | Notes                                                                             |
| ------------------------- | --------------------------------------------------------------------------------- |
| Push Notifications        | New dispatch assigned → push to courier via FCM/APNs                              |
| GPS / Location Tracking   | Record GPS coordinates at delivery confirmation                                   |
| Offline Mode              | Queue status updates when no network, flush on reconnect with idempotency keys    |
| Digital Signature Capture | Native canvas signature pad for recipient signature (field already exists in API) |
| Batch POD Upload          | Queue images during poor connectivity, upload when on WiFi                        |
| Biometric Login           | Face ID / fingerprint as alternative to password entry                            |
| Delivery Map View         | Map pin per delivery address for route planning                                   |
| Earnings Preview          | Preview earnings before submitting payout request                                 |

---

## 12. Web App Reference Files

> These files are in the **GDTMS v2 web app**. Reference only — do not modify.

| File                                                                           | Relevance                                              |
| ------------------------------------------------------------------------------ | ------------------------------------------------------ |
| `routes/auth/api.php` (lines 261–297)                                          | All mobile API routes                                  |
| `routes/auth.php` (lines 38–40)                                                | Login + reset-password public routes                   |
| `app/Http/Controllers/Mobile/CourierAuthentication.php`                        | Login behavior                                         |
| `app/Http/Controllers/Dashboard/CourierManagement/CourierMobileController.php` | All other mobile endpoints                             |
| `app/Http/Requests/DeliveryStatusUpdateRequest.php`                            | **Real POD field names** (use these, not the spec doc) |
| `app/Http/Requests/AcceptDispatchRequest.php`                                  | Accept dispatch payload                                |
| `app/Services/CourierMobileService.php`                                        | Business logic for mobile operations                   |
| `config/sanctum.php`                                                           | Token expiry (30 days = 43200 minutes)                 |

---

## Quick Reference — Key Business Rules

> These rules must be enforced at all times. Do not skip any.

1. **Rate Locking** — Always display `delivery_rate` from the delivery object. Never recalculate. Rates are locked at dispatch time.
2. **Earnings Transparency** — Always show 3-line breakdown: Delivery Rate → Coordinator Fee (deduction) → Net Amount.
3. **One Active Session** — On any `401`, immediately `AuthStorage::clearAll()` and redirect to Login with `"You've been logged out"`.
4. **POD Required for Delivered** — At least 1 photo + recipient name required when marking `delivered`. Enforce client-side before API call.
5. **Idempotency Keys** — `accept-dispatch` and `check-dispatch-eligibility` must include a fresh `client_request_id` (UUID v4). The accept key must be different from the eligibility key.
6. **Login Rate Limit** — 5 attempts per 5 minutes. Show countdown timer on `429`.
7. **Deliveries = Pending Only** — Active deliveries list shows `status=pending` only, sorted by `created_at ASC` (oldest = most urgent = top).
8. **Debug Gate** — Completed deliveries screen is only accessible when `APP_DEBUG=true`. Hidden in production.
9. **Wallet Disclaimer** — Payout amount disclaimer must always be visible on Create Payout and Payout Detail (until `status=paid`).
10. **Token Security** — Never log tokens. Never store in plain files or session. Always use NativePHP secure storage.

---

_Last Updated: March 2026 | GDTMS v2 — NativePHP v3 Courier Mobile App_
