# Mobile API Requirements & Compliance

> [!NOTE]
> This document tracks the status of backend requirements requested by the mobile team. 
> All v3.2–v3.6 requirements are now **fully implemented** as of May 4, 2026.

---

## 🚀 Active / Pending New Requests
*No active requests at this time. All legacy gaps have been closed.*

---

### UI & Core Compliance Status (v3.6)
- [x] **Model Layer**: Canonical key injection enforced in `LocalDelivery.toDeliveryMap`.
- [x] **UI Components**: `DeliveryCard`, `ScanScreen`, and Payout screens purged of legacy fallbacks.
- [x] **Sync Flow**: Standardized on `barcode` for all batch verification and status updates.
- [x] **Media Pipeline**: Fully transitioned to `/upload-params` direct storage flow.

---

## ✅ Completed & Standardized (Archive)

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

## 🛠️ Compliance Standards (v3.6)
*   **Source of Truth**: `docs/gdtms-v2-api/Courier-Mobile-API.postman_collection.json`
*   **Auth**: Laravel Sanctum (Bearer Token)
*   **Idempotency**: `X-Request-ID` header required for all PATCH/POST operations.
*   **Encoding**: UTF-8 / JSON
