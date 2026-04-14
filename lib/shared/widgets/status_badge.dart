// DOCS: docs/shared/widgets.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/styles/ui_styles.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toUpperCase();
    final color = switch (normalized) {
      'PENDING' => Colors.orange,
      'DELIVERED' => Colors.green,
      'FAILED_ATTEMPT' => Colors.deepOrange,
      'RTS' => Colors.red,
      'OSA' => Colors.amber,
      'DISPATCHED' => Colors.blue,
      _ => Colors.grey,
    };

    final displayStatus = status.replaceAll('_', ' ').toUpperCase();

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
