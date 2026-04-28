<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This is the documentation index for the FSI Courier mobile app.

  STRICT RULE: Every time a new doc file is added under docs/, add it here.
  Every time a doc file is removed or renamed, update this index.
  The README.md "Documentation" section mirrors this index — keep them in sync.
  ══════════════════════════════════════════════════════════════════════════════
-->

# Documentation Index

All files use kebab-case names. Organized to mirror the `lib/` folder structure.

---

## API Source of Truth

> **The Postman collection is the single source of truth for all API definitions.**
> Update it first, before writing any app code. See the development workflow below.

- [gdtms-v2-api/README.md](gdtms-v2-api/README.md) — full endpoint reference, changelog, development workflow
- [gdtms-v2-api/mobile-api-requirements.md](gdtms-v2-api/mobile-api-requirements.md) — what the backend team must fix/maintain for the mobile app (12 items, graded by severity)
- `gdtms-v2-api/Courier-Mobile-API.postman_collection.json` — **live source of truth**, authoritative request/response shapes

**Development order (enforced)**:

1. Update `Courier-Mobile-API.postman_collection.json`
2. Update `gdtms-v2-api/README.md`
3. Update the affected `docs/features/*.md`
4. Implement in the app

---

## Entry Points

- [entry-points.md](entry-points.md) — `main.dart`, `app.dart`, `splash_screen.dart`

---

## Core (`lib/core/`)

- [core/api.md](core/api.md) — `api_client.dart`, `api_result.dart`, `s3_upload_service.dart`
- [core/auth.md](core/auth.md) — `auth_provider.dart`, `auth_storage.dart`, `auth_service.dart`
- [core/database.md](core/database.md) — `app_database.dart`, DAOs, `cleanup_service.dart`
- [core/device.md](core/device.md) — `device_info.dart`, platform channel `fsi_courier/storage`
- [core/models.md](core/models.md) — `LocalDelivery`, `SyncOperation`, `PhotoEntry`, `BugReportPayload`
- [core/providers.md](core/providers.md) — `isOnlineProvider`, `deliveryRefreshProvider`, `locationProvider`, etc.
- [core/services.md](core/services.md) — all service classes under `lib/core/services/`
- [core/settings.md](core/settings.md) — `config.dart`, `constants.dart`, `app_settings.dart`, `compact_mode_provider.dart`
- [core/sync.md](core/sync.md) — `sync_manager.dart`, `delivery_bootstrap_service.dart`, `workmanager_setup.dart`

---

## Features (`lib/features/`)

- [features/auth.md](features/auth.md) — `login_screen.dart`, `reset_password_screen.dart`
- [features/dashboard.md](features/dashboard.md) — `dashboard_screen.dart`
- [features/delivery.md](features/delivery.md) — delivery list, detail, update, signature screens + widgets
- [features/dispatch.md](features/dispatch.md) — `dispatch_eligibility_screen.dart`, `dispatch_list_screen.dart`
- [features/error-logs.md](features/error-logs.md) — `error_logs_screen.dart`
- [features/initial-sync.md](features/initial-sync.md) — `initial_sync_screen.dart`
- [features/legal.md](features/legal.md) — `terms_screen.dart`, `privacy_screen.dart`
- [features/location.md](features/location.md) — `location_required_screen.dart`
- [features/notifications.md](features/notifications.md) — `notifications_screen.dart`
- [features/profile.md](features/profile.md) — `profile_screen.dart`, `profile_edit_screen.dart`
- [features/report.md](features/report.md) — `report_issue_screen.dart`
- [features/scan.md](features/scan.md) — `scan_screen.dart`
- [features/sync-history.md](features/sync-history.md) — `sync_screen.dart` (History tab)
- [features/wallet.md](features/wallet.md) — `wallet_screen.dart`, `payout_detail_screen.dart`, `payout_request_screen.dart`

---

## Shared (`lib/shared/`)

- [shared/helpers.md](shared/helpers.md) — all helper utilities under `lib/shared/helpers/`
- [shared/router.md](shared/router.md) — `app_router.dart`, `router_keys.dart`, full route table
- [shared/widgets.md](shared/widgets.md) — all reusable widgets under `lib/shared/widgets/`

---

## Design System

- [styles.md](styles.md) — `lib/design_system/` — color, typography tokens, and atomic widgets

---

## Legacy / Specific Reports

- [mobile-delivery-retention.md](mobile-delivery-retention.md) — delivery retention rules, history behavior, local cleanup, API v2
- [api-timestamp-bug-report.md](api-timestamp-bug-report.md) — API timestamp/timezone bug report

---

## How to use this system

1. **When you edit a source file** — open its matching doc (the `DOCS:` comment at the top of the file tells you which one) and update it.
2. **When you add a new file or folder** — create a matching doc, add it to this index, and add it to the `README.md` Documentation section.
3. **When you remove a file** — remove or update its entry here and in `README.md`.
