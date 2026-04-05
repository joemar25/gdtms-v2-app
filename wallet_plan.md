# Payout Account UI Refinement Plan

The goal is to streamline the payout account display by removing it from the payout request screen and making it an interactive, animated feature of the Wallet screen.

## User Review Required

> [!IMPORTANT]
> The payout account details will be hidden or collapsed by default on the Wallet screen (or only revealed when tapping the pending request). This might require the user to know where to tap to see their account. I will ensure the "Pending Payment Request" card has a visual cue or is clearly interactive.

## Proposed Changes

### Wallet Feature

#### [MODIFY] [payout_request_screen.dart](file:///c:/Users/Joemar%20Jane%20Cardi%C3%B1o/Documents/FSI-Internal/fsi-courier-app/lib/features/wallet/payout_request_screen.dart)
- Remove the `PaymentMethodCard` widget from the `_buildContent` method to eliminate redundancy.

#### [MODIFY] [wallet_screen.dart](file:///c:/Users/Joemar%20Jane%20Cardi%C3%B1o/Documents/FSI-Internal/fsi-courier-app/lib/features/wallet/wallet_screen.dart)
- Update `_EarningsCard` to be tappable when it represents a pending request.
- Add an `onTap` parameter to `_EarningsCard`.
- Implement a state variable `_showPayoutAccount` to control the visibility/expansion of the `PaymentMethodCard`.
- Use `AnimatedSize` or an `AnimationController` to smoothly reveal the `PaymentMethodCard` when triggered.
- If the card is already visible but collapsed, expand it to "show the details fully".

#### [MODIFY] [payment_method_card.dart](file:///c:/Users/Joemar%20Jane%20Cardi%C3%B1o/Documents/FSI-Internal/fsi-courier-app/lib/shared/widgets/payment_method_card.dart)
- Ensure the masking logic remains robust (showing only last 4 digits).
- Potentially add a "details" view mode if needed for the animation.

## Verification Plan

### Manual Verification
1. Open the Wallet screen.
2. Verify that the Payout Account is either hidden or in a compact state initially.
3. Tap on a "Pending Payment Request" card.
4. Observe the animation revealing the Payout Account details.
5. Verify the account number masking (••••••1234).
6. Navigate to the "Request Payout" screen and verify that the Payout Account card is no longer there.
