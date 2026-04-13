<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/shared/helpers/api_payload_helper.dart
    lib/shared/helpers/date_format_helper.dart
    lib/shared/helpers/delivery_helper.dart
    lib/shared/helpers/delivery_identifier.dart
    lib/shared/helpers/formatters.dart
    lib/shared/helpers/snackbar_helper.dart
    lib/shared/helpers/string_helper.dart

  Update this document whenever you change any of those files.
  Each of those files carries a header comment: "DOCS: docs/shared/helpers.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Shared — Helpers

Stateless utility functions shared across features.

## Files

| File | Purpose |
|------|---------|
| `api_payload_helper.dart` | Builds standardized API request payloads |
| `date_format_helper.dart` | Date/time formatting utilities (locale-aware) |
| `delivery_helper.dart` | Delivery-specific logic (status label, color, icon) |
| `delivery_identifier.dart` | Parses and validates barcode formats |
| `formatters.dart` | Currency, number, and text formatters |
| `snackbar_helper.dart` | Shows styled success/error/info snackbars |
| `string_helper.dart` | String utilities (truncate, capitalize, etc.) |

---

## `api_payload_helper.dart`

Builds the standard `{ data, meta }` envelope sent to the API.

```dart
ApiPayloadHelper.build(data: { ... }, courierId: id, deviceInfo: info)
```

Called before every API write. If the envelope format changes, update this helper and this doc.

---

## `date_format_helper.dart`

- All dates from the API are in UTC. Format them to local time for display.
- Use `DateFormatHelper.toDisplay(isoString)` for consistent formatting throughout the app.
- Do not use `DateTime.parse` + `intl` directly in screens — use this helper.

---

## `delivery_helper.dart`

Maps delivery `status` strings to UI properties:

```dart
DeliveryHelper.statusLabel('delivered')  // → "Delivered"
DeliveryHelper.statusColor('failed')     // → Colors.red
DeliveryHelper.statusIcon('pending')     // → Icons.schedule
```

If a new status is added server-side, add it here first.

---

## `delivery_identifier.dart`

Validates and normalizes barcodes before they are used in API calls or SQLite queries.

---

## `snackbar_helper.dart`

```dart
SnackbarHelper.success(context, 'Saved');
SnackbarHelper.error(context, 'Upload failed');
```

Centralizes snackbar styling. Do not call `ScaffoldMessenger` directly in screens.

---

## `formatters.dart`

- `Formatters.currency(amount)` — formats to PHP currency string.
- `Formatters.compactNumber(n)` — abbreviates large numbers (e.g. 1.2K).
