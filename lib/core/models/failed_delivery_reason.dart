/// Model representing a reason for a failed delivery attempt.
///
/// These are typically returned in `GET /api/mbl/app-config` or
/// as a standalone list in v3.6.
class FailedDeliveryReason {
  final int id;
  final String label;

  FailedDeliveryReason({required this.id, required this.label});

  factory FailedDeliveryReason.fromJson(Map<String, dynamic> json) {
    return FailedDeliveryReason(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      label: json['label'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'label': label};
}
