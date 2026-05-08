# Mobile API Requirements & Compliance

> [!NOTE]
> This document tracks the status of backend requirements requested by the mobile team.
> All v3.2–v3.7 requirements are now **fully implemented** as of May 5, 2026.

---

## 🏗️ Active Requirements (v3.8)

### v3.8 — Bagsakan Module Integration [PENDING]

**Request**: Implement backend support for the Bagsakan (Group Delivery) module to synchronize group metadata and delivery assignments.

1.  **Schema Update**:
    - Add `bagsakan_id` (nullable integer) to the `deliveries` table.
    - Create `bagsakan_groups` table with: `id`, `name`, `description`, `status` (enum: `pending`, `submitted`), `created_at`, `updated_at`.
2.  **New Endpoints**:
    - `GET /api/mbl/bagsakan/groups`: Fetch all active groups for the courier.
    - `POST /api/mbl/bagsakan/groups`: Create a new group (Defaults to `status: 'pending'`).
    - `PATCH /api/mbl/bagsakan/groups/{id}`: Update group metadata (Only if `pending`).
    - `DELETE /api/mbl/bagsakan/groups/{id}`: Delete group and **unassign** all deliveries associated with it.
    - `POST /api/mbl/bagsakan/groups/{id}/assign`: Bulk assign barcodes (List of strings) to a group.
    - `POST /api/mbl/bagsakan/groups/{id}/unassign`: Bulk unassign barcodes from a group.
    - `POST /api/mbl/bagsakan/groups/{id}/submit`: Finalize the Bagsakan group. All associated deliveries should be marked for bulk processing on the server.
3.  **Sync Integration**:
    - Include Bagsakan groups in the `GET /api/mbl/sync` payload.
    - Support **Soft Deletion**: Include `is_archived` (boolean) for groups to allow the mobile app to purge deleted groups during sync.
    - Ensure `bagsakan_id` is present in the `LocalDelivery` response objects in both standard and group-specific contexts.
4.  **Dispatch Acceptance**:
    - `GET /api/mbl/dispatches`: Include `bagsakan_id` and `is_bagsakan: true` flag for pre-grouped dispatches.
    - `POST /api/mbl/dispatches/{id}/accept`: When accepting a Bagsakan dispatch, the server must automatically link all associated deliveries to the `bagsakan_id` in the courier's context.
5.  **Visibility Hard Gate (MANDATORY)**:
    - **Dashboard Summary**: `GET /api/mbl/dashboard-summary` must exclude deliveries with a `bagsakan_id` from standard counts (Pending, Failed, etc.).
    - **Deliveries List**: `GET /api/mbl/deliveries` must strictly exclude items assigned to any `bagsakan_id` to prevent redundant courier workflow.
6.  **Case-Insensitivity**:
    - All barcode matching for assignment/unassignment must use `COLLATE NOCASE` (or equivalent) to ensure resilience against scanner case discrepancies.
7.  **Mobile Developer & UX Conveniences**:
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

## 🛠️ Compliance Standards (v3.7)

- **Source of Truth**: `docs/gdtms-v2-api/Courier-Mobile-API.postman_collection.json`
- **Auth**: Laravel Sanctum (Bearer Token)
- **Idempotency**: `X-Request-ID` header required for all PATCH/POST operations.
- **Encoding**: UTF-8 / JSON
