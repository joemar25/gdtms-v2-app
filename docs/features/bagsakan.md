# Bagsakan Feature

## Overview

A bagsakan is a delivery group that allows a single courier-confirmed delivery to propagate its complete delivery data to all remaining deliveries within the same group. This is designed for consolidation scenarios where multiple deliveries are handed off at one point (isahan) — one update covers all.

## Flow

### Operator side

**1. Create bagsakan** _(server-side / todo)_
Bagsakan groups are created from the server and dispatched to couriers. Operators do not manually create bagsakan groups — they appear as dispatch items tagged as bagsakan.

**2. Add deliveries**
Deliveries are bundled into the bagsakan group on the server before dispatch. A delivery is eligible to be included if its status is either **for delivery** or **failed delivery with less than 3 attempts**.

**3. Update bagsakan**
At any time before submission, the bagsakan can be updated by the operator — the name, description, or additional eligible deliveries may be added.

**4. Courier accepts the dispatch**
The courier sees the bagsakan-tagged dispatch in their dispatch list. Upon acceptance, the entire group — along with all its for-delivery items — is moved into the courier's **bagsakan list** automatically. The deliveries do not appear in the regular delivery status list at this point.

**5. Courier selects one delivery from the group**
On the delivery update page, the courier selects one delivery from the bagsakan group to update.

**6. Courier marks it as delivered**
The courier updates the selected delivery's status to delivered through the delivery update section.

**7. "Submit bagsakan" button becomes available**
Once at least one delivery inside the group has been marked as delivered, the system exposes the submit bagsakan button to the operator.

**8. Confirmation step — remove failed deliveries**
Before propagation, the operator is prompted to remove any deliveries that are being returned to the courier (failed deliveries). These items must be manually removed from the group. Once removed, they are no longer part of the bagsakan and will not receive any copied data.

**9. Confirm bagsakan delivered**
The operator confirms the final submission. This action is irreversible. The bagsakan is now **locked**.

**10. Full delivery data is copied to all remaining group items (Verified May 11, 2026)**
The complete delivery record from the 1 courier-updated delivery (source) is propagated to all remaining deliveries in the group. This includes status updates, timeline creation, and cloning of media (photos/POD). Propagation is idempotent; targets already in the terminal state are skipped.

---

### Courier side

**Dispatch list**
The courier receives a dispatch item tagged as bagsakan. This dispatch contains all the for-delivery items belonging to the group.

**Accepting the dispatch**
Upon acceptance, all deliveries within the bagsakan are moved into the courier's **bagsakan list** with a status of for delivery. They do not appear in the regular delivery status list.

**Bagsakan list lifetime**
The bagsakan remains in the courier's bagsakan list until it is submitted/delivered by the operator. Once submitted, the courier's bagsakan list entry follows the same **1-day lifetime rule** as delivered items in the regular delivery status list — it is automatically purged after 1 day from the submission/delivered timestamp. After that point it is considered stale data and is no longer shown.

**Updating a delivery**
The courier selects one delivery from the bagsakan list to update and marks it as delivered. This is the source record that the operator will later use to propagate data to the rest of the group.

### UI Standards (Modernization Parity)

To maintain a premium and consistent feel, the **Bagsakan List** must adhere to the core design system's high-fidelity patterns:

- **Visual Alignment**: Bagsakan group cards must mirror the layout of the `DeliveryCard`, including the use of `DSStyles.shadowSM` and rounded corner tokens.
- **Status Accent Bars**: Each card should feature a status-colored accent bar (left-aligned) that dynamically updates based on whether the group is a `DRAFT` or `SUBMITTED`.
- **Audit Trail (Dual Timestamps)**: For transparency, cards must display both the **Creation Date** (indicated by an "add" icon) and the **Submission Date** (indicated by a "check" icon in `DSColors.success`), if applicable.
- **Metrics Visibility**: Use the standard `InfoChip` pattern to display item counts and sync statuses (e.g., the "UNSYNCED" badge).
- **Physical Feedback**: Cards must provide high-quality touch feedback using `Material` splashes and the `BouncingCardWrapper` component.

---

## Deletion

### Eligibility

A bagsakan can only be deleted if its status is **not submitted**. Once a bagsakan has been submitted (step 9 confirmed), it is permanently locked and **deletion is not allowed**.

### Effect on group items

When a bagsakan is deleted:

- All deliveries that were assigned to the group (`bagsakan_id` pointing to this group) are **untagged** — their `bagsakan_id` is set back to `NULL`.
- These deliveries are no longer excluded from the standard visibility rules and will **re-appear in their respective status lists** (`/deliveries?status=...`), dashboard counts, and global search results based on their current status.
- No delivery data is modified — only the group association is removed.

### Effect on the courier's bagsakan list

If the operator deletes a bagsakan that the courier has already accepted:

- The bagsakan entry **remains visible on the courier's device** but is treated as regular individual deliveries from that point forward.
- Each untagged delivery re-enters the standard delivery flow and will appear in the courier's regular delivery list based on its current status.
- The courier can continue to update these deliveries normally — they are no longer grouped.

### Locked state (submitted)

Once a bagsakan reaches the submitted state:

- The record is **read-only**. No edits to name, description, or group membership are allowed.
- The **delete action is hidden/disabled** in the UI and rejected at the API/DAO level.
- Deliveries inside a submitted bagsakan retain their `bagsakan_id` permanently and remain excluded from the standard visibility views (they are considered archived within the group).

---

## Item Management

### 1. Removing Items from Group

When viewing items in a Bagsakan group (Group Items screen), removal of an item requires **explicit user confirmation** via a dialog. This is because the item is already part of an established group context, and removal changes its operational visibility (it will return to the standard delivery list).

### 2. Add/Edit Flow vs. Group List

- **Add/Edit Screen**: Assignment toggles are direct and do not require confirmation (bulk selection phase).
- **Group Items List**: Individual removals require a confirmation dialog ("Remove from Bagsakan?").
- **Propagation Source Protection**: Items designated as the "Propagation Source" (the basis for the group's status) cannot be removed from the group to maintain data integrity.

### 3. Immediate Sync

Similar to group deletion, individual item removal triggers an immediate background sync (`processQueue`) to ensure the server is notified and the item re-appears in the correct lists across all devices.

### 4. Default Update State

When opening the delivery update screen for any item within a Bagsakan group (or recovered failed deliveries), the form **always defaults to the "Delivered" status**. This allows couriers to immediately see and fill out completion details without manually switching tabs, even if the item was previously in a failed or misrouted state.

### 5. Individual Item Locking

Once an item within a Bagsakan group reaches a terminal status (e.g., **Delivered**, **OSA**, or **Verified Failed**), it is individually "sealed" and locked from further updates. Couriers are prevented from re-opening the delivery update screen for these items, and any attempt to do so will trigger an "Interaction Locked" notification. This ensures that the basis for propagation (the source record) remains stable and consistent.

---

## Sync & Connectivity Rules

### 1. Synchronization Visibility

Bagsakan group cards must display a **"UNSYNCED"** badge (using the standard `DeliveryMiniPill`) if there are any pending, failed, or conflicting sync operations associated with that group (`barcode = BAGSAKAN_{ID}`). This ensures parity with the regular delivery card identifiers.

### 2. Deletion Identity

When a Bagsakan group is deleted locally:

- The system must capture the **group name** before removal.
- The `DELETE_BAGSAKAN_GROUP` sync operation must include this name in its payload (`group_name`).
- This allows the **Sync History** screen to identify the deleted group by name instead of a generic ID.

### 3. Immediate Sync (Auto-Sync)

To ensure data integrity between the mobile device and server, an **immediate background sync** (`processQueue`) is triggered automatically after a group is deleted locally.

### 4. Connectivity Indicators

Both the **Bagsakan List** and **Bagsakan Group Details** screens must display the global `ConnectionStatusBanner`. This provides couriers with real-time feedback on their network and API availability, consistent with the rest of the application.

---

## Edge Cases

| Scenario                                                                                      | Behavior                                                                                                                                                                                          |
| --------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Delete a bagsakan with 0 deliveries                                                           | Allowed. No untagging needed. Group record is removed.                                                                                                                                            |
| Delete a bagsakan where some deliveries were already marked delivered (but not yet submitted) | Allowed. Those delivered-status deliveries are untagged and re-appear under the delivered status list.                                                                                            |
| Delete a submitted bagsakan                                                                   | **Not allowed.** UI hides the delete option; API/DAO rejects the request.                                                                                                                         |
| Delivery is removed from group mid-flow (step 8) then bagsakan is later deleted               | Delivery was already untagged at removal time. No additional action needed on delete.                                                                                                             |
| Operator deletes bagsakan after courier has accepted dispatch                                 | Deliveries are untagged server-side. On the courier's device, the bagsakan becomes individual regular deliveries. Courier can still update them normally.                                         |
| Courier has the delivery update screen open when bagsakan is deleted                          | The delivery is now a regular delivery. The update proceeds normally outside the group context.                                                                                                   |
| All deliveries are removed from the group before deletion                                     | Allowed. Bagsakan is now empty and can be deleted freely.                                                                                                                                         |
| Attempt to re-add a delivery to a submitted bagsakan                                          | **Not allowed.** Group is locked. The delivery remains in its current state.                                                                                                                      |
| Bagsakan is submitted — courier's list entry the next day                                     | Entry is automatically purged from the courier's bagsakan list after 1 day from the submission timestamp, matching the same lifetime rule as delivered items in the regular delivery status list. |
| Courier's device is offline when bagsakan is deleted                                          | Once the device reconnects and syncs, the bagsakan group is removed and affected deliveries are treated as regular deliveries on the courier's side.                                              |

---

## Rules Summary

| Rule                           | Detail                                                                                                               |
| ------------------------------ | -------------------------------------------------------------------------------------------------------------------- |
| Bagsakan creation              | Server-side only (todo). Operators do not manually create groups.                                                    |
| Eligible to add                | Status = **for delivery** OR failed delivery with < 3 attempts                                                       |
| Courier dispatch               | Courier accepts a bagsakan-tagged dispatch; all group deliveries land in the bagsakan list automatically             |
| Who updates the delivery       | Courier, via the bagsakan list → delivery update section                                                             |
| Submit button trigger          | At least 1 item in the group is marked delivered                                                                     |
| Before confirmation            | Remove all failed deliveries from group — they will not be copied                                                    |
| What gets copied               | Proof of delivery image, transaction date, and all delivery details                                                  |
| Source of copy                 | The single delivery updated by the courier                                                                           |
| Scope of copy                  | All deliveries still remaining in the bagsakan group at time of confirmation                                         |
| Delete allowed                 | Only if bagsakan is **not yet submitted**                                                                            |
| Delete effect on operator side | All group items are untagged (`bagsakan_id → NULL`); no delivery data is changed                                     |
| Delete effect on courier side  | Bagsakan remains on device but becomes individual regular deliveries                                                 |
| Submitted bagsakan             | Permanently locked — no edits, no deletions, deliveries retain group association                                     |
| Courier bagsakan list lifetime | Purged 1 day after submission/delivered timestamp — same rule as delivered items in the regular delivery status list |

---

## Database Schema

### `bagsakan_groups` Table

Stores metadata for the groups.

- `id`: INTEGER PRIMARY KEY AUTOINCREMENT
- `name`: TEXT NOT NULL
- `description`: TEXT
- `status`: TEXT NOT NULL DEFAULT `'draft'` — values: `draft` | `submitted`
- `submitted_at`: INTEGER — timestamp of when the bagsakan was confirmed delivered; used as the start of the 1-day lifetime clock on the courier side
- `created_at`: INTEGER NOT NULL
- `updated_at`: INTEGER NOT NULL

### `local_deliveries` Table

Modified to include a reference to a group.

- `bagsakan_id`: INTEGER (Reference to `bagsakan_groups.id`)

---

## Visibility Rules

### Operator (web/admin)

Deliveries assigned to a bagsakan group (`bagsakan_id IS NOT NULL`) are **excluded** from the following views:

- Dashboard status counts (`FOR_DELIVERY`, `DELIVERED`, `FAILED_DELIVERY`, `OSA`)
- Main delivery status lists (`/deliveries?status=...`)
- Global search results (unless specifically searching within bagsakan)

**Exception:** When a bagsakan is deleted, its group items are untagged (`bagsakan_id → NULL`) and immediately become visible again in the above views according to their current delivery status.

### Courier (mobile app)

- Accepted bagsakan dispatches go to the **bagsakan list**, not the regular delivery status list.
- The bagsakan list entry is purged **1 day after the submitted/delivered timestamp** (`submitted_at`), matching the same lifetime rule as delivered items in the regular delivery status list.
- If the bagsakan is deleted by the operator, the deliveries exit the bagsakan list and re-enter the courier's regular delivery list under their current status.

---

## Technical Implementation

- **DAO Filtering (Visibility Hard Gate)**: Most `LocalDeliveryDao` query methods (counts, lists, and search) strictly include `AND bagsakan_id IS NULL`. This ensures grouped items are invisible in the standard workflow.
- **Interaction Locking**: Any item with a `bagsakan_id != null` is considered "Locked" by the UI (via `checkIsLocked`). Tapping these items in search results or lists triggers a specific lock notification instead of opening the update screen.
- **Technical Propagation (v3.8)**: The submit endpoint propagates source data to all targets server-side. The mobile app reconciles these changes by immediately re-fetching the group items (`_refreshDeliveryFromServer`) after sync, ensuring the local POD and timeline stay aligned with the propagated state.
- **Delete guard**: Before executing delete, the DAO checks `status != 'submitted'`. If submitted, the operation is aborted.
- **Untagging**: On delete, an `UPDATE local_deliveries SET bagsakan_id = NULL WHERE bagsakan_id = ?` is executed before removing the `bagsakan_groups` record.
- **Courier bagsakan list lifetime**: Queries for the courier's bagsakan list filter out entries where `submitted_at` is not null and `submitted_at < (now - 1 day)`, mirroring the delivered lifetime filter in the regular delivery status list.
- **UI (operator)**: `BagsakanListScreen` handles the creation, assignment, management, and deletion flow.
- **UI (Bagsakan Form)**: Uses the **Integrated Header Pattern** with two tabs ("Info" and "Deliveries") managed by `DSSegmentedSelector`. The header is borderless and merges with a branded primary-colored sub-header.
- **UI (courier)**: Dispatch list shows bagsakan-tagged items distinctly. Accepting moves all group deliveries into the bagsakan list screen. The bagsakan list auto-purges entries past the 1-day submitted lifetime.

---

## UI Behavioral Rules

### Form Item Visibility

- **Creation Mode**: Displays all selected items in a "Pending Additions" summary list for verification.
- **Edit Mode**: Displays only the **newly added** items in a "Newly Added Items" summary list. Items that were already part of the group are hidden to keep the interface focused.

### Removal Confirmation

- **Instant Removal**: Removing an item added in the current session (not yet saved) happens instantly without a confirmation dialog.
- **Safe Removal**: Removing an item that was already part of the saved group requires a **confirmation dialog** to prevent accidental ungrouping of previously finalized items.

---

## Offline-First & Sync Implementation

### Offline Behavior

The bagsakan feature is **offline-first** — all operations are queued locally before transmission:

#### When Offline

- **No local persistence**: Bagsakan groups do not persist as cached data. Only operations are queued in the `sync_operations` table.
- **Read-only access**: Users can view previously-synced bagsakan groups (from the last online sync) but cannot create or modify them.
- **UI indicators**:
  - ConnectionStatusBanner displays at the top of forms
  - Submit/Save buttons remain visible but are logically gated (user is informed that sync requires internet)
  - Form saves are still allowed to queue locally, but success message indicates "Will sync when online"

#### When Online

- **Automatic sync**: On app startup or reconnection, the SyncManager processes all pending bagsakan operations in order:
  1. `CREATE_BAGSAKAN` (create new groups)
  2. `UPDATE_BAGSAKAN_GROUP` (update group metadata)
  3. `ASSIGN_TO_BAGSAKAN` (assign deliveries to groups)
  4. `UNASSIGN_FROM_BAGSAKAN` (remove deliveries from groups)
  5. `SUBMIT_BAGSAKAN` (finalize groups with propagation)
  6. `DELETE_BAGSAKAN_GROUP` (cleanup deleted groups)

- **Immediate flush** (when online during save): If the user saves a bagsakan group while online, the SyncManager automatically initiates queue processing so the backend has the group immediately, improving UX and preventing "group not found" errors when viewing details.

### Sync Queue Structure

All bagsakan mutations are stored as `SyncOperation` entries:

```sql
INSERT INTO sync_operations (
  id, courier_id, barcode, operation_type, payload_json, status, created_at
) VALUES (
  '<UUID>', '<courierId>', 'BAGSAKAN_<groupId>', 'CREATE_BAGSAKAN',
  '{"id":42,"name":"...","description":"..."}', 'pending', <timestamp>
);
```

### Operation Dependencies

The sync manager respects operation ordering to prevent referential integrity errors:

- **ASSIGN/UNASSIGN/DELETE operations** wait for their group's `CREATE_BAGSAKAN` to complete first.
- **SUBMIT operations** wait for their source delivery's status sync to complete (if any).
- If a dependency is not yet satisfied, the operation is re-queued as `pending` and retried on the next sync cycle.

### Conflict & Error Handling

#### Idempotency

- Every operation includes `X-Request-ID: <operation.id>` header.
- Server deduplicates retries by this ID (safe to retry).

#### Conflict Resolution (409)

- Server returns `409 Conflict` with details (`already_assigned_barcodes`, `group_name`) for assign collisions.
- Operation is marked `conflict` status; UI offers manual resolution (move, skip, delete).

#### Transient Failures (5xx, timeout)

- Automatic exponential backoff (up to 3 retries).
- Operation remains `failed` until next sync trigger.

#### Deleted Groups

- If server rejects because group no longer exists, operation is auto-cleaned with user notification.

### UI Indicators

- **"✓ Synced"** badge: Group exists on server.
- **"⏳ Pending Sync"** badge: Create/update operations queued.
- **"⚠️ Sync Error"** badge: Last sync failed (with retry option).
- **Action buttons disabled** while offline or during active sync.

### Data Retention

- **Synced operations**: Auto-deleted after `sync_retention_days` (configurable via app config).
- **Pending operations**: Retained indefinitely until sync succeeds.
- **Conflict operations**: Retained until user resolves (max 7 days auto-cleanup).
