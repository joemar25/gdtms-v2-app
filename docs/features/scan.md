<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/features/scan/scan_screen.dart

  Update this document whenever you change this file.
  This file carries a header comment: "DOCS: docs/features/scan.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Feature — Scan

## File

`lib/features/scan/scan_screen.dart` — Route: `/scan`

---

## Purpose

Barcode scanner screen used by dispatch and delivery flows.

## Behavior

- Uses `mobile_scanner` package.
- Supports multiple barcode formats (QR, Code128, Code39, etc.).
- On success, it either navigates forward (to update or eligibility screens) or returns the barcode to the caller depending on the entry point.
- Shows a `ScanModeSheet` for manual input fallback.

## Scan Modes (The "Rulings")

The scanner operates in three distinct modes, each tied to a specific workflow. Consistency in mode usage is critical for correct API integration and data lookups.

| Mode | Entry Point | Purpose | Success Action |
|------|-------------|---------|----------------|
| **Scan Dispatch** | `DispatchListScreen` header | For manifest/dispatch QR codes. | Calls `/check-dispatch-eligibility` -> `DispatchEligibilityScreen`. |
| **Scan POD** | `DeliveryStatusListScreen` header (For Delivery & Failed Delivery) | For parcel barcodes already in courier possession. | Searches local SQLite -> Fallback to server -> `DeliveryUpdateScreen`. |
| **Scan Bagsakan** | `CreateBagsakanScreen` | For grouping parcels. | (Under Development) Adds item to bagsakan group. |

### Rationale
- **Dispatch Mode** is restricted to the initial assignment phase. It allows scanning manifest codes that are *not* yet in the local database to "pull" them from the server.
- **POD Mode** is used for all active delivery lists. Since items in "For Delivery" or "Failed Delivery" are already in the local SQLite, this mode ensures fast offline-first lookups and prevents redundant eligibility checks for items the courier already owns.

## Usage

Pushed by `DispatchListScreen` and delivery search. Always pops with the barcode — never navigates forward directly.

## Notes

- Camera permission is expected to be granted before reaching this screen. If denied, the scanner shows a permission error state.
- Do not add business logic here — this screen is purely a barcode input mechanism.
