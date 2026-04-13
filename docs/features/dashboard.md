<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/features/dashboard/dashboard_screen.dart

  Update this document whenever you change this file.
  This file carries a header comment: "DOCS: docs/features/dashboard.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Feature — Dashboard

## File

`lib/features/dashboard/dashboard_screen.dart` — Route: `/dashboard`

---

## Purpose

Home screen after login. Shows the courier's daily summary and navigation cards.

## Layout

- **Stat chips** at the top: total deliveries, pending, delivered, failed counts pulled from `local_deliveries`.
- **Navigation cards**:
  - DISPATCH — navigates to `/dispatch/eligibility`
  - DELIVERIES — navigates to `/deliveries`
  - HISTORY — navigates to `/history` (sync history screen)
  - WALLET — navigates to `/wallet`
- **Version check banner**: shown if the app is behind the server's `min_version`.
- **Offline banner**: shown via `OfflineBanner` widget when `isOnlineProvider` is `false`.

## Data source

Stats are computed from `LocalDeliveryDao.getAll(courierId)` — **never** from a live API call. The dashboard is always offline-capable.

## Notes

- The SYNC card was renamed to HISTORY. If a future card needs to be added, add it here and update this doc.
- Auto-refresh: watches `deliveryRefreshProvider` — incremented by sync completion.
