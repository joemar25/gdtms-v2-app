<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/features/dispatch/dispatch_eligibility_screen.dart
    lib/features/dispatch/dispatch_list_screen.dart

  Update this document whenever you change any of those files.
  Each of those files carries a header comment: "DOCS: docs/features/dispatch.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Feature — Dispatch

## Files

| File | Route | Purpose |
|------|-------|---------|
| `dispatch_eligibility_screen.dart` | `/dispatch/eligibility` | Gate — checks if courier can start dispatch |
| `dispatch_list_screen.dart` | `/dispatch/list` | Lists parcels to scan and accept |

## Screenshots

**Allowed** on Dispatch eligibility and list (dispatch details) for courier support.
These screens are **not** wrapped in `SecureView`.

**Still blocked:** opening **Account Details** from a delivery card uses
`showDeliveryAccountDetails` → `SecureView` (recipient name/address/phone).

---

## `dispatch_eligibility_screen.dart`

### Flow

1. Screen mounts → calls `GET /dispatch/eligibility`.
2. Device info (free storage GB, OS version) is attached to the request — the server can block dispatch for low-storage devices.
3. **Eligible**: "START DISPATCH" button visible → navigates to `DispatchListScreen`.
4. **Ineligible**: server-provided reason shown; button hidden.

### Blocking reasons (from server)

- Unsynced deliveries from previous dispatch.
- Account suspension.
- Incomplete profile.
- Device below minimum spec (storage, OS).

### Notes

- This screen is the only place that attaches device info to an eligibility request. If device info fields change, update `DeviceInfoService` and this screen.
- Navigate here from: Dashboard DISPATCH card.
- Eligible deliveries preview is paginated client-side (`_pageSize = 10`) via `PaginationBar` + `PaginationSwipeArea` (swipe left/right also changes page — see `docs/shared/widgets.md`).

---

## `dispatch_list_screen.dart`

### Flow

1. Lists parcels assigned to this dispatch run (fetched from server).
2. Courier scans each parcel barcode using `ScanScreen` or manual input.
3. Tapping "ACCEPT" on a parcel calls `POST /dispatch/{id}/accept`.
4. All parcels accepted → dispatch session complete.

### Notes

- Parcels accepted here are seeded into `local_deliveries` immediately so they appear in the delivery list offline.
- Do not allow re-accepting already-accepted parcels (server returns 409 — handle with `ApiConflict`).

### Pagination

- List is fetched from `GET /pending-dispatches?page=&per_page=` (`kDispatchesPerPage` / `kCompactDispatchesPerPage` in `constants.dart`, 5 / 15 items).
- Response `total_count` and `pagination.last_page` drive a `PaginationBar` at the bottom of the list (same widget/pattern as `delivery_status_list_screen.dart`), so couriers can page through all pending dispatches instead of only ever seeing page 1.
- Switching compact mode resets back to page 1 since the page size changes.
- The list body is wrapped in `PaginationSwipeArea` so swiping left/right also changes page, same as tapping the `PaginationBar` arrows — see `docs/shared/widgets.md`.

### Scan Actions

The header in `DispatchListScreen` must use **Scan Dispatch** mode. This mode is specifically for manifest/dispatch barcodes and handles eligibility checks via the API. Refer to [scan.md](scan.md) for full rulings.
