<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/features/sync/sync_screen.dart

  Update this document whenever you change this file.
  This file carries a header comment: "DOCS: docs/features/sync-history.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Feature — Sync History

## File

`lib/features/sync/sync_screen.dart` — Route: `/history`

---

## Purpose

Shows the courier's sync operation history and allows manual sync trigger.

## Layout

- **Header action**: single SYNC button in the app bar header — does not interfere with list pagination.
- **History list**: paginated list of `sync_operations` rows ordered by date.
- Each row shows: barcode, status badge, timestamp, error message (if failed).

## Manual sync trigger

Manual / overlay paths use coalesced **`requestFlush(reason:, awaitIdle:)`** (see
`sync_now_button.dart` / `showSyncOverlay`). Screen open and pull-to-refresh also
flush when `ConnectionStatus.online`.

Architecture: [../architecture/system-map.md](../architecture/system-map.md),
[../core/sync.md](../core/sync.md).

**Support (stuck pending / failed / conflict — do not wipe app data first):**
[../architecture/ops-runbook.md](../architecture/ops-runbook.md).

## Status badges

| Status | Color | Meaning |
|--------|-------|---------|
| `synced` | Green | Successfully delivered to server |
| `pending` | Blue | Queued, not yet attempted |
| `processing` | Orange | Currently being synced |
| `failed` | Red | Last attempt failed — will retry |
| `conflict` | accent | Server rejected with a conflict |

## Notes

- This screen was previously named "Sync". It is now "History" throughout the UI and dashboard card.
- Retention window is set in Profile → Preferences (1, 3, or 5 days). `CleanupService` enforces it.
