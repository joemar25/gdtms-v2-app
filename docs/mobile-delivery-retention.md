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

### Rule 2 — Payout Requested (Same Day)

A delivery included in a payout request on the same day it was delivered remains visible.
No extra filter is applied — it already satisfies Rule 1 (`delivered_at >= today_midnight`).

### Rule 3 — Payout Paid Today

If the payout covering this delivery was marked **paid today**:

```
delivery.paid_at >= today_midnight
```

The delivery still appears on the Delivered screen. The driver can confirm payment on the same day.

### Rule 4 — Next-Day Removal

If the payout was paid **before today** (`paid_at < today_midnight`) and the delivery was also delivered before today, the delivery is **removed** from the Delivered screen.

**Example timeline:**

| Date    | Event                   | Visible on Delivered screen? |
| ------- | ----------------------- | ---------------------------- |
| March 8 | Delivery completed      | ✓ Yes                        |
| March 8 | Payout requested        | ✓ Yes                        |
| March 8 | Payout paid             | ✓ Yes                        |
| March 9 | Next day — no new event | ✗ No (removed)               |

---

## Dashboard Count Consistency

The **DELIVERED** stat card on the dashboard and the **Delivered list screen** always use the same filter query (`getVisibleDelivered` / `countVisibleDelivered`):

```
delivery_status = 'delivered'
AND (delivered_at >= today_midnight OR paid_at >= today_midnight)
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

When a delivery has been paid (`paid_at` is set), its History entry displays an **ARCHIVED** chip. This signals that the delivery's full lifecycle (Delivered → Payout Requested → Paid) is complete and the record has been removed from the active Delivered list.

```
Delivered → [in Delivered screen]
Payout requested → [still in Delivered screen, same day]
Paid (same day) → [still in Delivered screen, ARCHIVED shown in History]
Next day → [removed from Delivered screen, ARCHIVED shown in History]
```

---

## Local Database Schema

Relevant columns in the `local_deliveries` table:

| Column            | Type    | Description                                          |
| ----------------- | ------- | ---------------------------------------------------- |
| `delivery_status` | TEXT    | Current status: `pending`, `delivered`, `rts`, `osa` |
| `delivered_at`    | INTEGER | Epoch ms when status changed to `delivered`          |
| `paid_at`         | INTEGER | Epoch ms when the covering payout was marked paid    |
| `updated_at`      | INTEGER | Epoch ms of last record modification                 |

`delivered_at` is set by the DAO when `updateStatus('delivered')` or `updateFromJson` receives a `delivered` status. It is never overwritten after being set.

---

## Cleanup Behavior

Completed records (`delivered`, `rts`, `osa`) are deleted from local storage after retention windows expire:

- **Standard** (unpaid): deleted after `kLocalDataRetentionDays` days (based on `updated_at`)
- **Paid**: deleted after `kPaidDeliveryRetentionDays` day (based on `paid_at`)

The shorter paid-record window limits local data accumulation while still allowing same-day confirmation.

---

## Relationship Between Delivered Screen and History

| Screen    | Shows                                   | Removed when           |
| --------- | --------------------------------------- | ---------------------- |
| Delivered | Today's delivered + same-day paid items | Next day (midnight)    |
| History   | All sync entries, forever               | Only on cleanup delete |

History is a persistent audit trail. Delivered is a day-view operational list.

---

## API v2.0 Changes

### `is_paid` Field

Every delivery item returned by `GET /deliveries` now includes an `is_paid` boolean:

```json
{ "barcode": "FSIEE586361", "delivery_status": "delivered", "is_paid": true }
```

**Mapping rule:**

| API value       | `paid_at` in SQLite     | Effect                                     |
| --------------- | ----------------------- | ------------------------------------------ |
| `is_paid: true` | Sentinel `1` (1 ms)     | PAID badge shown; excluded from today list |
| `is_paid: false`| `null`                  | Normal visibility rules apply              |

The sentinel `1` ms value is clearly distinguishable from a real payout timestamp (which is always a large epoch value). When `PayoutDetailScreen` later calls `markAsPaid()`, the sentinel is overwritten with the real `paid_at` timestamp via the `AND (paid_at IS NULL OR paid_at <= 1)` condition.

### Bootstrap Pagination (`GET /deliveries`)

The response now uses a `pagination` key instead of `meta`:

```json
{ "data": [...], "pagination": { "current_page": 1, "last_page": 5, ... } }
```

`DeliveryBootstrapService` falls back to `meta` if `pagination` is absent, ensuring backward compatibility.

### Payout Detail (`GET /wallet/:reference`)

`daily_breakdown` is now a paginated object instead of a flat array:

```json
{ "daily_breakdown": { "data": [...days], "meta": { "current_page": 1, "last_page": 1 } } }
```

`PayoutDetailScreen` handles both shapes transparently.

### Dashboard Summary (`GET /dashboard-summary`)

The `paid=all` query parameter is now sent to ensure all delivered counts (regardless of paid status) are returned consistently.

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

