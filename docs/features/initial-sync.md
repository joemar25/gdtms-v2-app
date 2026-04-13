<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/features/initial_sync/initial_sync_screen.dart

  Update this document whenever you change this file.
  This file carries a header comment: "DOCS: docs/features/initial-sync.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Feature — Initial Sync

## File

`lib/features/initial_sync/initial_sync_screen.dart` — Route: `/initial-sync`

---

## Purpose

Shown after first login (or when local delivery data is empty). Blocks the courier from accessing the dashboard until `DeliveryBootstrapService` has seeded `local_deliveries` from the server.

## Flow

1. Screen mounts → calls `DeliveryBootstrapService.run()`.
2. Shows a progress indicator while seeding.
3. On success → navigates to `/dashboard`.
4. On network error → shows retry button.

## Notes

- This screen requires connectivity. If the courier is offline on first login, they see an error with a retry button — they cannot proceed without seeding.
- Subsequent app launches do not go through this screen; bootstrap runs silently in `app.dart`.
