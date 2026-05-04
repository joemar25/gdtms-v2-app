<!-- MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  SOURCE OF TRUTH FOR ALL API DEFINITIONS

  File: docs/gdtms-v2-api/Courier-Mobile-API.postman_collection.json

  ┌─────────────────────────────────────────────────────────────────────────┐
  │  DEVELOPMENT RULE — ENFORCED WITHOUT EXCEPTION                          │
  │                                                                         │
  │  The Postman collection MUST be updated FIRST before any API-related    │
  │  code is written or changed in the app.                                 │
  │                                                                         │
  │  If the collection and the app code disagree, the collection wins.      │
  │  Fix the app to match the collection — not the other way around.        │
  └─────────────────────────────────────────────────────────────────────────┘

  When the collection is updated:
    1. Update this README (endpoint or field changes).
    2. Update docs/core/api.md if the client behavior changes.
    3. Update the relevant docs/features/*.md for affected screens.
    4. Then implement in the app.

  Linked from: docs/index.md, docs/core/api.md, README.md
  ══════════════════════════════════════════════════════════════════════════════
-->

# GDTMS v2 API — Courier Mobile

**Collection file**: `docs/gdtms-v2-api/Courier-Mobile-API.postman_collection.json`

**Current version**: v3.6 (May 2026)

**Auth**: Laravel Sanctum — Bearer token in `Authorization` header.

**Base URL**: `{{baseURL}}` variable mapped to `API_BASE_URL` from `dart_defines.json`.

> All authenticated routes derive the courier from the Sanctum token. No courier ID appears in URL paths.

---

## Development Workflow

```
1. API changes  →  Update Postman collection FIRST
2.              →  Update this README (endpoint / field changes)
3.              →  Update docs/features/*.md for affected screens
4.              →  Implement in app (api_client.dart, screens, DAOs)
```

Do not skip steps 1–3. Touching app code before updating the collection means the collection is
no longer the source of truth — that is documentation debt that causes future bugs.

**Mobile requirements for backend team**: [mobile-api-requirements.md](mobile-api-requirements.md) — inconsistencies the app works around + what needs fixing on the server side.

---

## Changelog

### v3.6 (May 2026)

- **NEW** Response Enhancements: `piece_count` and `piece_index` as explicit integers.
- **NEW** `allowed_statuses` array for dynamic UI button visibility.
- **NEW** `recipient_metadata` including `latitude` and `longitude`.
- **PENDING** `failed_delivery_reasons` as localized {id, label} objects.

### v3.5 (May 2026)

- **NEW** `POST /api/mbl/deliveries/bulk-update` — sync entire local queue in one request.
- **NEW** `data_checksum` (SHA256) for sync integrity validation.
- **UPDATED** Canonical Field Mapping: Standardized on `barcode`, `tracking_number`, `recipient_name`, `recipient_address`.

### v3.4 (May 2026)

- **NEW** `GET /api/mbl/sync` — unified paginated sync stream for all statuses.
- **NEW** `GET /api/mbl/app-config` — remote constants for storage, retention, and media types.
- **NEW** `GET /api/mbl/deliveries/search` — server-side search across name, phone, and address.

### v3.3 (May 2026)

- **NEW** Standardized 409 Conflict codes: `MAX_ATTEMPTS_REACHED`, `DELIVERY_IMMUTABLE`, `DUPLICATE_REQUEST`.
- **PENDING** `POST /api/mbl/deliveries/verify-status` — batch verification for Phase 0 sync.
- **PENDING** `GET /api/mbl/media/upload-params` — pre-signed URLs for direct storage uploads.

### v3.2 (May 2026)

- **REMOVED** Payment tracking logic (`is_paid`, `paid` filter) from the mobile API surface.

---

## Full Endpoint Reference

All paths are relative to `{{baseURL}}/api/mbl`.

### Authentication

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/login` | No | Login with phone + password. Returns Sanctum token. |
| POST | `/reset-password` | No | Request password reset email. |
| POST | `/logout` | Yes | Revoke current device token. |
| POST | `/logout-all` | Yes | Revoke all device tokens for this courier. |
| GET | `/` | No | API health check. |
| POST | `/change-password` | Yes | Change password (authenticated). |

**Login request body**

```json
{
  "phone_number": "09208019846",
  "password": "...",
  "device_name": "...",
  "device_identifier": "...",
  "device_type": "android | ios | flutter | web",
  "app_version": "1.0.0"
}
```

**Login response** (`data` field)

```json
{
  "token": "...",
  "session_revoked": false,
  "session_revoked_message": null,
  "user": {
    "id": 401,
    "name": "MARIA SANTOS",
    "email": "...",
    "phone_number": "...",
    "profile_picture_url": null
  },
  "courier": {
    "id": 543,
    "courier_code": "GEOFM00543",
    "courier_type": "fm",
    "branch_id": 5
  }
}
```

---

### Dispatches

| Method | Path | Description |
|--------|------|-------------|
| GET | `/pending-dispatches?page=1&per_page=10` | List pending dispatches for this courier. |
| POST | `/accept-dispatch` | Accept a dispatch. |
| POST | `/reject-dispatch` | Reject a dispatch. |
| POST | `/check-dispatch-eligibility` | Check eligibility to start dispatch. Attach device info in body. |

---

### Deliveries

| Method | Path | Description |
|--------|------|-------------|
| GET | `/deliveries` | List deliveries (slim view). |
| GET | `/deliveries/:barcode` | Full delivery detail (rich view). |
| POST | `/deliveries/:barcode/media` | Upload delivery media (non-S3 clients). |
| PATCH | `/deliveries/:barcode` | Update delivery status (POD). |
| GET | `/sync` | **v3.4** Unified sync stream for all delivery statuses. |
| GET | `/search` | **v3.4** Server-side search by name/phone/address. |
| GET | `/app-config` | **v3.4** Remote configuration constants. |
| POST | `/deliveries/bulk-update` | **v3.5** Bulk status updates for queue clearing. |
| POST | `/deliveries/verify-status` | **v3.3 (PENDING)** Batch status verification. |
| GET | `/media/upload-params` | **v3.3 (PENDING)** Pre-signed URL generation for direct uploads. |

**GET /deliveries query params**

| Param | Values | Notes |
|-------|--------|-------|
| `status` | `delivered`, `pending`, `failed`, etc. | Filter by status |
| `active` | `true` / `false` | Active deliveries only |
| `updated_since` | ISO 8601 datetime | Delta sync — returns only records changed after this timestamp |

**PATCH /deliveries/:barcode request body**

```json
{
  "delivery_status": "DELIVERED",
  "delivered_date": "2026-04-13T10:00:00+08:00",
  "recipient": "MA ELIZA SANTOS",
  "relationship": "sister",
  "placement_type": "received",
  "notes": "...",
  "latitude": 14.5995,
  "longitude": 120.9842,
  "delivery_images": [
    { "file": "https://...", "type": "POD" }
  ]
}
```

**PATCH header**: `X-Request-ID: <uuid>` — idempotency key. Generate one UUID per delivery update and reuse it on retry. The server deduplicates by this key.

> Image fields are not returned in GET or PATCH responses since v2.0. Images are managed on the web portal only.

---

### Payment and Dashboard

| Method | Path | Description |
|--------|------|-------------|
| GET | `/dashboard-summary?paid=all` | Summary counts for dashboard stats. |
| GET | `/wallet-summary` | Wallet balance and history. |
| GET | `/wallet/:reference?page=&per_page=` | Wallet detail by reference number. |
| GET | `/payment-request` | Preview a payout request before submitting. |
| POST | `/payment-request` | Submit a payout request. |

---

### Profile

| Method | Path | Description |
|--------|------|-------------|
| GET | `/me` | Get courier profile (name, branch, phone, is_active). |
| PATCH | `/me` | Update profile (username, email, names). |
| POST | `/me/media` | Upload profile picture (non-S3 clients). |
| GET | `/me/payment-method` | Get active bank or GCash account for payouts. |

---

### Real-Time Tracking

| Method | Path | Description |
|--------|------|-------------|
| POST | `/location` | Update courier GPS coordinates. |

Body: `{ "latitude": 14.5995, "longitude": 120.9842, "accuracy": 10.5 }`

---

### Notifications

| Method | Path | Description |
|--------|------|-------------|
| GET | `/notifications?page=&per_page=` | List notifications. |
| GET | `/notifications/unread-count` | Get unread notification count. |
| POST | `/notifications/:id/mark-as-read` | Mark one notification as read. |
| POST | `/notifications/mark-all-as-read` | Mark all notifications as read. |

---

### App Version

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/app/version` | No | Returns `{ min_version, force_update }`. Used by `VersionCheckService`. |

---

### Support

| Method | Path | Description |
|--------|------|-------------|
| POST | `/courier/reports` | Submit bug report with device info and severity. |

---

## Implementation Notes

- **No courier ID in URLs** — all authenticated endpoints resolve the courier from the Sanctum token.
- **Delta sync**: use `updated_since` on `GET /deliveries`. Store `updated_at` from the last response as the next `updated_since` value.
- **Offline PATCH**: always send `delivered_date` in ISO 8601 with timezone offset so the server stores the correct timestamp even for delayed offline syncs.
- **Idempotency**: generate one UUID per delivery update, send it as `X-Request-ID`. Retrying the same UUID is safe — the server deduplicates.
