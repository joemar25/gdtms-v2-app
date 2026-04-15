<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This document is for the WEB / BACKEND team.
  It describes what the mobile app expects from the API and what currently
  requires workarounds on the client side due to inconsistencies.

  Update this file whenever a backend fix lands or a new mobile requirement is confirmed.
  Linked from: docs/gdtms-v2-api/README.md, docs/index.md
  ══════════════════════════════════════════════════════════════════════════════
-->

# Mobile API Requirements

**Audience**: backend / web API team
**Source of truth**: `Courier-Mobile-API.postman_collection.json` (same folder)
**Current API version**: v2.8

> **Alignment status (as of April 2026)**
> All legacy `RTS` (Return to Sender) terminology has been systematically replaced
> with `FAILED_DELIVERY`. The mobile app now uses `FAILED_DELIVERY` as the primary
> status and `failed_delivery` for all associated attempt and verification fields.

---

## 1. Terminology Enforcement — No 'RTS'

**Status**: **MANDATORY**
**Requirement**: All endpoints must use `FAILED_DELIVERY` (uppercase) for status and `failed_delivery` (snake_case) for property prefixes.

| Legacy Field / Value      | New Field / Value          | Notes                                                 |
| :------------------------ | :------------------------- | :---------------------------------------------------- |
| `RTS` (status)            | `FAILED_DELIVERY`          | Handled by SQLite migration v11                       |
| `rts_attempts`            | `failed_delivery_attempts` | List of objects                                       |
| `rts_attempt`             | `failed_delivery_attempt`  | Also accepts `delivery_attempt` as replacement        |
| `rts_verification_status` | `rts_verification_status`  | `unvalidated`, `verified_with_pay`, `verified_no_pay` |

**Backend Implementation Rule**:

- `unvalidated`: Not yet checked by admin.
- `verified_with_pay`: Validated failed delivery; courier is eligible for payout.
- `verified_no_pay`: Validated failed delivery; courier is NOT eligible for payout.

**What we need**:

- The backend must NOT return any keys containing `rts_`.
- The backend must return `failed_delivery_attempts` instead of `rts_attempts`.

---

## 2. CRITICAL — Barcode field name must be consistent

**Where it hurts**: `delivery_bootstrap_service.dart` — every page parse

**Status**: **RESOLVED v2.8**
**Requirement**: Pick one field and use it everywhere. `barcode_value` is the primary key in SQLite.

- Apply it consistently across:
  - `GET /deliveries` (list)
  - `GET /deliveries/:barcode` (detail)
  - `PATCH /deliveries/:barcode` (status update)

---

## 3. CRITICAL — Media upload endpoint must accept all machine-types

**Where it hurts**: `api_client.dart` — `uploadMedia()` routing logic

**Status**: **RESOLVED v2.8**
**Requirement**: `POST /deliveries/:barcode/media` must accept the following types without restriction:

- `pod`
- `selfie`
- `recipient_signature`
- `other`

---

## 4. HIGH — Media upload response URL field must be consistent

**Where it hurts**: `sync_manager.dart`

**Status**: **RESOLVED v2.8**
**Requirement**: `POST /deliveries/:barcode/media` and `POST /me/media` must always return the URL under a single field: **`url`** inside a `data` object.

Expected response:

```json
{
  "success": true,
  "data": {
    "url": "https://..."
  }
}
```

---

## 5. HIGH — Conflict errors need machine-readable codes

**Where it hurts**: `sync_manager.dart` — auto-resolve logic

**Status**: **RESOLVED v2.8**
**Requirement**: Return a `code` field in 409 Conflict responses.

| Code                     | Meaning                                         |
| :----------------------- | :---------------------------------------------- |
| `DELIVERY_IMMUTABLE`     | Delivery is in a terminal state (DELIVERED/OSA) |
| `SAME_STATUS_TRANSITION` | Requested status is already the current status  |
| `DUPLICATE_REQUEST`      | `X-Request-ID` already processed                |
| `UNSYNCED_DELIVERIES`    | Courier has pending syncs, dispatch not allowed |

---

## 6. HIGH — `X-Request-ID` idempotency

**Where it hurts**: `sync_manager.dart` — PATCH retries

**Status**: **RESOLVED v2.8**
**Requirement**: The server must store `X-Request-ID` per PATCH and return `200` (not `409`) if the same UUID is received again.

---

## 7. HIGH — `delivered_date` device timestamp preservation

**Where it hurts**: `sync_manager.dart`

**Status**: **RESOLVED v2.8**
**Requirement**: The server must store and echo back the `delivered_date` provided in the PATCH payload if it exists (offline delivery time), falling back to `NOW()` only if absent.

---

## 8. HIGH — Device Eligibility Validation

**Where it hurts**: `dispatch_eligibility_screen.dart`

**Status**: **RESOLVED v2.8**
**Requirement**: `POST /check-dispatch-eligibility` must validate `free_storage_gb` and return clear `ineligible` reasons.

---

## Appendix: Legacy Status Mapping

| Status value (API) | Display label   | Notes                       |
| :----------------- | :-------------- | :-------------------------- |
| `PENDING`          | Pending         | Also accepts `FOR_DELIVERY` |
| `DELIVERED`        | Delivered       |                             |
| `FAILED_DELIVERY`  | Failed Delivery | Replaces legacy `RTS`       |
| `OSA`              | Misrouted       | Out of Serviceable Area     |
