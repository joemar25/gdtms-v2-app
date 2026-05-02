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

1. Courier fills in summary (required), selects type and severity, and optionally adds description.
2. Device info (model, OS version, device ID, app version) is collected via `DeviceInfoService`.
3. Recent error logs (up to 50) are optionally attached if "Include diagnostic logs" is checked.
4. Calls `ReportService.submit(BugReportPayload)` to POST `/courier/reports`.
5. On success: shows confirmation with report ID and navigates back.

## Notes

- Device info is always attached automatically — do not remove it.
- Error logs are collected from `ErrorLogDao` (last 50 entries) when `includeLogs=true`.
- Response returns `report_id` in RPT-xxxx format (parsed from API response).
- If the payload fields change, update `BugReportPayload` in `docs/core/models.md` too.
