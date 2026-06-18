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

- `GET /wallet-summary` — `total_earnings`, `tentative_pending_payout`, `has_existing_request_today`, `latest_request`, `payout_history`.
- `GET /me/payment-method` — active payout account (flip-card back).
- Payout history displayed as card list (`PayoutHistoryRow`), limited to the last 7 days (pending/processing always shown).
- Deliveries that fail visibility rules (e.g. old delivered items) show a grey `lock_outline_rounded` icon — always visible, no debug gate.

### Payout action button (Consolidate vs Request)

`latest_request.status` is the **courier-facing** status (`OPS_REJECTED` / `HR_REJECTED` are surfaced, not the raw `PENDING` / `OPS_APPROVED`).

| `latest_request.status` | New eligible? | Button | Why |
|---|---|---|---|
| _none_ / `OPS_REJECTED` / `HR_REJECTED` / `OPS_APPROVED` / `HR_APPROVED` / `PAID` | yes | **Request Payout** (new reference) | only an open `PENDING` request can be consolidated into; everything else is closed |
| `PENDING` | yes | **Consolidate** | merges into the open request (backend: `status=PENDING AND ops_status!=REJECTED`) |
| `PENDING` | no | _none_ | nothing new to add; wait for approval |
| any | — (open PENDING request created today) | **Request** disabled | once-per-day limit blocks only while an undecided request is still open; approved/paid/rejected stop blocking |

Gating (see `wallet_screen.dart` build):
- `isConsolidatable = latestStatus == 'PENDING'`
- `canConsolidate = online && isConsolidatable && eligible > 0` — **not** gated on `has_existing_request_today` (consolidation is never daily-limited).
- `canRequest = online && !isConsolidatable && !has_existing_request_today`.
- `has_existing_request_today` comes from the server (authoritative). It is `true` only while an undecided (`PENDING`, non-rejected) request created today is open — approved/paid/rejected requests do **not** block, so an OPS_APPROVED request lets the courier request again the same day. `_applyDynamicFlags` only recomputes it as a legacy/offline fallback when the field is absent.

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

1. `GET /payment-request` previews eligible deliveries (`coverage_period`, `eligible_delivery_count`, `has_existing_request_today`, `existing_request`, `daily_breakdown`, estimated totals).
2. When consolidating, `existing_request.reference` (when present) is shown in the merge notice via `wallet.request.pending_request_warning_ref`.
3. Submit calls `POST /payment-request` with `{from_date, to_date}`.
4. **Success**: navigates back with a success snackbar and bumps `walletRefreshProvider`.

### Error handling — the API returns HTTP 400 for business failures

The payout endpoint returns **HTTP 400** (not 409) for every business-rule failure: already submitted today, no completed deliveries, nothing eligible. `api_client` maps 400 → `ApiBadRequest`, so `_submit()` must handle it and surface `result.message` (the server's own reason). The `ApiConflict` (409) branch is kept for safety but is currently never hit by this endpoint.

Branches handled in `_submit()`:

| Result | Source | Shown |
|---|---|---|
| `ApiSuccess` | 200 | success snackbar, pop |
| `ApiValidationError` | 422 | first field error |
| `ApiBadRequest` | **400** | `result.message` (e.g. "already submitted a payment request today") |
| `ApiConflict` | 409 (defensive) | `result.message` |
| `ApiServerError` | 5xx | `result.message` / generic |

Do not let `ApiBadRequest` fall through to the generic catch — that swallows the real reason and shows "Failed to submit".
