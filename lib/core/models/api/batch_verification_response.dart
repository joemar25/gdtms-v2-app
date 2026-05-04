import 'package:fsi_courier_app/core/models/delivery_status.dart';

/// Response model for the batch verification endpoint.
///
/// Endpoint: `POST /api/mbl/deliveries/verify-status`
class BatchVerificationResponse {
  final bool success;
  final List<VerificationItem> data;

  BatchVerificationResponse({required this.success, required this.data});

  factory BatchVerificationResponse.fromJson(Map<String, dynamic> json) {
    return BatchVerificationResponse(
      success: json['success'] ?? false,
      data: (json['data'] as List? ?? [])
          .map((item) => VerificationItem.fromJson(item))
          .toList(),
    );
  }
}

class VerificationItem {
  final String barcode;
  final String status;
  final DateTime? updatedAt;

  VerificationItem({
    required this.barcode,
    required this.status,
    this.updatedAt,
  });

  factory VerificationItem.fromJson(Map<String, dynamic> json) {
    return VerificationItem(
      barcode: json['barcode'] ?? '',
      status: json['status'] ?? '',
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
    );
  }

  /// Convenience getter to resolve the status to the local enum.
  DeliveryStatus get statusEnum => DeliveryStatus.fromString(status);
}
