<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/features/dispatch/dispatch_eligibility_screen.dart
    lib/features/dispatch/dispatch_list_screen.dart
    lib/features/dispatch/widgets/dispatch_info_card.dart
    lib/features/dispatch/widgets/pin_confirm_dialog.dart

  Update this document whenever you change any of those files.
  Each of those files carries a header comment: "DOCS: docs/features/dispatch.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Feature — Dispatch

## Files

| File | Route | Purpose |
|------|-------|---------|
| `dispatch_eligibility_screen.dart` | `/dispatches/eligibility` | **Dispatch details** — review, accept (PIN), or reject |
| `dispatch_list_screen.dart` | `/dispatches` | Pending dispatches list |
| `widgets/dispatch_info_card.dart` | — | Gold hero + branch/items/dates summary |
| `widgets/pin_confirm_dialog.dart` | — | Last-4 PIN confirm before accept |

## Screenshots

**Allowed** on Dispatch eligibility and list for courier support (not wrapped in `SecureView`).

**Still blocked:** Account Details from a delivery card → `SecureView`.

---

## Dispatch details (`dispatch_eligibility_screen.dart`)

### UI standard (must follow design-system.md)

| Layer | API |
|-------|-----|
| Shell | `DsAppScaffold` |
| Header | Glass `AppHeaderBar` (standalone — not continuous strip) |
| Body | `ListView` + `DSSpacing` / `DSSectionHeader` / `DSCard` |
| Summary | `DispatchInfoCard` (gold hero = start-work) |
| CTAs | **`DsBottomActionBar`** — Accept (gold) + Reject (error outline) |
| Reject form | Same dock with solid error **Reject** + Cancel |
| Loading | `LoadingOverlay` |

**Never:** centered `maxWidth: 420` slab, floating CTAs without `DsBottomActionBar` (black void risk), raw `CircularProgressIndicator` as page body.

### Flow

1. Opened with `eligibility_response` already fetched (list / scan / notification).
2. **Eligible** → summary card, optional delivery preview (paginated), Accept / Reject dock.
3. **Accept** → PIN (unless `skipPinDialog`) → `POST` accept → seed deliveries → dashboard.
4. **Reject** → reason form → confirm dialog → `POST` reject → dashboard.
5. **Ineligible / error** → status card in body (no bottom dock).

### Notes

- Device info is attached on accept/reject/eligibility check via `DeviceInfoService`.
- Delivery preview pagination: client-side `_pageSize = 10` + `PaginationBar` / `PaginationSwipeArea`.

---

## `dispatch_list_screen.dart`

### Flow

1. Lists pending dispatches (`GET` pending, online only).
2. Tap card → eligibility check → push **dispatch details**.
3. Header scan → Scan Dispatch mode.

### UI

- `DsAppScaffold` + glass `AppHeaderBar`
- `RefreshIndicator` + `PaginationBar` / `PaginationSwipeArea`
- Offline → `OfflinePlaceholder`

### Pagination

- `kDispatchesPerPage` / `kCompactDispatchesPerPage`
- Compact mode change resets to page 1

### Scan

Header uses **Scan Dispatch** mode — see [scan.md](scan.md).
