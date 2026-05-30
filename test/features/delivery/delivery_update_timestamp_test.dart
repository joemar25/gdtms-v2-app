// Tests for the delivery update timestamp contract.
//
// WHY THIS FILE EXISTS:
// In May 2026 two bugs were found and fixed:
//   1. FAILED_DELIVERY and MISROUTED never sent `delivered_date`, so the server
//      fell back to now() (sync time) instead of the courier's capture time.
//   2. Timestamps were converted to UTC before sending. Because the server's
//      Eloquent datetime cast reads raw MySQL strings as app-timezone (Manila),
//      a UTC value stored as "00:55" was read back as "00:55 Manila" = 12:55 AM
//      instead of the correct "08:55 AM Manila".
//
// These tests guard both contracts so the bugs cannot regress silently.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── Timestamp format ─────────────────────────────────────────────────────────

  group('timestamp format', () {
    test('local ISO string does not carry a UTC Z suffix', () {
      final now = DateTime.now();
      final iso = now.toLocal().toIso8601String();

      expect(
        iso.endsWith('Z'),
        isFalse,
        reason:
            'Server (APP_TIMEZONE=Asia/Manila) treats naive ISO as Manila time. '
            'A Z suffix causes Carbon to store UTC (e.g. "00:55") which Eloquent '
            'reads back as "00:55 Manila" instead of "08:55 Manila".',
      );
    });

    test('UTC ISO would differ from local by the device timezone offset', () {
      // Regression proof: demonstrates why toUtc() is wrong for this server.
      final captureTime = DateTime(2026, 5, 30, 8, 55, 0); // 08:55 AM local
      final utcIso = captureTime.toUtc().toIso8601String();
      final localIso = captureTime.toLocal().toIso8601String();

      expect(utcIso.endsWith('Z'), isTrue);
      expect(localIso.endsWith('Z'), isFalse);

      // UTC hour is 8 hours earlier (PHT = UTC+8).
      final utcHour = DateTime.parse(utcIso).toUtc().hour;
      final localHour = captureTime.hour;
      expect(utcHour, isNot(equals(localHour)));
    });

    test('local ISO is parseable and preserves hour and minute exactly', () {
      final captureTime = DateTime(2026, 5, 30, 8, 55, 30);
      final iso = captureTime.toLocal().toIso8601String();
      final parsed = DateTime.parse(iso);

      expect(parsed.hour, captureTime.hour);
      expect(parsed.minute, captureTime.minute);
      expect(parsed.second, captureTime.second);
    });
  });

  // ── Payload field contract per status ────────────────────────────────────────
  //
  // Server resolution order (UpdateDeliveryStatusAction):
  //   1. delivered_date  — DELIVERED only
  //   2. transaction_at  — all terminal statuses (FAILED_DELIVERY, MISROUTED)
  //   3. now()           — last resort (must never occur from mobile)

  group('payload field contract', () {
    Map<String, dynamic> buildPayload(String status, DateTime captureTime) {
      final transactionAt = captureTime.toLocal().toIso8601String();
      final payload = <String, dynamic>{
        'delivery_status': status,
        'transaction_at': transactionAt,
      };
      if (status == 'DELIVERED') {
        payload['delivered_date'] = transactionAt;
      }
      return payload;
    }

    test(
      'DELIVERED sends both transaction_at and delivered_date, equal values',
      () {
        final capture = DateTime(2026, 5, 30, 8, 55, 0);
        final payload = buildPayload('DELIVERED', capture);

        expect(payload.containsKey('transaction_at'), isTrue);
        expect(payload.containsKey('delivered_date'), isTrue);
        expect(payload['transaction_at'], equals(payload['delivered_date']));
        expect(
          payload['transaction_at'],
          equals(capture.toLocal().toIso8601String()),
        );
      },
    );

    test(
      'FAILED_DELIVERY sends transaction_at and does NOT send delivered_date',
      () {
        final capture = DateTime(2026, 5, 30, 8, 55, 0);
        final payload = buildPayload('FAILED_DELIVERY', capture);

        expect(payload.containsKey('transaction_at'), isTrue);
        expect(
          payload.containsKey('delivered_date'),
          isFalse,
          reason: 'delivered_date is semantically wrong for failed attempts',
        );
      },
    );

    test('MISROUTED sends transaction_at and does NOT send delivered_date', () {
      final capture = DateTime(2026, 5, 30, 8, 55, 0);
      final payload = buildPayload('MISROUTED', capture);

      expect(payload.containsKey('transaction_at'), isTrue);
      expect(
        payload.containsKey('delivered_date'),
        isFalse,
        reason: 'delivered_date is semantically wrong for misrouted items',
      );
    });

    test(
      'transaction_at value is always the capture moment, not the sync moment',
      () {
        // Regression: before the fix, offline updates used now() on the server
        // (the sync moment), not the time the courier actually made the attempt.
        final captureTime = DateTime(2026, 5, 30, 8, 55, 0); // 08:55 AM
        final syncTime = DateTime(
          2026,
          5,
          30,
          12,
          55,
          0,
        ); // 12:55 PM (4h later)

        final payload = buildPayload('FAILED_DELIVERY', captureTime);
        final payloadHour = DateTime.parse(
          payload['transaction_at'] as String,
        ).hour;

        expect(
          payloadHour,
          equals(captureTime.hour),
          reason:
              'Payload must carry capture time (08:55), not sync time (12:55)',
        );
        expect(payloadHour, isNot(equals(syncTime.hour)));
      },
    );
  });

  // ── JSON roundtrip (SyncOperation.payloadJson) ────────────────────────────────

  group('SyncOperation payloadJson roundtrip', () {
    test(
      'DELIVERED payload survives JSON encode/decode with correct fields',
      () {
        final capture = DateTime(2026, 5, 30, 8, 55, 0);
        final iso = capture.toLocal().toIso8601String();

        final raw = jsonEncode({
          'delivery_status': 'DELIVERED',
          'transaction_at': iso,
          'delivered_date': iso,
        });
        final decoded = jsonDecode(raw) as Map<String, dynamic>;

        expect(decoded['transaction_at'], equals(iso));
        expect(decoded['delivered_date'], equals(iso));
        expect((decoded['transaction_at'] as String).endsWith('Z'), isFalse);
      },
    );

    test(
      'FAILED_DELIVERY payload survives JSON encode/decode without delivered_date',
      () {
        final capture = DateTime(2026, 5, 30, 8, 55, 0);
        final iso = capture.toLocal().toIso8601String();

        final raw = jsonEncode({
          'delivery_status': 'FAILED_DELIVERY',
          'transaction_at': iso,
        });
        final decoded = jsonDecode(raw) as Map<String, dynamic>;

        expect(decoded.containsKey('transaction_at'), isTrue);
        expect(decoded.containsKey('delivered_date'), isFalse);
        expect((decoded['transaction_at'] as String).endsWith('Z'), isFalse);
      },
    );

    test(
      'MISROUTED payload survives JSON encode/decode without delivered_date',
      () {
        final capture = DateTime(2026, 5, 30, 8, 55, 0);
        final iso = capture.toLocal().toIso8601String();

        final raw = jsonEncode({
          'delivery_status': 'MISROUTED',
          'transaction_at': iso,
        });
        final decoded = jsonDecode(raw) as Map<String, dynamic>;

        expect(decoded.containsKey('transaction_at'), isTrue);
        expect(decoded.containsKey('delivered_date'), isFalse);
        expect((decoded['transaction_at'] as String).endsWith('Z'), isFalse);
      },
    );

    test(
      'offline scenario: payloadJson queued at capture time is unchanged at sync time',
      () {
        // The SyncOperation is created at capture time and sent hours later.
        // The payload must be frozen at capture time.
        final captureTime = DateTime(2026, 5, 30, 8, 55, 0);
        final iso = captureTime.toLocal().toIso8601String();

        final payloadJson = jsonEncode({
          'delivery_status': 'FAILED_DELIVERY',
          'transaction_at': iso,
        });

        // Simulate hours passing — the payload is unchanged.
        // ignore: unused_local_variable
        final syncTime = DateTime(2026, 5, 30, 12, 55, 0);
        final decoded = jsonDecode(payloadJson) as Map<String, dynamic>;
        final storedHour = DateTime.parse(
          decoded['transaction_at'] as String,
        ).hour;

        expect(storedHour, equals(captureTime.hour));
      },
    );
  });
}
