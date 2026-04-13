<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/core/models/bug_report_payload.dart
    lib/core/models/local_delivery.dart
    lib/core/models/photo_entry.dart
    lib/core/models/sync_operation.dart

  Update this document whenever you change any of those files.
  Each of those files carries a header comment: "DOCS: docs/core/models.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Core — Models

Data models used across the app.

## Files

| File | Model | Purpose |
|------|-------|---------|
| `local_delivery.dart` | `LocalDelivery` | A delivery record stored in SQLite |
| `sync_operation.dart` | `SyncOperation` | One sync attempt row from `sync_operations` table |
| `photo_entry.dart` | `PhotoEntry` | A photo attachment (path + type) for a delivery update |
| `bug_report_payload.dart` | `BugReportPayload` | Payload sent when a courier reports an issue |

---

## `LocalDelivery`

Maps to the `local_deliveries` SQLite table. Key fields:

| Field | Notes |
|-------|-------|
| `barcode` | Primary key |
| `courierId` | Owning courier |
| `status` | `pending`, `delivered`, `failed`, `rts`, etc. |
| `recipientName`, `address` | Display fields |
| `updatedAt` | Timestamp of last server-known update |

`LocalDeliveryDao` handles all reads/writes. Do not query the table directly from screens.

---

## `SyncOperation`

Maps to `sync_operations` table. Key fields:

| Field | Notes |
|-------|-------|
| `id` | Auto-increment |
| `barcode` | Delivery this operation belongs to |
| `status` | `pending`, `processing`, `synced`, `failed`, `conflict` |
| `error` | Server error message on failure |
| `createdAt`, `syncedAt` | Timestamps |

Any row with status `pending`, `processing`, `failed`, or `conflict` counts as an **active sync lock** on that barcode.

---

## `PhotoEntry`

Transient model — not stored in SQLite directly. Used to pass photo data through the delivery update flow.

| Field | Notes |
|-------|-------|
| `path` | Local file path after capture/pick |
| `type` | `pod`, `signature`, `other` |
| `base64` | Populated when queuing offline; cleared after upload |

---

## `BugReportPayload`

Sent to the report-issue endpoint. Includes:

- `description` — free-text from the courier.
- `deviceInfo` — OS version, app version, free storage.
- `deliveryBarcode` — optional, if the issue is delivery-specific.
