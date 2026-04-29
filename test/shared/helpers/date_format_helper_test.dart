import 'package:flutter_test/flutter_test.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';

void main() {
  group('DateFormatHelper', () {
    group('parseServerDate', () {
      test(
        'Given a valid ISO-8601 string with Z suffix, when parsed, then returns UTC DateTime',
        () {
          // Arrange
          const iso = '2025-03-09T15:59:00Z';

          // Act
          final result = parseServerDate(iso);

          // Assert
          expect(result, isNotNull);
          expect(result!.isUtc, true);
          expect(result.year, 2025);
          expect(result.month, 3);
          expect(result.day, 9);
        },
      );

      test(
        'Given a date string with space instead of T, when parsed, then returns valid DateTime',
        () {
          // Arrange
          const iso = '2025-03-09 15:59:00Z';

          // Act
          final result = parseServerDate(iso);

          // Assert
          expect(result, isNotNull);
          expect(result!.year, 2025);
        },
      );

      test(
        'Given a string without timezone, when parsed, then it handles it',
        () {
          // Arrange
          const iso = '2025-03-09T15:59:00';

          // Act
          final result = parseServerDate(iso);

          // Assert
          expect(result, isNotNull);
        },
      );

      test('Given null or empty input, when parsed, then returns null', () {
        expect(parseServerDate(null), isNull);
        expect(parseServerDate(''), isNull);
      });
    });

    group('formatDate', () {
      test(
        'Given an ISO string, when formatted, then returns formatted date in PST (UTC+8)',
        () {
          // Arrange
          const iso = '2025-03-09T15:00:00Z'; // 3 PM UTC -> 11 PM PST

          // Act
          final result = formatDate(iso, includeTime: true);

          // Assert
          // 2025-03-09T15:00:00Z is 2025-03-09 11:00 PM PST
          expect(result, contains('Mar 9, 2025'));
          expect(result, contains('11:00 PM'));
        },
      );

      test(
        'Given null or empty input, when formatted, then returns empty string',
        () {
          expect(formatDate(null), '');
          expect(formatDate(''), '');
          expect(formatDate('null'), '');
        },
      );
    });

    group('formatEpoch', () {
      test(
        'Given an epoch timestamp, when formatted, then returns formatted string in PST',
        () {
          // Arrange
          final ms = DateTime.utc(2025, 3, 9, 15).millisecondsSinceEpoch;

          // Act
          final result = formatEpoch(ms, includeTime: true);

          // Assert
          expect(result, contains('Mar 9, 2025'));
          expect(result, contains('11:00 PM'));
        },
      );
    });
  });
}
