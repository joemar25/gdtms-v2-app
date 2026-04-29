/// Pure logic helper for [DeliveryUpdateScreen].
/// Extracted to allow unit testing of dirty-state and validation logic.
class DeliveryUpdateHelper {
  /// Checks if the delivery update form is "dirty" (has unsaved changes).
  ///
  /// We no longer consider the status selection itself as "dirty" to allow
  /// couriers to toggle between statuses without being warned on exit.
  static bool isDirty({
    required String recipient,
    required String note,
    required String? relationship,
    required String relationshipSpecify,
    required String? reason,
    required String reasonSpecify,
    required String accordingTo,
    required bool hasPodPhoto,
    required bool hasSelfiePhoto,
    required bool hasMailpackPhoto,
    required bool hasAdditionalPhotos,
    required bool hasSignature,
    required String confirmationCode,
    required String? placement,
  }) {
    return recipient.isNotEmpty ||
        note.isNotEmpty ||
        relationship != null ||
        relationshipSpecify.isNotEmpty ||
        reason != null ||
        reasonSpecify.isNotEmpty ||
        accordingTo.isNotEmpty ||
        hasPodPhoto ||
        hasSelfiePhoto ||
        hasMailpackPhoto ||
        hasAdditionalPhotos ||
        hasSignature ||
        confirmationCode.isNotEmpty ||
        (placement != null && placement != 'RECEIVED');
  }
}
