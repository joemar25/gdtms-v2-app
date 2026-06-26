// Regression guard for the PR2026L6BD incident: a courier tapped a rejected
// payout whose backend detail call 500'd (WALLET_ERROR). The screen used to map
// that 500 to a "not found" dead-end and left a real 404 unhandled (blank ₱0).
//
// classifyPayoutLoad() pins the corrected mapping:
//   - only a true 404 (ApiNotFound) is "not found"
//   - every other failure (500, network, timeout, unexpected) is a retryable error
//   - 2xx is success

import 'package:flutter_test/flutter_test.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/features/wallet/payout_detail_load_outcome.dart';

void main() {
  group('classifyPayoutLoad', () {
    test('2xx success → success', () {
      const result = ApiSuccess<Map<String, dynamic>>({'success': true});
      expect(classifyPayoutLoad(result), PayoutLoadOutcome.success);
    });

    test('404 WALLET_NOT_FOUND → notFound (terminal, no retry)', () {
      const result = ApiNotFound<Map<String, dynamic>>(
        'Payment request not found.',
      );
      expect(classifyPayoutLoad(result), PayoutLoadOutcome.notFound);
    });

    test('500 WALLET_ERROR → error (retryable), NOT notFound', () {
      // The exact production failure. Must be a retryable error, never notFound.
      const result = ApiServerError<Map<String, dynamic>>(
        'Failed to retrieve payment request',
      );
      final outcome = classifyPayoutLoad(result);
      expect(outcome, PayoutLoadOutcome.error);
      expect(outcome, isNot(PayoutLoadOutcome.notFound));
    });

    test('network error → error (retryable)', () {
      const result = ApiNetworkError<Map<String, dynamic>>(
        'Network error. Check connection.',
      );
      expect(classifyPayoutLoad(result), PayoutLoadOutcome.error);
    });

    test('unexpected server error (no message) → error', () {
      const result = ApiServerError<Map<String, dynamic>>(
        'An unexpected error occurred.',
      );
      expect(classifyPayoutLoad(result), PayoutLoadOutcome.error);
    });

    test('rate limited → error (retryable), not notFound', () {
      const result = ApiRateLimited<Map<String, dynamic>>('Rate limited.');
      expect(classifyPayoutLoad(result), PayoutLoadOutcome.error);
    });
  });
}
