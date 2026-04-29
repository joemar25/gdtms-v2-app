import 'package:flutter_test/flutter_test.dart';
import 'package:fsi_courier_app/shared/helpers/string_helper.dart';

void main() {
  group('StatusStringFormat extension', () {
    test('toDisplayStatus converts FAILED_DELIVERY to FAILED DELIVERY', () {
      // Arrange
      const status = 'FAILED_DELIVERY';

      // Act
      final result = status.toDisplayStatus();

      // Assert
      expect(result, 'FAILED DELIVERY');
    });

    test('toDisplayStatus converts delivered to DELIVERED', () {
      // Arrange
      const status = 'delivered';

      // Act
      final result = status.toDisplayStatus();

      // Assert
      expect(result, 'DELIVERED');
    });

    test('toDisplayStatus handles unknown status by replacing underscores', () {
      // Arrange
      const status = 'SOME_UNKNOWN_STATUS';

      // Act
      final result = status.toDisplayStatus();

      // Assert
      expect(result, 'SOME UNKNOWN STATUS');
    });

    test('toDisplayStatus returns em-dash for empty string', () {
      // Arrange
      const status = '';

      // Act
      final result = status.toDisplayStatus();

      // Assert
      expect(result, '—');
    });
  });

  group('ContactStringFormat extension', () {
    test(
      'cleanContactNumber extracts the first number from a slash-separated list',
      () {
        // Arrange
        const contact = '09123456789 / 09987654321';

        // Act
        final result = contact.cleanContactNumber();

        // Assert
        expect(result, '09123456789');
      },
    );

    test(
      'cleanContactNumber extracts the first number from a comma-separated list',
      () {
        // Arrange
        const contact = '09123456789 , 09987654321';

        // Act
        final result = contact.cleanContactNumber();

        // Assert
        expect(result, '09123456789');
      },
    );

    test('cleanContactNumber returns original string if no separators', () {
      // Arrange
      const contact = '09123456789';

      // Act
      final result = contact.cleanContactNumber();

      // Assert
      expect(result, '09123456789');
    });

    test('cleanContactNumber returns empty string for empty input', () {
      // Arrange
      const contact = '';

      // Act
      final result = contact.cleanContactNumber();

      // Assert
      expect(result, '');
    });
  });
}
