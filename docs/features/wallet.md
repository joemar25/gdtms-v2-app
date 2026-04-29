<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/features/wallet/wallet_screen.dart
    lib/features/wallet/payout_detail_screen.dart
    lib/features/wallet/payout_request_screen.dart

  Update this document whenever you change any of those files.
  Each of those files carries a header comment: "DOCS: docs/features/wallet.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Feature — Wallet

## Files

| File | Route | Purpose |
|------|-------|---------|
| `wallet_screen.dart` | `/wallet` | Balance overview + payout history list |
| `payout_detail_screen.dart` | `/wallet/payout/:id` | Single payout detail + horizontal stepper |
| `payout_request_screen.dart` | `/wallet/payout/request` | Request a new payout |

---

## `wallet_screen.dart`

### Data

- `GET /wallet` — current balance and payout history.
- Payout history displayed as `DateStripWithDeliveries` or card list.
- Deliveries that fail visibility rules (e.g. old delivered items) show a grey `lock_outline_rounded` icon — always visible, no debug gate.

---

## `payout_detail_screen.dart`

### Transaction History

Tapping the history icon in the app bar triggers `showPayoutHistorySheet()`, which renders the payout status progression as a **vertical animated stepper**:

- Latest status at the top.
- Uses semantic colors (Green for `PAID`, Red for `REJECTED`).
- Displays timestamps and remarks for each event.

### Breakdown Flip Card

The `PayoutHeroFlipCard` displays the total amount on the front and flips to show a detailed tax/incentive breakdown on the back when tapped.

### Visibility lock

Cards for deliveries outside the visibility window show a grey lock icon on the trailing edge. This is not conditional on debug mode.

---

## `payout_request_screen.dart`

### Flow

1. Courier selects payout amount and method.
2. Calls `POST /wallet/payout`.
3. **Success**: navigates back with a success snackbar.
4. **`ApiConflict` (409)**: a payout request is already pending — show specific message.
5. **`ApiServerError` (5xx)**: generic server error message.

### Guard

Both `ApiConflict` and `ApiServerError` must be handled explicitly in `_submit()`. Do not let them fall through to a generic catch.
