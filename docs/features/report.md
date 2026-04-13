<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/features/report/report_issue_screen.dart

  Update this document whenever you change this file.
  This file carries a header comment: "DOCS: docs/features/report.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Feature — Report Issue

## File

`lib/features/report/report_issue_screen.dart` — Route: `/report`

---

## Purpose

Lets the courier submit a bug report or operational issue to the backend.

## Flow

1. Courier fills in description (required) and optionally selects a related delivery barcode.
2. `DeviceInfoService.getDeviceInfo()` is called to attach OS version, app version, and free storage.
3. Calls `ReportService.submit(BugReportPayload)`.
4. On success: shows confirmation and navigates back.

## Notes

- Device info is always attached automatically — do not remove it.
- If the payload fields change, update `BugReportPayload` in `docs/core/models.md` too.
