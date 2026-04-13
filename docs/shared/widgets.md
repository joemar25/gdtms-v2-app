<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents all files under:
    lib/shared/widgets/

  Update this document whenever you change any widget in that folder.
  Each of those files carries a header comment: "DOCS: docs/shared/widgets.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Shared — Widgets

Reusable widgets used across two or more features.

## Files

| Widget file | Export / Class | Purpose |
|-------------|---------------|---------|
| `app_header_bar.dart` | `AppHeaderBar` | Consistent app bar used on all main screens |
| `bottom_nav_bar.dart` | `BottomNavBar` | Standard bottom navigation bar |
| `confirmation_dialog.dart` | `ConfirmationDialog` | Generic yes/no dialog |
| `date_strip_with_deliveries.dart` | `DateStripWithDeliveries` | Date-grouped delivery list strip |
| `delivery_card.dart` | `DeliveryCard` | Delivery list item — normal and compact variants |
| `empty_state.dart` | `EmptyState` | Centered icon + message for empty lists |
| `floating_bottom_nav_bar.dart` | `FloatingBottomNavBar` | Floating variant of the bottom nav |
| `loading_overlay.dart` | `LoadingOverlay` | Full-screen semi-transparent loading indicator |
| `offline_banner.dart` | `OfflineBanner` | Top banner shown when `isOnlineProvider` is false |
| `offline_placeholder.dart` | `OfflinePlaceholder` | Content-area placeholder for offline state |
| `pagination_bar.dart` | `PaginationBar` | Previous/Next controls for paginated lists |
| `payment_method_card.dart` | `PaymentMethodCard` | Payout method display card |
| `scan_mode_sheet.dart` | `ScanModeSheet` | Bottom sheet to switch camera vs manual entry |
| `search_bar.dart` | `AppSearchBar` | Styled search input |
| `stat_widgets.dart` | `StatChip`, `StatCard` | Dashboard stat display widgets |
| `status_badge.dart` | `StatusBadge` | Colored pill badge for delivery/sync status |
| `success_overlay.dart` | `SuccessOverlay` | Full-screen animated success confirmation |
| `sync_progress_bar.dart` | `SyncProgressBar` | Linear progress bar shown during sync |

---

## `DeliveryCard`

Two variants controlled by the `compact` parameter:

- **Normal**: shows full address, status badge, and sync-lock badge.
- **Compact**: condensed layout — same data, smaller spacing.

### Sync-lock badge

When the delivery map contains `_in_sync_queue: true`, the card shows a blue "PENDING SYNC" badge with `sync_lock_rounded` icon. This is injected by `DeliveryStatusListScreen._toCardMap()`.

### Visibility lock icon

Deliveries outside the visibility window show a grey `lock_outline_rounded` icon on the trailing edge — always visible, no debug gate.

---

## `OfflineBanner`

Watches `isOnlineProvider` internally. Place it at the top of any screen that needs to indicate offline status. It auto-hides when the app goes online.

---

## `SuccessOverlay`

Used by `DeliveryUpdateScreen` to confirm offline queue entry. Do **not** use a navigation pop for this — the overlay stays on screen briefly, then auto-dismisses.

---

## Adding a new shared widget

1. Create the file in `lib/shared/widgets/`.
2. Add it to the table above in this doc.
3. Add the `DOCS: docs/shared/widgets.md` header comment to the new file.
