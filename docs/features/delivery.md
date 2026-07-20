<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/features/delivery/delivery_status_list_screen.dart
    lib/features/delivery/delivery_detail_screen.dart
    lib/features/delivery/delivery_update_screen.dart
    lib/features/delivery/signature_capture_screen.dart
    lib/features/delivery/widgets/delivery_form_helpers.dart
    lib/features/delivery/widgets/delivery_geo_location_field.dart
    lib/features/delivery/widgets/delivery_recipient_cards.dart
    lib/features/delivery/widgets/delivery_signature_field.dart
    lib/features/delivery/widgets/searchable_selection_sheet.dart

  Update this document whenever you change any of those files.
  Each of those files carries a header comment: "DOCS: docs/features/delivery.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Feature — Delivery

## Files

| File | Route | Purpose |
|------|-------|---------|
| `delivery_status_list_screen.dart` | `/deliveries` | Paginated list of the courier's deliveries |
| `delivery_detail_screen.dart` | `/deliveries/:barcode` | Detail view + timeline |
| `delivery_update_screen.dart` | `/deliveries/:barcode/update` | POD update form (status, photos, signature); offline queue + `completeWrite` |
| `signature_capture_screen.dart` | `/deliveries/:barcode/signature` | Full-screen signature pad |
| `widgets/` | — | Form helpers and sub-components |

---

## `delivery_status_list_screen.dart`

### Data loading

1. Reads `local_deliveries` from SQLite via `LocalDeliveryDao`.
2. Reads active barcodes from `SyncOperationsDao.getSyncQueuedBarcodes(courierId)`.
3. Injects `_in_sync_queue: true` into matching delivery maps via `_toCardMap()`.

### Sync-lock badge

`DeliveryCard` shows a blue "PENDING SYNC" badge (`sync_lock_rounded` icon) when `_in_sync_queue` is `true`. The card is not tappable to the update screen while locked.

### Pagination

Controlled by `PaginationBar`. Page size is defined in `constants.dart`. Changing page size must not break existing scroll position.

### Screenshot protection

### Screenshot policy (support vs PII)

| Area | Screenshots |
| ---- | ----------- |
| Wallet / Dispatch / Profile / Sync | **Allowed** (no `SecureView`) for support |
| Delivery list **DELIVERED** / **MISROUTED** | **Allowed** |
| Delivery list **FOR_DELIVERY** / **FAILED_DELIVERY** | **Blocked** (`SecureView`) — active recipient PII |
| `showDeliveryAccountDetails` sheet | **Blocked** — full account name/address/phone |
| Delivery update + signature | **Blocked** — POD + recipient fields |

The list body uses `_ConditionalSecureView(secure: !_allowScreenshots)` where
`_allowScreenshots` is true for DELIVERED and MISROUTED:

- **All statuses except `DELIVERED`** are wrapped in `SecureView`, which enables OS-level screenshot/screen-recording protection (`screen_protector`).
- **The `DELIVERED` list opts out** (`secure: false`) so couriers can capture proof of delivery. This is safe because delivered cards expose **no recipient account name** — only the barcode, transaction ID/date, and product. (`_isDelivered` returns `widget.status.toUpperCase() == kStatusDelivered`.)

Protection is still globally bypassable via developer mode (`SecureViewManager.setDeveloperModeOverride`) and the `kSecureScreenshots` config flag. The detail and update screens for a delivered item remain screenshot-protected — only the list view is relaxed.

### Scan Actions

The header in `DeliveryStatusListScreen` for both `FOR_DELIVERY` and `FAILED_DELIVERY` must use **Scan POD** mode.

### Integrated Sub-Header (Failed Delivery)

The `FAILED_DELIVERY` list uses the **Integrated Header Pattern**. The sub-filters ("For Redelivery" and "For Return") are embedded in a branded, primary-colored sub-header that merges with the top app bar. This provides a unified visual experience for complex status filtering.

---

## `delivery_detail_screen.dart`

### Sections

- **Header**: barcode, recipient name, address, contact.
- **Timeline** (`_buildTimeline()`): status history — always visible (not gated by `kDebugMode`).
- **Address/Contact rows**: `onTap: null, trailingIcon: null` when `status == 'delivered'` — no interaction allowed after delivery.
- **UPDATE FAB**: disabled (grey, spinner icon, "SYNC PENDING…" label) when `_hasPendingSync == true`.

### Sync-lock rule on detail screen

Check `SyncOperationsDao.getSyncQueuedBarcodes()` on `_load()`. If the barcode is in the result, set `_hasPendingSync = true`. The FAB must remain disabled until the sync clears.

---

## `delivery_update_screen.dart`

### Purpose

Offline-first POD (proof-of-delivery) update form.

### Integrated Header Layout

The `DeliveryUpdateScreen` uses the **Integrated Header Pattern**. The `AppHeaderBar` is borderless and merges into a primary-colored sub-header containing the **Status Selector**. This ensures the most critical control (Status) is prominently featured in a high-contrast, premium branded area.

### Image compression

- Uses `FlutterImageCompress`: max width **600px**, quality **70**.
- Do not increase these — they are tuned for offline storage and upload reliability.

### Offline-First Architecture

All delivery updates follow a unified **Offline-First** flow. There are no separate "online" vs "offline" submission code paths.

1. **Form submission** — status changes persist to the sync queue + `local_deliveries` immediately.
2. **Sync registration** — `SyncOperation` with `pending` status.
3. **Side effects** — `syncWriteCoordinatorProvider.completeWrite(reason: 'submit_delivery')`:
   - refreshes lists always;
   - coalesced `requestFlush` only when `isOnlineProvider` (network + API);
   - if offline/API down, queue waits for reconnect / login / periodic / Sync Now.

System map & accuracy: [../architecture/system-map.md](../architecture/system-map.md),
[../architecture/accuracy-and-scale.md](../architecture/accuracy-and-scale.md).  
If updates look “stuck” or missing on web: [../architecture/ops-runbook.md](../architecture/ops-runbook.md)
(**queue first — never reinstall to “fix” sync**).

### Delivery Confirmation Code (conditional)

The confirmation code input on the DELIVERED form is **server-driven** per delivery via the
boolean `required_confirmation_code` field (carried through `raw_json` → `toDeliveryMap()`):

- `required_confirmation_code == true` → the `delivery_confirmation_code` field is **shown** and
  **required** (validation error if empty); the value is included in the update payload.
- `false`, `null`, or absent → the field is **hidden entirely**, not validated, and the key is
  **omitted** from the payload.

Implemented in `delivery_update_screen.dart` via the `_requiresConfirmationCode` getter
(`_delivery['required_confirmation_code'] == true`), which gates validation, the payload, and the
field rendered by `delivery_recipient_section.dart` (`confirmationCodeRequired`). No SQLite column
or `LocalDelivery` field is added — the flag rides through `raw_json`.

**Code format:** codes are **case-sensitive**, 1–50 alphanumeric, recipient-provided. The input
preserves case (`FilteringTextInputFormatter.allow([A-Za-z0-9])`, no uppercase transform),
`maxLength` 50. The flag is a **per-client** setting on the server.

**Server safety net:** if a `DELIVERED` update reaches the server without a required code (only
possible on offline flag-drift, since the app validates first), the server returns HTTP 422
`code: CONFIRMATION_CODE_REQUIRED`. `sync_manager.dart` surfaces this as a conflict and refreshes
the delivery from the server (`_refreshDeliveryFromServer`) so the local
`required_confirmation_code` flag is current and the courier can re-open the update screen and
re-enter the code.

### Operational Rules

-   **Connectivity Agnostic**: The ability to update a delivery is governed strictly by its **Status** and **Eligibility**, NOT by real-time connectivity. If an item is "available to update" (e.g., FOR_DELIVERY), the courier can process it even in a complete dead zone.
-   **Terminal Lock**: Once a delivery is marked `DELIVERED` or `OSA`, or has reached max `FAILED_DELIVERY` attempts, it is considered "locked" locally to prevent inconsistent state changes before synchronization.
-   **Sync Visibility**: Items pending server reconciliation must display the **UNSYNCED** or **PENDING SYNC** indicator on all list views.
-   **Image Integrity**: Photos are compressed (600px/70 quality) immediately upon capture to ensure they fit in the local SQLite payload and upload reliably over poor 4G/LTE connections.

---

## `signature_capture_screen.dart`

Full-screen signature pad. Returns a `Uint8List` PNG to the caller. Integrated via `delivery_signature_field.dart`.

---

## Delivery widgets

| Widget | Purpose |
|--------|---------|
| `delivery_form_helpers.dart` | Form field builders shared across the update form |
| `delivery_geo_location_field.dart` | GPS coordinates field — reads `locationProvider` |
| `delivery_recipient_cards.dart` | Recipient name, address, contact display cards |
| `delivery_signature_field.dart` | Signature preview + capture trigger |
| `searchable_selection_sheet.dart` | Bottom sheet for selecting delivery status or reason |
