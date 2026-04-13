<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/features/notifications/notifications_screen.dart

  Update this document whenever you change this file.
  This file carries a header comment: "DOCS: docs/features/notifications.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Feature — Notifications

## File

`lib/features/notifications/notifications_screen.dart` — Route: `/notifications`

---

## Purpose

Lists in-app notifications for the courier (e.g. dispatch assignments, payout status updates).

## Data source

Fetched from `GET /notifications`. Read status updated via `PATCH /notifications/{id}/read`.

## Notes

- `flutter_local_notifications` is initialized but not actively used for push scheduling yet. When push notifications are implemented, update this doc and `docs/core/services.md`.
- Unread count badge on the bottom nav is driven by `notificationsProvider`.
