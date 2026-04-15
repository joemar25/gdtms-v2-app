// DOCS: docs/shared/widgets.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/core/models/delivery_status.dart';
import 'package:fsi_courier_app/styles/ui_styles.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final ds = DeliveryStatus.fromString(status);
    final color = switch (ds) {
      DeliveryStatus.pending => Colors.orange,
      DeliveryStatus.delivered => Colors.green,
      DeliveryStatus.failedDelivery => Colors.red,
      DeliveryStatus.osa => Colors.amber,
      _ => Colors.grey,
    };

    final displayStatus = ds != DeliveryStatus.unknown
        ? ds.displayName.toUpperCase()
        : status.replaceAll('_', ' ').toUpperCase();

    return Chip(
      label: Text(displayStatus),
      backgroundColor: color.withValues(alpha: UIStyles.alphaActiveAccent),
      labelStyle: TextStyle(color: color.shade700, fontWeight: FontWeight.w600),
      side: BorderSide(
        color: color.withValues(alpha: UIStyles.alphaDarkShadow),
      ),
    );
  }
}
