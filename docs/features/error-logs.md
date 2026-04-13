<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/features/error_logs/error_logs_screen.dart

  Update this document whenever you change this file.
  This file carries a header comment: "DOCS: docs/features/error-logs.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Feature — Error Logs

## File

`lib/features/error_logs/error_logs_screen.dart` — Route: `/error-logs`

---

## Purpose

Developer/support screen showing app-level error events captured by `ErrorLogService`.

## Data source

Reads from `ErrorLogDao.getAll()` — the local `error_logs` SQLite table. No network call.

## Actions

- **Clear all**: calls `ErrorLogDao.deleteAll()`. Cannot be undone.
- **Copy entry**: copies the error detail to clipboard for sharing.

## Notes

- Access is via Profile → Developer Options (or a hidden tap sequence — do not advertise this route to end users).
- Entries are written by `ErrorLogService.log(...)` in catch blocks throughout the app. See `docs/core/services.md`.
