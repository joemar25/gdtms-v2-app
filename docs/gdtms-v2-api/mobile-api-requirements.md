# Mobile API Requirements & Compliance

> [!NOTE]
> This document tracks the status of backend requirements requested by the mobile team.
> All v3.2–v3.7 requirements are now **fully implemented** as of May 5, 2026.

---

## 🏗️ Active Requirements (v3.8)

### v3.8 — Bagsakan Module Integration [PENDING]

**Request**: Implement backend support for the Bagsakan (Group Delivery) module to synchronize group metadata and delivery assignments.

1.  **Schema Update**:
    - Add `bagsakan_id` (nullable integer) to the deliveries table.
    - Create `bagsakan_groups` table with `id`, `name`, `description`, `created_at`, and `updated_at`.
2.  **New Endpoints**:
    - `GET /api/mbl/bagsakan/groups`: Fetch all active groups for the courier.
    - `POST /api/mbl/bagsakan/groups`: Create a new group.
    - `PATCH /api/mbl/bagsakan/groups/{id}`: Update group info.
    - `DELETE /api/mbl/bagsakan/groups/{id}`: Delete group (Should untag associated deliveries server-side).
    - `POST /api/mbl/bagsakan/groups/{id}/assign`: Bulk assign barcodes to a group.
3.  **Sync Integration**:
    - Include Bagsakan groups in the `GET /api/mbl/sync` payload.
    - Ensure `bagsakan_id` is present in the `LocalDelivery` response objects.
4.  **Dispatch Acceptance**:
    - `GET /api/mbl/dispatches`: Include `bagsakan_id` and `is_bagsakan: true` flag for Bagsakan group dispatches.
    - `POST /api/mbl/dispatches/{id}/accept`: When accepting a Bagsakan dispatch, the server must automatically link all associated deliveries to the `bagsakan_id` in the courier's context.

- **Priority**: High.
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
