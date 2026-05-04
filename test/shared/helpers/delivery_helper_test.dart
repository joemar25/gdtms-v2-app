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

      test('Given status OSA, when checked, then returns true', () {
        expect(
          checkIsLocked(status: 'OSA', rtsVerificationStatus: 'unvalidated'),
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
      test('extracts count from failed_delivery_count key', () {
        final data = {'failed_delivery_count': 2};
        expect(getAttemptsCountFromMap(data), 2);
      });

      test('extracts count from failed_delivery_attempts list length', () {
        final data = {
          'failed_delivery_attempts': [{}, {}],
        };
        expect(getAttemptsCountFromMap(data), 2);
      });

      test('handles string numeric values', () {
        final data = {'failed_delivery_count': '5'};
        expect(getAttemptsCountFromMap(data), 5);
      });

      test('returns 0 for empty map', () {
        expect(getAttemptsCountFromMap({}), 0);
      });
    });
  });
}
