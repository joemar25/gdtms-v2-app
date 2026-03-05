import 'package:flutter/material.dart';

import '../helpers/delivery_identifier.dart';
import 'status_badge.dart';

class DeliveryCard extends StatelessWidget {
  const DeliveryCard({
    super.key,
    required this.delivery,
    required this.onTap,
  });

  final Map<String, dynamic> delivery;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final barcode = resolveDeliveryIdentifier(delivery);
    final status = delivery['delivery_status']?.toString() ?? 'pending';
    final address = delivery['address']?.toString() ?? '';
    final recipient = delivery['recipient']?.toString() ?? '';

    return Card(
      child: ListTile(
        title: Text(barcode.isEmpty ? 'Unknown' : barcode),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusBadge(status: status),
            if (recipient.isNotEmpty) Text('Recipient: $recipient'),
            if (address.isNotEmpty) Text(address),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
