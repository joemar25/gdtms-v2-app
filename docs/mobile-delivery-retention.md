# Mobile Delivery Retention Rules

This document describes how deliveries are shown, hidden, and archived in the FSI Courier mobile app.

---

## Delivered Screen Visibility Rules

A delivery appears in the **Delivered** screen only when it passes the following rules:

### Rule 1 — Delivered Today

```
delivery.delivered_at >= today_midnight
```

If a delivery was completed today, it is visible on the Delivered screen.

### Rule 2 — Verification Status

Verified Return-to-Sender (RTS) and delivered records that have been archived are excluded from the active lists to ensure the courier only sees actionable items.

**Example timeline:**

| Date    | Event                   | Visible on Delivered screen? |
| ------- | ----------------------- | ---------------------------- |
| March 8 | Delivery completed      | ✓ Yes                        |
| March 9 | Next day — no new event | ✗ No (removed)               |

---

## Dashboard Count Consistency

The **DELIVERED** stat card on the dashboard and the **Delivered list screen** always use the same filter query (`getVisibleDelivered` / `countVisibleDelivered`):

```
delivery_status = 'delivered'
AND delivered_at >= today_midnight
```

This ensures the card count and the list length are always equal — no mismatch.

When online, the server's `delivered_today` figure is used directly. When offline, the local SQLite result from the same filter is used as a fallback.

---

## Payout Status on Delivery Cards

Delivery cards in the Delivered list show a **PAID** badge when `paid_at` is set. This lets the driver confirm at a glance which deliveries have been included in a paid payout.

| Badge    | Condition             |
| -------- | --------------------- |
| _(none)_ | `paid_at` is null     |
| **PAID** | `paid_at` is not null |

---

## History Screen

The **History** screen (`/history`) shows all delivery sync entries — pending, synced, and failed uploads.

When a delivery has been archived or verified, its History entry displays an **ARCHIVED** chip. This signals that the delivery's lifecycle is complete.

```
Delivered → [in Delivered screen]
Next day → [removed from Delivered screen, ARCHIVED shown in History]
```

---

## Local Database Schema

Relevant columns in the `local_deliveries` table:

| Column            | Type    | Description                                          |
| ----------------- | ------- | ---------------------------------------------------- |
| `delivery_status` | TEXT    | Current status: `pending`, `delivered`, `rts`, `osa` |
| `delivered_at`    | INTEGER | Epoch ms when status changed to `delivered`          |
| `updated_at`      | INTEGER | Epoch ms of last record modification                 |

`delivered_at` is set by the DAO when `updateStatus('delivered')` or `updateFromJson` receives a `delivered` status.

---

## Cleanup Behavior

Completed records (`delivered`, `rts`, `osa`) are deleted from local storage after retention windows expire:

- **Standard**: deleted after `kLocalDataRetentionDays` days (based on `updated_at`)
- **Verified RTS**: deleted **immediately** upon detection from the API (sync or detail refresh). Once the hub team verifies a return, it is no longer part of the courier's active database.

Immediate verified-RTS purging ensures the courier cannot view or act on finalized returns.

---

## Relationship Between Delivered Screen and History

| Screen    | Shows                                   | Removed when           |
| --------- | --------------------------------------- | ---------------------- |
| Delivered | Today's delivered items                 | Next day (midnight)    |
| History   | All sync entries, forever               | Only on cleanup delete |

History is a persistent audit trail. Delivered is a day-view operational list.

---


---

## Notifications

Push-style in-app notifications are fetched from `GET /notifications`. The bell icon in `AppHeaderBar` shows an unread badge count loaded via `NotificationsNotifier.loadUnreadCount()`.

### Notification Types

| Type                     | Icon            | Navigates to              |
| ------------------------ | --------------- | ------------------------- |
| `payout_requested`       | Send            | `/wallet/:reference`      |
| `payout_approved`        | Check circle    | `/wallet/:reference`      |
| `payout_rejected`        | Cancel          | `/wallet/:reference`      |
| `transaction_due_soon`   | Schedule        | _(no navigation)_         |
| `transaction_due_today`  | Today            | _(no navigation)_         |

### Lifecycle

1. App starts online → `AppHeaderBar` loads unread count (badge appears immediately).
2. User taps bell → navigates to `/notifications` → full list loaded.
3. Tapping an unread notification → marked read optimistically, then persisted to server.
4. "Mark all read" button → all entries cleared optimistically + server call.
5. Pull-to-refresh → reloads page 1.
6. "Load more" button → appends next page.

### Provider

```dart
// Full state (list + pagination + unread count)
ref.watch(notificationsProvider)

// Only the unread badge count (cheap watch for AppHeaderBar)
ref.watch(notificationsUnreadCountProvider)
```

