import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final color = switch (normalized) {
      'pending' => Colors.orange,
      'delivered' => Colors.green,
      'failed_attempt' => Colors.deepOrange,
      'rts' => Colors.red,
      'osa' => Colors.amber,
      'dispatched' => Colors.blue,
      _ => Colors.grey,
    };

    return Chip(
      label: Text(normalized),
      backgroundColor: color.withValues(alpha: 0.15),
      labelStyle: TextStyle(color: color.shade700, fontWeight: FontWeight.w600),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
    );
  }
}
