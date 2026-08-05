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

**Composition reference** for post-login UI: [design-system.md](../design-system.md).

- **Shell**: transparent tab `Scaffold`; scenery from `ScaffoldWithNavBar` (`DsBackdrop.shell`).
- **Section titles**: shared i18n (`overview_title`, `quick_title`) — uppercase caption.
- **Metric grid (`StatCard`)**: Dispatch (gold), Deliveries / Delivered / Attempted / Misrouted / Sync (primary). Hold-to-reveal details; fixed height; brand palette only.
- **Quick actions (`ScanButton`)**: Dispatch scan (gold), POD scan (primary); hold-to-reveal; fixed height.
- **Motion**: `.dsDashboardCardEntry` / `.dsDashboardCtaEntry` + stagger; in-card count-up / active pulse.
- **Sync Now** (new-feel / dashboard sync strip): `showSyncOverlay` — same loader as initial sync.

## Data source

Stats are computed from local DB / summary map — **never** only a live API call for the grid. Offline-capable.

## Notes

- SYNC card opens `/sync` (history). Sync Now uses the shared overlay, not a dark spinner dialog.
- Auto-refresh: watches `deliveryRefreshProvider` — incremented by sync completion.
- When aligning Bagsakan / Wallet / Profile, follow design-system.md §10 apply map.
