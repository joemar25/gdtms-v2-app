// DOCS: docs/features/wallet.md — update that file when you edit this one.

import 'package:fsi_courier_app/core/api/api_client.dart';

/// How the payout-detail screen should react to a `GET /wallet/{reference}`
/// result.
///
/// Pulled out of the widget so the branch logic is unit-testable in isolation.
/// The distinction is load-bearing for couriers: a genuine 404 is a terminal
/// "this payout is gone" state, while a 500 / network blip is transient and
/// must offer a retry instead of a misleading "not found" dead-end (the
/// PR2026L6BD incident, where a rejected-payout 500 showed up as "not found").
enum PayoutLoadOutcome {
  /// 2xx with a usable body — render the payout.
  success,

  /// HTTP 404 / WALLET_NOT_FOUND — the record genuinely does not exist.
  notFound,

  /// Anything else (500 / WALLET_ERROR, network, timeout, unexpected) —
  /// recoverable; surface a friendly message with a retry.
  error,
}

/// Classify an API result into the screen state it should drive.
///
/// Only an explicit [ApiNotFound] is treated as "not found"; every other
/// non-success outcome is a retryable [PayoutLoadOutcome.error]. This is the
/// inverse of the old behaviour, which mapped a 500 to the not-found state and
/// left a true 404 unhandled.
PayoutLoadOutcome classifyPayoutLoad(ApiResult<Map<String, dynamic>> result) {
  return switch (result) {
    ApiSuccess<Map<String, dynamic>>() => PayoutLoadOutcome.success,
    ApiNotFound<Map<String, dynamic>>() => PayoutLoadOutcome.notFound,
    _ => PayoutLoadOutcome.error,
  };
}
