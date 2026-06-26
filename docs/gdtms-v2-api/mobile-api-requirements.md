# Mobile API Requirements & Compliance

> [!NOTE]
> This document tracks the status of backend requirements requested by the mobile team.
> All v3.2–v3.7 requirements are now **fully implemented** as of May 5, 2026.

---

## 🏗️ Active Requirements (v4.2)

### v4.2 — Read `delivery_attempts` For 3-Attempt / For Return Classification [FIXED June 26, 2026]

#### Problem

After backend v4.2, list/sync/detail/PATCH responses expose the authoritative operational count as
`delivery_attempts`. Detail and PATCH responses do **not** always include `failed_delivery_count`.
The app only read `failed_delivery_count` / `failed_delivery_attempts[]`, so parcels with 3 real
attempts stayed in **For Redelivery** (and showed **FAILED DELIVERY**) instead of **For Return**.

#### Fix (our side)

- `lib/shared/helpers/delivery_helper.dart` — `getAttemptsCountFromMap()` reads
  `delivery_attempts`, then `failed_delivery_count` (for lock/tab rules only).
  `rawDeliveryAttemptsFromMap()` exposes `delivery_attempts` for display.
- `lib/shared/widgets/delivery_card.dart` — shows raw API `delivery_status` and
  `delivery_attempts` in the card; no client-side relabeling or derived counts.
- Tests: `delivery_helper_test.dart`, `delivery_visibility_rules_test.dart`.

#### Backend contract (no API change required)

| Field | Mobile use |
| ----- | ---------- |
| `delivery_attempts` | **Authoritative** for For Return tab, lock state, attempt badge |
| `failed_delivery_count` | List/sync alias only |
| `total_delivery_attempts` | Audit display only — do not use for limit |

---

## 🏗️ Active Requirements (v3.9)

### v3.9 — Failed Delivery `according_to` Must Be Sent As a Structured Field [FIXED June 26, 2026]

> [!NOTE]
> Mobile fix applied: `according_to` is now sent as a structured payload field via
> `DeliveryUpdateHelper.resolveAccordingTo()` (unit-tested), and is no longer appended to `note`.
> Backend was already ready. MISROUTED confirmed **out of scope** — the delivery update
> screen captures only a mailpack photo + note for misrouted (no reason/informant by design).

#### Problem (confirmed June 26, 2026)

On `UPDATE_STATUS` for `FAILED_DELIVERY` (and `MISROUTED`), the app embeds the informant inside the free-text `note` instead of sending the dedicated `according_to` field. GDTMS stores the courier value **verbatim**, so `delivery_timeline.according_to` stays `NULL` and the witness ends up baked into `remarks` as `"<narrative> | According to: <NAME>"`.

Result: the GDTMS **"Recipient/According To"** column (Delivery Reports, Product Reports, Global Search) is blank for these rows. Production audit (June 26, 2026): **159** failed/misrouted timeline rows have the informant only in `remarks`, **0** in the structured column or in metadata.

#### Root cause (our side)

`lib/features/delivery/delivery_update_screen.dart` (~line 668):

```dart
// CURRENT (wrong) — informant joined into the note
if (config.requiresAccordingTo && _accordingTo.text.trim().isNotEmpty) {
  notes.add('According to: ${_accordingTo.text.trim()}');
}
// ...
payload['note'] = notes.join(' | ');   // → "narrative | According to: NAME"
```

#### Fix (our side)

Send `according_to` as its own payload key; do **not** append it to `note`:

```dart
// FIXED — structured field
if (config.requiresAccordingTo && _accordingTo.text.trim().isNotEmpty) {
  payload['according_to'] = _accordingTo.text.trim();
}
// `note` now carries ONLY the courier's own free-text narrative
```

#### Backend contract (already supported — no API work needed)

- The status-update endpoint already validates/accepts `according_to` (`DeliveryStatusUpdateRequest`), maps it via DTO, and persists it to `delivery_timeline.according_to`.
- Reports read the structured column directly, with a `metadata.according_to` fallback (legacy/nested payloads).
- `recipient` (DELIVERED) and `according_to` (FAILED/MISROUTED) are **mutually exclusive** per row.
- A backend backfill command (`php artisan timeline:backfill-according-to`) promotes `metadata.according_to` → column where empty. It **never** parses `note`/`remarks` — courier text is stored as-is — so it only helps rows whose witness reached metadata.

#### Mobile App TODO (Our Side)

- [x] Send `according_to` as a **top-level payload field** on `FAILED_DELIVERY` updates (stop appending `"According to: ..."` to `note`). — `delivery_update_screen.dart` + `DeliveryUpdateHelper.resolveAccordingTo()`, covered by `delivery_update_helper_test.dart`.
- [x] Keep `note` for the courier's free-text narrative only (system text belongs in backend `notes`, never `remarks`).
- [x] MISROUTED confirmed out of scope — the screen captures only a mailpack photo + note for misrouted (the reason picker and "according to" field are gated to FAILED_DELIVERY only). No informant is collected by design, so none is sent.
- [ ] (Optional, for already-shipped builds) send the informant under `metadata.according_to` so the backend backfill can recover it without parsing free text.

#### Field Accuracy Audit (current app payload — `delivery_update_screen.dart`)

| Field                                                                              | Status                              |
| ---------------------------------------------------------------------------------- | ----------------------------------- |
| `delivery_status`, `transaction_at`, `latitude`/`longitude`/`geo_accuracy`         | ✅ structured                       |
| DELIVERED: `recipient`, `relationship`, `placement_type`, `delivery_confirmation_code`, `delivered_date` | ✅ structured |
| FAILED: `reason`                                                                   | ✅ structured                       |
| FAILED: `reason` + `according_to`                                                  | ✅ structured (according_to fixed June 26, 2026) |
| MISROUTED: `according_to` / `reason`                                               | ➖ N/A — screen captures only mailpack photo + note (by design) |
| `note` (courier free text)                                                         | ✅ stored as-is                     |
| media (pod / selfie / signature / mailpack / photos)                               | ✅                                  |

- **Priority**: High (data accuracy for reports + billing visualization on the GDTMS web side).
- **Owner**: Mobile app. Backend is ready; no GDTMS API change required.

---

## 🏗️ Active Requirements (v3.8)

### v3.8 — Bagsakan Module Integration [COMPLETED]

#### Mobile Integration Audit (May 8, 2026)

Status: **Aligned**. Mobile now consumes the remaining v3.8 Bagsakan endpoints and response fields.

#### Endpoint Consumption Matrix (Mobile App)

- [x] `GET /api/mbl/bagsakan/groups` — retained as fallback bootstrap path (`DeliveryBootstrapService._syncBagsakanGroupsLegacy`).
- [x] `POST /api/mbl/bagsakan/groups` — consumed via offline queue flush (`CREATE_BAGSAKAN` in `SyncManagerNotifier`).
- [x] `PATCH /api/mbl/bagsakan/groups/{id}` — consumed via offline queue flush (`UPDATE_BAGSAKAN_GROUP`).
- [x] `DELETE /api/mbl/bagsakan/groups/{id}` — consumed via offline queue flush (`DELETE_BAGSAKAN_GROUP`).
- [x] `POST /api/mbl/bagsakan/groups/{id}/assign` — consumed via offline queue flush (`ASSIGN_TO_BAGSAKAN`).
- [x] `POST /api/mbl/bagsakan/groups/{id}/unassign` — consumed via offline queue flush (`UNASSIGN_FROM_BAGSAKAN`).
- [x] `POST /api/mbl/bagsakan/groups/{id}/submit` — consumed via offline queue flush (`SUBMIT_BAGSAKAN`).
- [x] `GET /api/mbl/bagsakan/groups/{id}` — consumed in group-details screen to read `deliveries` and `propagation_source`.
- [x] `POST /api/mbl/bagsakan/groups/{id}/assign-account` — consumed in group-details UI flow with online validation and refresh.

#### v3.8 Contract Alignment Notes

- [x] `bagsakan_id` is modeled/parsed in `LocalDelivery` and persisted locally.
- [x] Local visibility hard-gate is enforced in DAO queries (`bagsakan_id IS NULL` on standard delivery/dashboard counters).
- [x] Soft deletion signal (`is_archived`) is handled in Bagsakan group upsert/purge logic.
- [x] Unified sync contract (`GET /api/mbl/sync` carrying `bagsakan_groups`) is consumed during bootstrap, with fallback to legacy groups endpoint.
- [x] `GET /api/mbl/deliveries/search?eligible_for_bagsakan=1` is now consumed by Bagsakan search when online, with local DAO fallback when offline/API fails.
- [x] Conflict intelligence payload details (`already_assigned_barcodes`, `group_name`) are surfaced in Sync UI from persisted conflict payload data.
- [x] Propagation preview flag (`propagation_source`) from group-detail API is consumed and used to prefer submit source selection.
- [x] Dispatch Bagsakan metadata (`bagsakan_id`, `is_bagsakan`) is explicitly consumed and displayed in dispatch list UI metadata.

#### Mobile App TODO (Our Side)

- [x] Integrate `GET /api/mbl/bagsakan/groups/{id}` in Bagsakan group details screen (consume server `deliveries` payload and `propagation_source`).
- [x] Add UI + API flow for `POST /api/mbl/bagsakan/groups/{id}/assign-account` (account input, submit, success/error handling, refresh sync queue).
- [x] Surface assign conflict details in UI from sync responses (`already_assigned_barcodes`, `group_name`) instead of generic conflict text.
- [x] Consume `bagsakan_groups` from `GET /api/mbl/sync` during bootstrap with a safe legacy fallback.

#### API Team TODO (Backend Side)

- [x] Confirmed `GET /api/mbl/deliveries/search` accepts both `eligible_for_bagsakan=1` and `eligible_for_bagsakan=true`.
- [x] Confirmed `GET /api/mbl/sync` always includes `bagsakan_groups` in production contract.
- [x] Confirmed assign conflict payload is stable and complete: `error_code`, `already_assigned_barcodes[]`, and per-item `group_name`.
- [x] Confirmed `GET /api/mbl/bagsakan/groups/{id}` includes `propagation_source` for each delivery item.
- [x] Confirmed `POST /api/mbl/bagsakan/groups/{id}/assign-account` validation/error contract in production (`BAGSAKAN_LOCKED`, `NO_ELIGIBLE_DELIVERIES`, etc.).
- [x] **Regression fix confirmed**: `POST /api/mbl/bagsakan/groups/{id}/submit` propagates source delivery update to all group members, including statuses, timelines, and media.

Propagation acceptance criteria (backend - VERIFIED):

1. For each target delivery in the submitted group, `deliveries.delivery_status` is updated to the propagated final status (e.g., `DELIVERED`).
2. A `delivery_timeline` row is created per propagated target delivery.
3. `delivery_media` (cloned/copied from source) is attached to each propagated target.
4. `GET /api/mbl/bagsakan/groups/{id}` and `GET /api/mbl/sync` return the propagated statuses immediately.
5. Submit endpoint response includes counts: `updated_deliveries`, `timeline_created`, `media_attached`.

Backend verification notes (May 11, 2026):

- Regression fix verified by backend team.
- All 5 acceptance criteria met.
- Test suite: 11 submit tests pass (26 assertions).

#### Recommendation

Keep regression tests around Bagsakan sync, assign conflict rendering, and propagation source selection to protect this now-complete v3.8 integration.

#### Backend Contract Status (Per Postman v3.8)

Latest `Courier-Mobile-API.postman_collection.json` now documents the previously flagged contracts:

1. `GET /api/mbl/bagsakan/groups/{id}` with `propagation_source` in delivery items.
2. `POST /api/mbl/bagsakan/groups/{id}/assign-account` endpoint and sample responses.
3. `POST /api/mbl/bagsakan/groups/{id}/submit` simplified payload and propagation behavior (verified May 11, 2026).
4. Assign conflict payload with `already_assigned_barcodes` and `group_name`.
5. `GET /api/mbl/sync` response sample that includes `bagsakan_groups` + `is_archived`.

Action now shifts to **mobile consumption/integration** of these documented contracts.

**Request**: Implement backend support for the Bagsakan (Group Delivery) module to synchronize group metadata and delivery assignments.

1. **Schema Update**:
   - Add `bagsakan_id` (nullable integer) to the `deliveries` table.
   - Create `bagsakan_groups` table with: `id`, `name`, `description`, `status` (enum: `pending`, `submitted`), `created_at`, `updated_at`.
2. **New Endpoints**:
   - `GET /api/mbl/bagsakan/groups`: Fetch all active groups for the courier.
   - `POST /api/mbl/bagsakan/groups`: Create a new group (Defaults to `status: 'pending'`).
   - `PATCH /api/mbl/bagsakan/groups/{id}`: Update group metadata (Only if `pending`).
   - `DELETE /api/mbl/bagsakan/groups/{id}`: Delete group and **unassign** all deliveries associated with it.
   - `POST /api/mbl/bagsakan/groups/{id}/assign`: Bulk assign barcodes (List of strings) to a group.
   - `POST /api/mbl/bagsakan/groups/{id}/unassign`: Bulk unassign barcodes from a group.
   - `POST /api/mbl/bagsakan/groups/{id}/submit`: Propagates source status/media to all group members. Payload: `{ "source_barcode": "...", "propagation_status": "..." }`. Status: VERIFIED.
3. **Sync Integration**:
   - Include Bagsakan groups in the `GET /api/mbl/sync` payload.
   - Support **Soft Deletion**: Include `is_archived` (boolean) for groups to allow the mobile app to purge deleted groups during sync.
   - Ensure `bagsakan_id` is present in the `LocalDelivery` response objects in both standard and group-specific contexts.
4. **Dispatch Acceptance**:
   - `GET /api/mbl/dispatches`: Include `bagsakan_id` and `is_bagsakan: true` flag for pre-grouped dispatches.
   - `POST /api/mbl/dispatches/{id}/accept`: When accepting a Bagsakan dispatch, the server must automatically link all associated deliveries to the `bagsakan_id` in the courier's context.
5. **Visibility Hard Gate (MANDATORY)**:
   - **Dashboard Summary**: `GET /api/mbl/dashboard-summary` must exclude deliveries with a `bagsakan_id` from standard counts (Pending, Failed, Misrouted, etc.).
   - **Deliveries List**: `GET /api/mbl/deliveries` must strictly exclude items assigned to any `bagsakan_id` to prevent redundant courier workflow.
6. **Case-Insensitivity**:
   - All barcode matching for assignment/unassignment must use `COLLATE NOCASE` (or equivalent) to ensure resilience against scanner case discrepancies.
7. **Mobile Developer & UX Conveniences**:
   - **Computed Counts**: `GET /api/mbl/bagsakan/groups` must return `item_count` and `delivered_count` per group to avoid client-side tallying.
   - **Eligibility Flag**: `GET /api/mbl/deliveries/search` should support an `eligible_for_bagsakan=1` flag to offload complex status/attempt filtering to the server.
   - **Conflict Intelligence**: The `assign` endpoint should return a `409 Conflict` with a list of `already_assigned_barcodes` and their current `group_name` if any barcode is already part of another group.
   - **Bulk Account Assignment**: `POST /api/mbl/bagsakan/groups/{id}/assign-account` (Payload: `account_name`) to instantly group all eligible deliveries for a client.
   - **Propagation Preview**: When querying a group, if any item is `DELIVERED`, the API should flag it as the `propagation_source: true` to help the UI highlight which data will be copied.

- **Priority**: High (Blocking v3.8 stabilization).
- **Deadline**: May 15, 2026.

---

## ✅ Completed & Standardized (Archive)

### v3.7 — Product Metadata Standardisation [COMPLETED]

**Request**: Ensure the `product` field is consistently returned in all delivery-related response payloads (`GET /deliveries`, `GET /sync`, `GET /eligibility`). And its delivery details.

- **Reason**: The mobile app has decoupled `product` from `mail_type` in the UI and database. Standardising this key across all endpoints allows for consistent branding and routing logic.
- **Status**: ✅ Mobile UI integration complete as of May 5, 2026 (Refactored to `DeliveryOtherInfoSection`).
- **Priority**: High.

### v3.7 — Backend Media Endpoint Deprecation [COMPLETED]

The mobile app now handles all S3 uploads **client-side** using AWS Signature V4 pre-signed PUT URLs.

- **Status**: ✅ Mobile side complete as of May 4, 2026. Backend multipart endpoint `POST /api/mbl/deliveries/{barcode}/media` is now obsolete.

### UI & Core Compliance Status (v3.7)

- [x] **Model Layer**: `product` and `mail_type` handled as distinct canonical fields in `LocalDelivery`.
- [x] **UI Components**: Centralized `DeliveryOtherInfoSection` implemented for `DeliveryCard` and `showDeliveryAccountDetails`.
- [x] **Media Pipeline**: Fully transitioned to direct S3 uploads.
- [x] **Delivery Card Refinement**: Standardized iconography for identifiers (Person, Barcode, Location) and strict privacy enforcement for locked items finalized.

---

### v3.6 — Business Logic Offloading [COMPLETED]

- [x] **Pre-computed Piece Counts**: Returns `piece_count` and `piece_index` as integers.
- [x] **Allowed Transitions**: `allowed_statuses` array present in all delivery objects.
- [x] **Localized Reason Codes**: `failed_delivery_reasons` available in `GET /app-config`.
- [x] **Rich Recipient Metadata**: Nested `recipient_metadata` object with coordinates and phone.

### v3.5 — Data Integrity & Canonical Mapping [COMPLETED]

- [x] **Canonical Field Mapping**: Standardized on `barcode`, `job_order`, `recipient_name`, and `recipient_address`. Legacy aliases removed.
- [x] **Data Checksums**: `data_checksum` (SHA256) present for all records.
- [x] **Bulk PATCH Endpoint**: `POST /api/mbl/deliveries/bulk-update` live.

### v3.4 — Architectural Improvements [COMPLETED]

- [x] **Unified Sync Stream**: `GET /api/mbl/sync` (delta sync via `updated_since`).
- [x] **Remote Configuration**: `GET /api/mbl/app-config` (centralized constants).
- [x] **Global Search**: `GET /api/mbl/deliveries/search` server-side filtering.

### v3.3 — Payload Efficiency [COMPLETED]

- [x] **Batch Status Verification**: `POST /api/mbl/deliveries/verify-status` (Phase 0 sync).
- [x] **Direct Media Uploads**: `GET /api/mbl/media/upload-params` (Direct-to-Storage).
- [x] **Standardized Conflict Codes**: Machine-readable error codes (409/400).

### v3.2 — Payment Payload Pruning [COMPLETED]

- [x] **Field Removal**: `is_paid` and `paid` filters stripped from mobile surface.
- [x] **Mobile Optimization**: Database schema and UI badges removed.

---

## � Offline-First Sync Strategy (Bagsakan & All Features)

### Core Principles

The mobile app implements **offline-first** architecture across all features, including Bagsakan:

1. **Local-first operations**: All data mutations (create, update, assign, unassign, submit, delete) are queued locally in SQLite before transmission.
2. **No data loss**: Operations persist across app crashes and network interruptions.
3. **Transparent sync**: Users see "PENDING SYNC" badges on affected items when offline.
4. **Strong conflict resolution**: When online, the sync manager processes operations with retry logic and conflict intelligence.

### Bagsakan Offline Behavior

#### When Offline

- **No LOCAL persistence**: Bagsakan groups and assignments are NOT stored locally as separate records beyond the sync queue.
- **Operations queued**: Any action (create group, assign items, unassign, submit, delete) is captured as a `SyncOperation` entry with status `pending`.
- **Read-only access**: Users can view previously-synced bagsakan groups (from the last online sync) but cannot modify them until connectivity is restored.
- **Preview UI disabled**: Form submission buttons show an offline indicator and prompt for retry when online.

#### When Online

- **Automatic sync initiation**: On app startup or reconnect, the `SyncManagerNotifier` processes all pending bagsakan operations.
- **Ordered execution**: Operations are executed in creation order to maintain referential integrity:
  1. `CREATE_BAGSAKAN` (new groups)
  2. `UPDATE_BAGSAKAN_GROUP` (metadata updates)
  3. `ASSIGN_TO_BAGSAKAN` (add items to groups)
  4. `UNASSIGN_FROM_BAGSAKAN` (remove items from groups)
  5. `SUBMIT_BAGSAKAN` (finalize groups)
  6. `DELETE_BAGSAKAN_GROUP` (cleanup)

- **Server state merge**: After sync, fresh bagsakan groups are fetched via `GET /api/mbl/sync` (with fallback to `GET /api/mbl/bagsakan/groups`) and upserted into the local database.

### Sync Operation Schema

All bagsakan mutations are stored in the `sync_operations` table:

```sql
CREATE TABLE sync_operations (
  id TEXT PRIMARY KEY,
  courier_id TEXT,
  barcode TEXT,                    -- 'BAGSAKAN_<groupId>' for group ops
  operation_type TEXT,             -- CREATE_BAGSAKAN, ASSIGN_TO_BAGSAKAN, etc.
  payload_json TEXT,               -- Operation-specific data (see below)
  media_paths_json TEXT,           -- N/A for bagsakan
  status TEXT,                     -- 'pending', 'processing', 'completed', 'failed', 'conflict'
  retry_count INTEGER,
  last_error TEXT,
  created_at INTEGER,
  last_attempt_at INTEGER
);
```

### Payload Structure Examples

#### CREATE_BAGSAKAN

```json
{
  "id": 42,
  "name": "Metro Manila Q1 Batch",
  "description": "High-priority medical supplies"
}
```

#### ASSIGN_TO_BAGSAKAN

```json
{
  "group_id": 42,
  "group_name": "Metro Manila Q1 Batch",
  "barcodes": ["PKG001", "PKG002", "PKG003"]
}
```

#### UNASSIGN_FROM_BAGSAKAN

```json
{
  "group_id": 42,
  "group_name": "Metro Manila Q1 Batch",
  "barcodes": ["PKG001"]
}
```

#### SUBMIT_BAGSAKAN

```json
{
  "group_id": 42,
  "source_barcode": "PKG001",
  "propagation_status": "DELIVERED",
  "barcodes": ["PKG002", "PKG003"]
}
```

#### DELETE_BAGSAKAN_GROUP

```json
{
  "id": 42,
  "group_name": "Metro Manila Q1 Batch",
  "barcodes": ["PKG001", "PKG002", "PKG003"]
}
```

### Conflict & Retry Handling

#### Idempotency

- Every bagsakan operation includes a unique `X-Request-ID` header (UUID from `SyncOperation.id`).
- Server deduplicates retries by this ID.

#### Conflict Resolution (`409 Conflict`)

- **Already assigned barcodes**: Server returns list of conflicting barcodes + their current group.
  - Local queue remains `conflict` status.
  - UI shows inline conflict details and offers manual resolution (move, unassign, skip).
  - On user action, conflict is either resolved (operation requeued) or deleted.

- **Deleted groups**: If server rejects because group no longer exists:
  - Operation automatically cleaned up from queue.
  - User is notified via toast.

#### Transient Failures (`5xx`, network timeout)

- Automatic exponential backoff (default: up to 3 retries).
- Operation remains in `failed` state until next online sync trigger.

### UI Indicators

#### Bagsakan Group Cards

- **"✓ Synced"** badge: Group exists on server.
- **"⏳ Pending Sync"** badge: Create/update operations in queue.
- **"⚠️ Sync Error"** badge: Last sync failed (with error details in popover).
- **Action buttons disabled** while offline or during sync.

#### Group Items (Deliveries)

- **"📍 In Bagsakan"**: Item assigned to group (locally or on server).
- **"⏳ Pending Assignment"**: ASSIGN operation queued.
- **"⚠️ Assignment Failed"**: Retry available.

### Connection Status Detection

The app uses `connectionStatusProvider` (Riverpod) to determine state:

```dart
enum ConnectionStatus { online, offline, apiUnreachable }

// Polled every 10 seconds:
// - NetworkConnectivity.none → offline
// - Network present + API reachability check → online or apiUnreachable
```

- **UI response**: Forms lock, sync triggers, offline banner displayed.
- **No optimistic UI**: Forms require online confirmation before showing success states.

### Data Retention & Cleanup

- **Synced operations**: Deleted after `sync_retention_days` (configurable via `GET /api/mbl/app-config`).
- **Pending operations**: Retained indefinitely until sync succeeds.
- **Conflict operations**: Retained until user resolves (max 7 days, then auto-cleaned).

---

## �🛠️ Compliance Standards (v3.7)

- **Source of Truth**: `docs/gdtms-v2-api/Courier-Mobile-API.postman_collection.json`
- **Auth**: Laravel Sanctum (Bearer Token)
- **Idempotency**: `X-Request-ID` header required for all PATCH/POST operations.
- **Encoding**: UTF-8 / JSON
