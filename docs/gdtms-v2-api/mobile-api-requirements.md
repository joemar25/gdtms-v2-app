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
**Current API version**: v2.3

This document describes what the mobile app needs from the API to work correctly,
with special attention to inconsistencies the app currently works around in code.
Each item is graded:

- **CRITICAL** — the mobile app has a fragile workaround; a wrong server response causes silent data loss or a sync failure
- **HIGH** — causes poor UX or requires extra API calls that should be unnecessary
- **NICE TO HAVE** — improvement with no current workaround cost

---

## 1. CRITICAL — Barcode field name must be consistent

**Where it hurts**: `delivery_bootstrap_service.dart` — every page parse

The app currently tries three field names to find the barcode:

```dart
item['barcode_value'] ?? item['barcode'] ?? item['tracking_number']
```

This happens on every delivery list response. If the API changes which field it uses,
or returns a new one, the mobile app silently drops items.

**What we need**:

- **Pick one field and use it everywhere**: `barcode_value` is preferred (already the primary key in SQLite).
- Apply it consistently across:
  - `GET /deliveries` (list)
  - `GET /deliveries/:barcode` (detail)
  - `PATCH /deliveries/:barcode` (response)
- If renaming is not possible, return **all three** as aliases until the mobile app ships a
  version that only reads one.

---

## 2. CRITICAL — Delivery status casing must be consistent

**Where it hurts**: `delivery_bootstrap_service.dart`, `sync_manager.dart`, `local_delivery_dao.dart`

The app calls `toUpperCase()` before writing to SQLite and `toUpperCase()`/`toLowerCase()`
before sending PATCH payloads. This is because the API has returned both `DELIVERED` and
`delivered` depending on the endpoint version.

**What we need**:

- All status strings from the API (list, detail, PATCH response) must use **UPPERCASE**
  consistently: `PENDING`, `DELIVERED`, `RTS`, `OSA`, `FAILED`.
- The PATCH body sent by the mobile uses `delivery_status` (UPPERCASE value).
  The server must accept that field name and casing without variation.

---

## 3. CRITICAL — Media upload endpoint must accept all types, not just `pod` and `selfie`

**Where it hurts**: `api_client.dart` — `uploadMedia()` comment and routing logic

```dart
// type is NOT pod/selfie (i.e. recipient_signature, other) → S3 forced,
// because the API upload endpoint only accepts pod / selfie.
```

When S3 is disabled (`USE_S3_UPLOAD=false`), uploading a `recipient_signature` type
currently falls back to the API endpoint even though that endpoint rejects it.
This silently drops the signature.

**What we need**:

- `POST /deliveries/:barcode/media` must accept the following types without restriction:
  - `pod`
  - `selfie`
  - `recipient_signature`
  - `other`
- The response must return the uploaded URL under a **single consistent field** (see item 4).

---

## 4. HIGH — Media upload response URL field must be consistent

**Where it hurts**: `sync_manager.dart` — after every `uploadMedia()` call

The app tries four field names to extract the returned URL:

```dart
inner['url'] ?? inner['signed_url'] ?? inner['file'] ?? inner['path']
```

If none of these match, the upload is silently treated as failed even though the server
accepted it — the delivery goes into a retry loop.

**What we need**:

- `POST /deliveries/:barcode/media` and `POST /me/media` must always return the URL under
  the same field: **`url`** inside a `data` object.

Expected response shape:

```json
{
  "success": true,
  "data": {
    "url": "https://..."
  }
}
```

---

## 5. HIGH — Pagination meta key must be consistent

**Where it hurts**: `delivery_bootstrap_service.dart` — every paginated call

The app checks two field names for pagination:

```dart
final meta = data['pagination'] ?? data['meta'];
```

If neither is present, pagination stops at page 1, silently dropping all subsequent pages.

**What we need**:

- All paginated responses must use **one key**: `pagination` (preferred, already used in
  most endpoints) or `meta` — pick one and apply it everywhere.
- The pagination object must always include: `current_page`, `last_page`, `per_page`, `total`.

---

## 6. HIGH — Conflict errors need machine-readable codes, not parsed strings

**Where it hurts**: `sync_manager.dart` — auto-resolve logic

The app currently parses error message strings to decide how to handle conflicts:

```dart
// "This item is DELIVERED and immutable" → auto-resolve as synced
errorMsg.toLowerCase().contains('delivered') &&
errorMsg.toLowerCase().contains('immutable')

// "Invalid status transition from 'RTS' to 'RTS'" → auto-resolve
errorMsg.toLowerCase().contains('invalid status transition') &&
errorMsg.toLowerCase().contains("to '$targetStatus'")
```

This string-matching breaks if the error message wording changes even slightly.

**What we need**:

All 409 Conflict responses must include a machine-readable `code` field:

```json
{
  "message": "This delivery is already DELIVERED and cannot be updated.",
  "code": "DELIVERY_IMMUTABLE"
}
```

Suggested codes the mobile app cares about:

| Code | Meaning |
|------|---------|
| `DELIVERY_IMMUTABLE` | Delivery is in a terminal state and cannot be changed |
| `SAME_STATUS_TRANSITION` | Requested status is already the current status |
| `DUPLICATE_REQUEST` | `X-Request-ID` already processed |
| `UNSYNCED_DELIVERIES` | Courier has pending syncs, dispatch not allowed |

---

## 7. HIGH — `GET /deliveries` delta sync (`updated_since`) must return `updated_at` on every item

**Where it hurts**: `delivery_bootstrap_service.dart` — `_syncDelta()`

The delta sync flow (`updated_since` query param) was introduced in v2.1. The app stores
the timestamp of the last sync and uses it as `updated_since` on the next call. This only
works if every item in the list response includes `updated_at` so the app knows what
timestamp to use next.

**What we need**:

- Every item in `GET /deliveries` list responses must include `updated_at` (ISO 8601, UTC).
- The `updated_since` filter must be inclusive and timezone-aware (the app sends UTC ISO 8601).

---

## 8. HIGH — `X-Request-ID` idempotency must be enforced server-side

**Where it hurts**: `sync_manager.dart` — PATCH call

The app sends `X-Request-ID` (a UUID per sync operation) on every `PATCH /deliveries/:barcode`.
On retry (network failure), the same UUID is sent again. If the server does not deduplicate,
the delivery gets processed twice — double delivery_images entries, duplicate status transitions.

**What we need**:

- The server must store `X-Request-ID` per PATCH and return `200` (not `409`) if the same
  UUID is received again, treating it as a successful duplicate rather than a conflict.
- Response on duplicate: return the same response as the original successful PATCH.

---

## 9. HIGH — `delivered_date` must be stored and returned as-is (device timestamp)

**Where it hurts**: `sync_manager.dart` — PATCH payload building

For offline deliveries, the app sends `delivered_date` with the device's local timestamp
(ISO 8601 with timezone offset). This is the actual time the delivery was made, not the
time it was synced.

**What we need**:

- The server must store `delivered_date` as the authoritative delivery time when provided.
- Fall back to `NOW()` only when `delivered_date` is absent.
- The `transaction_at` field in the PATCH response must echo back whatever was stored.
- Do not normalize `delivered_date` to UTC silently — return it in the same format it was
  received, or clearly document the stored format.

---

## 10. HIGH — `POST /check-dispatch-eligibility` must accept and validate device info

**Where it hurts**: `dispatch_eligibility_screen.dart`

The app attaches device info (free storage GB, OS version, app version) to the eligibility
request so the server can block dispatch for devices that don't meet minimum specs.

**What we need**:

- The endpoint must accept and validate these fields in the request body:

```json
{
  "free_storage_gb": 3.5,
  "os_version": "Android 14",
  "app_version": "1.2.0",
  "device_type": "android"
}
```

- Return a clear `ineligible` reason when storage is below the server's threshold.
- Document the minimum `free_storage_gb` threshold so the mobile app can show a warning
  before the courier even tries to start dispatch.

---

## 11. NICE TO HAVE — Rate-limit responses must include `Retry-After` header

**Where it hurts**: `api_client.dart` — 429 handling

The app reads `Retry-After` (seconds) on 429 responses to show the courier how long to wait.
Without the header, the app shows a generic "please wait" message with no countdown.

**What we need**:

- All 429 responses must include: `Retry-After: <seconds>` in the response header.

---

## 12. NICE TO HAVE — `GET /deliveries/:barcode` should return 404 for missing/reassigned items

**Where it hurts**: `delivery_bootstrap_service.dart` — `_reconcileOneBarcode()`

During priority reconciliation, the app calls `GET /deliveries/:barcode` for barcodes
that disappeared from the pending list. If the item was reassigned to another courier,
the server currently returns a 403 or an empty 200. The app cannot tell the difference
between "gone" and "permission denied".

**What we need**:

- `GET /deliveries/:barcode` returns `404` when the barcode exists but is not assigned
  to the authenticated courier (or was cancelled/removed).
- Returns `403` only for actual authentication/authorization failures.

---

## Summary Table

| # | Severity | Endpoint(s) | Issue | Workaround in app |
|---|----------|-------------|-------|-------------------|
| 1 | CRITICAL | GET /deliveries, GET /deliveries/:barcode | Barcode field name inconsistency | Tries 3 field names |
| 2 | CRITICAL | GET /deliveries, PATCH /deliveries/:barcode | Status casing inconsistency | `toUpperCase()` everywhere |
| 3 | CRITICAL | POST /deliveries/:barcode/media | Only accepts `pod` and `selfie` types | Forces S3 for other types |
| 4 | HIGH | POST /deliveries/:barcode/media, POST /me/media | URL field name inconsistency in response | Tries 4 field names |
| 5 | HIGH | All paginated endpoints | Pagination key inconsistency (`pagination` vs `meta`) | Tries both keys |
| 6 | HIGH | PATCH /deliveries/:barcode (409 response) | No machine-readable error codes | Parses error message strings |
| 7 | HIGH | GET /deliveries | `updated_at` not always present | Delta sync may miss items |
| 8 | HIGH | PATCH /deliveries/:barcode | `X-Request-ID` not deduplicated server-side | Risk of double processing |
| 9 | HIGH | PATCH /deliveries/:barcode | `delivered_date` may be ignored | Falls back to server NOW() |
| 10 | HIGH | POST /check-dispatch-eligibility | Device info not validated | App checks storage locally |
| 11 | NICE | All rate-limited endpoints | No `Retry-After` header on 429 | Generic "please wait" shown |
| 12 | NICE | GET /deliveries/:barcode | 403 vs 404 ambiguity for reassigned items | Left for Phase 2 cleanup |
