<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This document is for the WEB / BACKEND team.
  It describes the finalized mobile API contract (v2.9).
  Linked from: docs/gdtms-v2-api/README.md, docs/index.md
  ══════════════════════════════════════════════════════════════════════════════
-->

# Mobile API Specification (v2.9)

**Audience**: backend / web API team
**Source of truth**: `Courier-Mobile-API.postman_collection.json` (same folder)
**Last Updated**: April 16, 2026

## 1. Core Terminology & Mapping

All endpoints must use standardized terminology for status and property prefixes. The term `RTS` is legacy and must be normalized to `FAILED_DELIVERY` for all mobile interactions.

| Field Type          | Canonical Mobile Name      | Legacy/Backend Alias      | Notes                                                   |
| :------------------ | :------------------------- | :------------------------ | :------------------------------------------------------ |
| Status Value        | `FAILED_DELIVERY`          | `RTS`                     | Normalized server-side for persistence                  |
| Attempt Counter     | `failed_delivery_count`    | `rts_count`               | Returned in lists and delta sync                        |
| Attempt History     | `failed_delivery_attempts` | `rts_attempts`            | Returned in detail and PATCH responses                  |
| Verification Status | `rts_verification_status`  | `rts_verification_status` | **Exception**: Field name is retained for compatibility |

### Failed Delivery (RTS) Verification Rules

Backend must return one of the following lowercase values for `rts_verification_status`:

- `unvalidated`: Initial state (not yet checked by admin).
- `verified_with_pay`: Courier is eligible for payout.
- `verified_no_pay`: Courier is NOT eligible for payout.

## 2. API Data Consistency

### Barcode Primary Key

`barcode_value` is the primary identifier. It must be used consistently across all response payloads (`GET /deliveries`, `GET /deliveries/:barcode`, and `PATCH` responses).

### Media Type Acceptance

`POST /deliveries/:barcode/media` must accept the following types in the `type` field:

- `pod` (Proof of Delivery)
- `selfie`
- `recipient_signature`
- `other`

### Response Shapes

- **Media Upload**: `POST` to media endpoints must return the URI under `data.url`.
- **Status Mapping**:
  - `PENDING` (or `FOR_DELIVERY`) -> Pending
  - `DELIVERED` -> Delivered
  - `FAILED_DELIVERY` -> Failed Delivery
  - `OSA` -> Out of Service Area (Misrouted)

## 3. Reliability & Sync Logic

### Machine-Readable Conflict Errors

`409 Conflict` responses must include a `code` field for mobile auto-resolution:

- `DELIVERY_IMMUTABLE`: Record is in terminal state (DELIVERED/OSA).
- `SAME_STATUS_TRANSITION`: Payload status is already the current server status.
- `DUPLICATE_REQUEST`: `X-Request-ID` already processed.
- `UNSYNCED_DELIVERIES`: Pending syncs prevent this action (e.g., dispatch check).

### Idempotency & Persistence

- **X-Request-ID**: Server must honor this header for all state-changing requests (PATCH), caching the 200 result for 24h to handle retries.
- **delivered_date**: PATCH payloads may include an ISO 8601 UTC timestamp. The server must preserve this as the authoritative transaction time.

### Dispatch Eligibility

`POST /check-dispatch-eligibility` must validate `free_storage_gb` against the server-side threshold and return structured `ineligible` reasons if rejected.
