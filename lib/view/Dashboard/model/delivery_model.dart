class Delivery {
  final int id;
  final String dispatchCode;
  final String partialCode;
  final String mailType;
  final String tat;
  final String transmittalDate;
  final String status;
  final List<dynamic> history;
  final String name;
  final String address;
  final String contact;
  final String? authorizedRep1;
  final String? contactRep1;
  final String? authorizedRep2;
  final String? contactRep2;
  final String? authorizedRep3;
  final String? contactRep3;
  final String? specialInstruction;
  final String sequenceNumber;
  final String barcodeValue;
  final String product;
  final String remarks;
  final List<String> media; // ✅ added

  Delivery({
    required this.id,
    required this.dispatchCode,
    required this.partialCode,
    required this.mailType,
    required this.tat,
    required this.transmittalDate,
    required this.status,
    required this.history,
    required this.name,
    required this.address,
    required this.contact,
    this.authorizedRep1,
    this.contactRep1,
    this.authorizedRep2,
    this.contactRep2,
    this.authorizedRep3,
    this.contactRep3,
    this.specialInstruction,
    required this.sequenceNumber,
    required this.barcodeValue,
    required this.product,
    required this.remarks,
    this.media = const [],
  });

  factory Delivery.fromJson(Map<String, dynamic> json) {
    return Delivery(
      id: json['id'] ?? 0,
      dispatchCode: json['dispatch_code'] ?? '',
      partialCode: json['partial_code'] ?? '',
      mailType: json['mail_type'] ?? '',
      tat: json['tat'] ?? '',
      transmittalDate: json['transmittal_date'] ?? '',
      status: json['delivery_status'] ?? '',
      history: json['delivery_trans_history'] ?? [],
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      contact: json['contact'] ?? '',
      authorizedRep1: json['authorized_rep_1'],
      contactRep1: json['contact_rep_1'],
      authorizedRep2: json['authorized_rep_2'],
      contactRep2: json['contact_rep_2'],
      authorizedRep3: json['authorized_rep_3'],
      contactRep3: json['contact_rep_3'],
      specialInstruction: json['special_instruction'],
      sequenceNumber: json['sequence_number'] ?? '',
      barcodeValue: json['barcode_value'] ?? '',
      product: json['product'] ?? '',
      remarks: json['remarks'] ?? '',
      media:
          (json['media'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  // ✅ Add this method to convert Delivery to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dispatch_code': dispatchCode,
      'partial_code': partialCode,
      'mail_type': mailType,
      'tat': tat,
      'transmittal_date': transmittalDate,
      'delivery_status': status,
      'delivery_trans_history': history,
      'name': name,
      'address': address,
      'contact': contact,
      'authorized_rep_1': authorizedRep1,
      'contact_rep_1': contactRep1,
      'authorized_rep_2': authorizedRep2,
      'contact_rep_2': contactRep2,
      'authorized_rep_3': authorizedRep3,
      'contact_rep_3': contactRep3,
      'special_instruction': specialInstruction,
      'sequence_number': sequenceNumber,
      'barcode_value': barcodeValue,
      'product': product,
      'remarks': remarks,
      'media': media,
    };
  }
}
