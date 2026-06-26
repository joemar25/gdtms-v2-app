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

  group('parseContactNumbers', () {
    test('splits slash-separated numbers', () {
      expect(
        parseContactNumbers('09123456789 / 09987654321'),
        ['09123456789', '09987654321'],
      );
    });

    test('splits comma-separated numbers', () {
      expect(
        parseContactNumbers('09123456789 , 09987654321'),
        ['09123456789', '09987654321'],
      );
    });

    test('splits space-concatenated +63 numbers', () {
      expect(
        parseContactNumbers('+63 9609206186 +63 9355349832'),
        ['+63 9609206186', '+63 9355349832'],
      );
    });

    test('splits compact +63 numbers separated by spaces', () {
      expect(
        parseContactNumbers('+639609206186 +639355349832'),
        ['+639609206186', '+639355349832'],
      );
    });

    test('keeps internal spaces inside a single number', () {
      expect(
        parseContactNumbers('+63 960 920 6186'),
        ['+63 960 920 6186'],
      );
    });

    test('returns empty list for blank input', () {
      expect(parseContactNumbers(''), isEmpty);
      expect(parseContactNumbers('   '), isEmpty);
    });
  });

  group('resolveDeliveryContactNumbers', () {
    test('maps contact and contact_rep to separate owners', () {
      final result = resolveDeliveryContactNumbers({
        'contact': '+639609206186',
        'contact_rep': '+639355349832',
      });

      expect(result.recipient, ['+639609206186']);
      expect(result.authRep, ['+639355349832']);
    });

    test('parses multiple recipient numbers from contact field', () {
      final result = resolveDeliveryContactNumbers({
        'contact': '+639609206186/+639123456789',
      });

      expect(result.recipient, ['+639609206186', '+639123456789']);
      expect(result.authRep, isEmpty);
    });

    test('dedupes auth rep number from recipient list', () {
      final result = resolveDeliveryContactNumbers({
        'contact': '+639609206186/+639355349832',
        'contact_rep': '+639355349832',
      });

      expect(result.recipient, ['+639609206186']);
      expect(result.authRep, ['+639355349832']);
    });

    test('prefers recipient_phone over contact', () {
      final result = resolveDeliveryContactNumbers({
        'recipient_phone': '09208019846',
        'contact': '+639609206186',
      });

      expect(result.recipient, ['09208019846']);
    });
  });

  group('ContactStringFormat extension', () {
    test(
      'cleanContactNumber extracts the first number from a slash-separated list',
      () {
        const contact = '09123456789 / 09987654321';

        expect(contact.cleanContactNumber(), '09123456789');
      },
    );

    test(
      'cleanContactNumber extracts the first number from a comma-separated list',
      () {
        const contact = '09123456789 , 09987654321';

        expect(contact.cleanContactNumber(), '09123456789');
      },
    );

    test('cleanContactNumber returns original string if no separators', () {
      const contact = '09123456789';

      expect(contact.cleanContactNumber(), '09123456789');
    });

    test('cleanContactNumber returns empty string for empty input', () {
      expect(''.cleanContactNumber(), '');
    });
  });
}
