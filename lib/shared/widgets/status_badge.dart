// DOCS: docs/shared/widgets.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/core/models/delivery_status.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final ds = DeliveryStatus.fromString(status);
    final color = switch (ds) {
      DeliveryStatus.pending => DSColors.warning,
      DeliveryStatus.delivered => DSColors.success,
      DeliveryStatus.failedDelivery => DSColors.error,
      DeliveryStatus.osa => DSColors.warning,
      _ =>
        Theme.of(context).brightness == Brightness.dark
            ? DSColors.labelSecondaryDark
            : DSColors.labelSecondary,
    };

    final displayStatus = ds != DeliveryStatus.unknown
        ? ds.displayName.toUpperCase()
        : status.replaceAll('_', ' ').toUpperCase();

    return Chip(
      label: Text(displayStatus),
      backgroundColor: color.withValues(alpha: DSStyles.alphaSoft),
      labelStyle: DSTypography.label(
        color: color,
      ).copyWith(fontWeight: FontWeight.w600),
      side: BorderSide(
        color: color.withValues(alpha: DSStyles.alphaMuted),
      ),
    );
  }
}
