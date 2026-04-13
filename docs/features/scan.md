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
- Returns the scanned barcode string to the calling screen via `GoRouter.pop(barcode)`.
- Shows a `ScanModeSheet` to let the courier switch between camera scan and manual entry.

## Usage

Pushed by `DispatchListScreen` and delivery search. Always pops with the barcode — never navigates forward directly.

## Notes

- Camera permission is expected to be granted before reaching this screen. If denied, the scanner shows a permission error state.
- Do not add business logic here — this screen is purely a barcode input mechanism.
