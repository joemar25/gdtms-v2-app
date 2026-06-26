import 'package:flutter_test/flutter_test.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_helper.dart';

void main() {
  group('DeliveryHelper', () {
    group('checkIsLocked', () {
      test('Given status DELIVERED, when checked, then returns true', () {
        expect(
          checkIsLocked(
            status: 'DELIVERED',
            rtsVerificationStatus: 'unvalidated',
          ),
          true,
        );
      });

      test('Given status MISROUTED, when checked, then returns true', () {
        expect(
          checkIsLocked(
            status: 'MISROUTED',
            rtsVerificationStatus: 'unvalidated',
          ),
          true,
        );
      });

      test(
        'Given status FAILED_DELIVERY with 3 attempts, when checked, then returns true',
        () {
          expect(
            checkIsLocked(
              status: 'FAILED_DELIVERY',
              rtsVerificationStatus: 'unvalidated',
              attempts: 3,
            ),
            true,
          );
        },
      );

      test(
        'Given status FAILED_DELIVERY with 1 attempt and verified, when checked, then returns true',
        () {
          expect(
            checkIsLocked(
              status: 'FAILED_DELIVERY',
              rtsVerificationStatus: 'verified_with_pay',
            ),
            true,
          );
        },
      );

      test('Given status FOR_DELIVERY, when checked, then returns false', () {
        expect(
          checkIsLocked(
            status: 'FOR_DELIVERY',
            rtsVerificationStatus: 'unvalidated',
          ),
          false,
        );
      });
    });

    group('getAttemptsCountFromMap', () {
      test('prefers delivery_attempts over failed_delivery_count (v4.2)', () {
        final data = {'delivery_attempts': 3, 'failed_delivery_count': 1};
        expect(getAttemptsCountFromMap(data), 3);
      });

      test('extracts count from delivery_attempts key', () {
        final data = {'delivery_attempts': 3};
        expect(getAttemptsCountFromMap(data), 3);
      });

      test(
        'falls back to failed_delivery_count when delivery_attempts missing',
        () {
          final data = {'failed_delivery_count': 2};
          expect(getAttemptsCountFromMap(data), 2);
        },
      );

      test('handles string numeric values on delivery_attempts', () {
        final data = {'delivery_attempts': '3'};
        expect(getAttemptsCountFromMap(data), 3);
      });

      test('returns 0 for empty map', () {
        expect(getAttemptsCountFromMap({}), 0);
      });
    });

    group('rawDeliveryAttemptsFromMap', () {
      test('returns delivery_attempts only — no fallback', () {
        expect(
          rawDeliveryAttemptsFromMap({
            'delivery_attempts': 1,
            'failed_delivery_count': 3,
          }),
          1,
        );
      });

      test('returns null when delivery_attempts is absent', () {
        expect(
          rawDeliveryAttemptsFromMap({'failed_delivery_count': 2}),
          isNull,
        );
      });
    });

    group('checkIsLockedFromMap', () {
      test('locks at 3 attempts when only delivery_attempts is present', () {
        final data = {
          'delivery_status': 'FAILED_DELIVERY',
          'rts_verification_status': 'unvalidated',
          'delivery_attempts': 3,
        };
        expect(checkIsLockedFromMap(data), isTrue);
      });

      final lockedMaps = <String, Map<String, dynamic>>{
        'DELIVERED': {'delivery_status': 'DELIVERED'},
        'MISROUTED': {'delivery_status': 'MISROUTED'},
        '3 delivery_attempts': {
          'delivery_status': 'FAILED_DELIVERY',
          'delivery_attempts': 3,
        },
        '4 delivery_attempts': {
          'delivery_status': 'FAILED_DELIVERY',
          'delivery_attempts': 4,
        },
        'string delivery_attempts': {
          'delivery_status': 'FAILED_DELIVERY',
          'delivery_attempts': '3',
        },
        'failed_delivery_count fallback': {
          'delivery_status': 'FAILED_DELIVERY',
          'failed_delivery_count': 3,
        },
        'verified_with_pay': {
          'delivery_status': 'FAILED_DELIVERY',
          'delivery_attempts': 1,
          'rts_verification_status': 'verified_with_pay',
        },
        'verified_no_pay': {
          'delivery_status': 'FAILED_DELIVERY',
          'delivery_attempts': 2,
          'rts_verification_status': 'verified_no_pay',
        },
        'dirty _sync_status': {
          'delivery_status': 'FOR_DELIVERY',
          '_sync_status': 'dirty',
        },
        'dirty sync_status alias': {
          'delivery_status': 'FOR_DELIVERY',
          'sync_status': 'dirty',
        },
        'bagsakan_id': {'delivery_status': 'FOR_DELIVERY', 'bagsakan_id': 99},
        'legacy RTS at max attempts': {
          'delivery_status': 'RTS',
          'delivery_attempts': 3,
        },
        'prefixed _rts_verification_status': {
          'delivery_status': 'FAILED_DELIVERY',
          'delivery_attempts': 1,
          '_rts_verification_status': 'verified_with_pay',
        },
      };

      for (final entry in lockedMaps.entries) {
        test('locks for ${entry.key}', () {
          expect(checkIsLockedFromMap(entry.value), isTrue);
        });
      }

      final unlockedMaps = <String, Map<String, dynamic>>{
        'FOR_DELIVERY': {'delivery_status': 'FOR_DELIVERY'},
        'FAILED_DELIVERY 1 attempt': {
          'delivery_status': 'FAILED_DELIVERY',
          'delivery_attempts': 1,
        },
        'FAILED_DELIVERY 2 attempts': {
          'delivery_status': 'FAILED_DELIVERY',
          'delivery_attempts': 2,
        },
        'FAILED_DELIVERY 2 via failed_delivery_count': {
          'delivery_status': 'FAILED_DELIVERY',
          'failed_delivery_count': 2,
        },
        'delivery_attempts overrides lower failed_delivery_count': {
          'delivery_status': 'FAILED_DELIVERY',
          'delivery_attempts': 2,
          'failed_delivery_count': 5,
        },
      };

      for (final entry in unlockedMaps.entries) {
        test('unlocked for ${entry.key}', () {
          expect(checkIsLockedFromMap(entry.value), isFalse);
        });
      }

      test('locks when only prefixed _rts_verification_status is verified', () {
        expect(
          checkIsLockedFromMap({
            'delivery_status': 'FAILED_DELIVERY',
            'delivery_attempts': 1,
            '_rts_verification_status': 'verified_with_pay',
          }),
          isTrue,
        );
      });
    });

    group('checkIsPrivacyLockedFromMap', () {
      test('bagsakan_id does not privacy-lock actionable deliveries', () {
        expect(
          checkIsPrivacyLockedFromMap({
            'delivery_status': 'FOR_DELIVERY',
            'bagsakan_id': 42,
          }),
          isFalse,
        );
      });

      test('still privacy-locks terminal statuses inside bagsakan', () {
        expect(
          checkIsPrivacyLockedFromMap({
            'delivery_status': 'DELIVERED',
            'bagsakan_id': 42,
          }),
          isTrue,
        );
      });

      test('bagsakan_id still action-locks via checkIsLockedFromMap', () {
        expect(
          checkIsLockedFromMap({
            'delivery_status': 'FOR_DELIVERY',
            'bagsakan_id': 42,
          }),
          isTrue,
        );
      });
    });

    group('isTerminalState', () {
      test('DELIVERED and MISROUTED are terminal', () {
        expect(
          isTerminalState(
            status: 'DELIVERED',
            rtsVerificationStatus: 'unvalidated',
          ),
          isTrue,
        );
        expect(
          isTerminalState(
            status: 'MISROUTED',
            rtsVerificationStatus: 'unvalidated',
          ),
          isTrue,
        );
      });

      test('FAILED_DELIVERY terminal at 3 attempts or when verified', () {
        expect(
          isTerminalState(
            status: 'FAILED_DELIVERY',
            rtsVerificationStatus: 'unvalidated',
            attempts: 3,
          ),
          isTrue,
        );
        expect(
          isTerminalState(
            status: 'FAILED_DELIVERY',
            rtsVerificationStatus: 'verified_no_pay',
            attempts: 1,
          ),
          isTrue,
        );
        expect(
          isTerminalState(
            status: 'FAILED_DELIVERY',
            rtsVerificationStatus: 'unvalidated',
            attempts: 2,
          ),
          isFalse,
        );
      });
    });

    group('isTerminalStateFromMap', () {
      test('maps delivered and for-return payloads correctly', () {
        expect(
          isTerminalStateFromMap({'delivery_status': 'DELIVERED'}),
          isTrue,
        );
        expect(
          isTerminalStateFromMap({
            'delivery_status': 'FAILED_DELIVERY',
            'delivery_attempts': 3,
          }),
          isTrue,
        );
        expect(
          isTerminalStateFromMap({'delivery_status': 'FOR_DELIVERY'}),
          isFalse,
        );
      });
    });
  });
}
