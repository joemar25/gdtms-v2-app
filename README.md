# GDTMS Courier Mobile

NativePHP v3 mobile app for FSI couriers, built on Laravel 12 + PHP 8.4.
Consumes the GDTMS v2 web app's dedicated mobile REST API (`/api/mbl`).

For the full implementation checklist and business rules, see [documentation/TODO.md](documentation/TODO.md).

---

## Stack

| Layer            | Technology                        |
| ---------------- | --------------------------------- |
| Framework        | Laravel 12 + PHP 8.4              |
| Mobile runtime   | NativePHP v3 (Android / iOS)      |
| Frontend         | Blade + vanilla JS (no React/Vue) |
| Database (local) | SQLite                            |
| Cache / Session  | File-based (`CACHE_STORE=file`)   |
| Testing          | PHPUnit 11.5                      |

---

## Development Workflow

> Requires NativePHP v3 "Jump" mode. Your dev machine and Android device must be on the **same Wi-Fi network**.

```bash
# Build bundle + start jump server (full rebuild)
php artisan native:jump android

# Reuse existing bundle (no rebuild — faster iteration)
php artisan native:jump android --skip-build

# Stream device logs via ADB
php artisan native:tail

# Build a release APK / IPA
php artisan native:build

# or
php artisan native:run --build=release

# Build and run your app on a device or simulator.
php artisan native:run {os?} {udid?}

# sample:
php artisan native:run android --watch
```

> **Note:** After any PHP change, run a full `native:jump android` (without `--skip-build`) so the device picks up the new bundle.

```md
# check devices available for testing 
adb devices
```

---

## Running Tests

```bash
php artisan test tests/Feature/Auth/LoginTest.php
```

All 5 `LoginTest` cases must pass before any PR.

---

## Key `.env` Requirements

```dotenv
CACHE_STORE=file        # Required — database cache crashes before migration runs
LOG_STACK=single        # Required for native:tail to work
APP_DEBUG=true          # Dev mode — enables debug stats
```

---

## Business Rules (Quick Reference)

- **Dashboard home** shows only `pending` deliveries that have a `received_by_courier` history entry.
- **Delivered / RTS / OSA** items are hidden from the home screen.
- **Dispatch scan UI** (accept incoming dispatch) is hidden in production; visible only when `APP_DEBUG=true`.
- **Auto-accept dispatch** — controlled by the in-app settings toggle. When on, eligibility check immediately accepts and redirects to dashboard.
- All dev-only UI elements use the `.dev-badge` / `$isDebug` guard pattern.

---

## Project Notes

- PHP runs **locally on the device** (embedded PHP runtime via NativePHP). The jump server only distributes the PHP bundle — it is **not** a proxy for page requests.
- `nativephp_call()` exists on device → `onDevice()` returns `true` → SecureStorage is used.
- Host `laravel.log` is always empty during Jump mode (expected — logs are on device storage).
