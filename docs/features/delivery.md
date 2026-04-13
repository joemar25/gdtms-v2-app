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
| `delivery_update_screen.dart` | `/deliveries/:barcode/update` | POD update form (status, photos, signature) |
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

### Image compression

- Uses `FlutterImageCompress`: max width **600px**, quality **70**.
- Do not increase these — they are tuned for offline storage and upload reliability.

### Offline submit flow

1. Compress photos to base64.
2. Write row to `delivery_update_queue` with `_pending_media`.
3. Write `sync_operations` row with status `pending`.
4. Show `SuccessOverlay` (not a navigation pop).
5. `SyncManager` processes the queue on next sync cycle.

### Online submit flow

1. Compress + upload photos immediately (API or S3).
2. PATCH `/deliveries/{barcode}`.
3. Update `local_deliveries.status` in SQLite.
4. Show `SuccessOverlay`.

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
