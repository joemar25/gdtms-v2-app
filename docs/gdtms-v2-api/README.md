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

**Current version**: v2.3 (April 2026)

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

### v2.3 (April 2026)

- **NEW** `GET /app/version` — returns `{ min_version, force_update }`. No auth required.
- **NEW** `POST /courier/reports` — submit bug reports with device info and severity. Requires auth.

### v2.2 (April 2026)

- **NEW** `GET /me/payment-method` — active bank account for payouts. Includes auto-provisioning message.
- **NEW** Dynamic payout validation — any active bank accepted (removed GCash/BDO-only restriction).
- **NEW** Auto-provisioning fallback — if no active bank exists on payout submit, a default GCash (00000000) account is created automatically.

### v2.1 (April 2026)

- **NEW** `GET /me` and `PATCH /me` — courier profile read/update.
- **NEW** `POST /me/media` — profile picture upload (non-S3 clients).
- **NEW** `delivered_date` field on `PATCH /deliveries/:barcode` — honors device timestamp for offline sync; falls back to `NOW()` when absent.
- **NEW** `X-Request-ID` idempotency header on `PATCH /deliveries/:barcode` — prevents duplicate processing on retry.
- **NEW** `transaction_at` echoed in PATCH response — mobile confirms what was stored.
- **NEW** `updated_since` query param on `GET /deliveries` — delta sync (1 call instead of 4).
- **NEW** `updated_at` on every delivery list item — use as next `updated_since` value.

### v2.0 (March 2026)

- **NEW** `is_paid` boolean on each delivery item.
- **NEW** `paid` query param on deliveries and dashboard-summary endpoints.
- **NEW** Slim List View vs Rich Detail View for deliveries.
- **UPDATED** Payout API response cleanup (removed redundant timestamps, added history snapshot).
- **UPDATED** Image fields (`media`, `signature`, `rts attempt images`) removed from all GET/PATCH delivery responses. Images are read-only on the web portal via signed URLs.

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

**GET /deliveries query params**

| Param | Values | Notes |
|-------|--------|-------|
| `status` | `delivered`, `pending`, `failed`, etc. | Filter by status |
| `active` | `true` / `false` | Active deliveries only |
| `paid` | `true`, `false`, `all` | Payment filter |
| `updated_since` | ISO 8601 datetime | Delta sync — returns only records changed after this timestamp |

**PATCH /deliveries/:barcode request body**

```json
{
  "status": "delivered",
  "delivered_date": "2026-04-13T10:00:00+08:00",
  "recipient_name": "...",
  "notes": "...",
  "latitude": 14.5995,
  "longitude": 120.9842,
  "media_urls": ["https://..."],
  "signature_url": "https://..."
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
