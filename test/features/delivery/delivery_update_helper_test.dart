import 'package:flutter_test/flutter_test.dart';
import 'package:fsi_courier_app/features/delivery/helpers/delivery_update_helper.dart';

void main() {
  group('DeliveryUpdateHelper.isDirty', () {
    test('returns false when all fields are empty or default', () {
      // Arrange & Act
      final result = DeliveryUpdateHelper.isDirty(
        recipient: '',
        note: '',
        relationship: null,
        relationshipSpecify: '',
        reason: null,
        reasonSpecify: '',
        accordingTo: '',
        hasPodPhoto: false,
        hasSelfiePhoto: false,
        hasMailpackPhoto: false,
        hasAdditionalPhotos: false,
        hasSignature: false,
        confirmationCode: '',
        placement: 'RECEIVED',
      );

      // Assert
      expect(result, false);
    });

    test('returns true when recipient name is filled', () {
      // Arrange & Act
      final result = DeliveryUpdateHelper.isDirty(
        recipient: 'John Doe',
        note: '',
        relationship: null,
        relationshipSpecify: '',
        reason: null,
        reasonSpecify: '',
        accordingTo: '',
        hasPodPhoto: false,
        hasSelfiePhoto: false,
        hasMailpackPhoto: false,
        hasAdditionalPhotos: false,
        hasSignature: false,
        confirmationCode: '',
        placement: 'RECEIVED',
      );

      // Assert
      expect(result, true);
    });

    test('returns true when note is filled', () {
      // Arrange & Act
      final result = DeliveryUpdateHelper.isDirty(
        recipient: '',
        note: 'Some note',
        relationship: null,
        relationshipSpecify: '',
        reason: null,
        reasonSpecify: '',
        accordingTo: '',
        hasPodPhoto: false,
        hasSelfiePhoto: false,
        hasMailpackPhoto: false,
        hasAdditionalPhotos: false,
        hasSignature: false,
        confirmationCode: '',
        placement: 'RECEIVED',
      );

      // Assert
      expect(result, true);
    });

    test('returns true when relationship is selected', () {
      // Arrange & Act
      final result = DeliveryUpdateHelper.isDirty(
        recipient: '',
        note: '',
        relationship: 'OWNER',
        relationshipSpecify: '',
        reason: null,
        reasonSpecify: '',
        accordingTo: '',
        hasPodPhoto: false,
        hasSelfiePhoto: false,
        hasMailpackPhoto: false,
        hasAdditionalPhotos: false,
        hasSignature: false,
        confirmationCode: '',
        placement: 'RECEIVED',
      );

      // Assert
      expect(result, true);
    });

    test('returns true when reason is selected', () {
      // Arrange & Act
      final result = DeliveryUpdateHelper.isDirty(
        recipient: '',
        note: '',
        relationship: null,
        relationshipSpecify: '',
        reason: 'HOUSE_CLOSED',
        reasonSpecify: '',
        accordingTo: '',
        hasPodPhoto: false,
        hasSelfiePhoto: false,
        hasMailpackPhoto: false,
        hasAdditionalPhotos: false,
        hasSignature: false,
        confirmationCode: '',
        placement: 'RECEIVED',
      );

      // Assert
      expect(result, true);
    });

    test('returns true when POD photo is taken', () {
      // Arrange & Act
      final result = DeliveryUpdateHelper.isDirty(
        recipient: '',
        note: '',
        relationship: null,
        relationshipSpecify: '',
        reason: null,
        reasonSpecify: '',
        accordingTo: '',
        hasPodPhoto: true,
        hasSelfiePhoto: false,
        hasMailpackPhoto: false,
        hasAdditionalPhotos: false,
        hasSignature: false,
        confirmationCode: '',
        placement: 'RECEIVED',
      );

      // Assert
      expect(result, true);
    });

    test('returns true when placement is changed from default', () {
      // Arrange & Act
      final result = DeliveryUpdateHelper.isDirty(
        recipient: '',
        note: '',
        relationship: null,
        relationshipSpecify: '',
        reason: null,
        reasonSpecify: '',
        accordingTo: '',
        hasPodPhoto: false,
        hasSelfiePhoto: false,
        hasMailpackPhoto: false,
        hasAdditionalPhotos: false,
        hasSignature: false,
        confirmationCode: '',
        placement: 'GUARD',
      );

      // Assert
      expect(result, true);
    });

    test(
      'returns false when placement is explicitly null (if possible in UI)',
      () {
        // Arrange & Act
        final result = DeliveryUpdateHelper.isDirty(
          recipient: '',
          note: '',
          relationship: null,
          relationshipSpecify: '',
          reason: null,
          reasonSpecify: '',
          accordingTo: '',
          hasPodPhoto: false,
          hasSelfiePhoto: false,
          hasMailpackPhoto: false,
          hasAdditionalPhotos: false,
          hasSignature: false,
          confirmationCode: '',
          placement: null,
        );

        // Assert
        expect(result, false);
      },
    );
  });
}
