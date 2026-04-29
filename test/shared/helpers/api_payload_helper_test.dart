import 'package:flutter_test/flutter_test.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';

void main() {
  group('ApiPayloadHelper', () {
    test(
      'asStringDynamicMap converts a generic Map to Map<String, dynamic>',
      () {
        // Arrange
        final input = {1: 'a', 2: 'b'};

        // Act
        final result = asStringDynamicMap(input);

        // Assert
        expect(result, isA<Map<String, dynamic>>());
        expect(result['1'], 'a');
        expect(result['2'], 'b');
      },
    );

    test('listOfMapsFromKey extracts list of maps safely', () {
      // Arrange
      final source = {
        'items': [
          {'id': 1},
          {'id': 2},
        ],
      };

      // Act
      final result = listOfMapsFromKey(source, 'items');

      // Assert
      expect(result, hasLength(2));
      expect(result[0]['id'], 1);
    });

    test(
      'listOfMapsFromKey returns empty list if key missing or not a list',
      () {
        expect(listOfMapsFromKey({}, 'missing'), isEmpty);
        expect(listOfMapsFromKey({'items': 'not a list'}, 'items'), isEmpty);
      },
    );
  });
}
