// DOCS: docs/development-standards.md
// DOCS: docs/features/delivery.md — update that file when you edit this one.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/features/delivery/delivery_update_components.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_form_helpers.dart';

/// Top-level status selection section for [DeliveryUpdateScreen].
///
/// Wraps the [DeliveryStatusSelector] with a section header and error display.
class DeliveryStatusSection extends StatelessWidget {
  const DeliveryStatusSection({
    super.key,
    required this.statusSelectorKey,
    required this.currentStatus,
    required this.onStatusChanged,
    this.error,
  });

  final GlobalKey<DeliveryStatusSelectorState> statusSelectorKey;
  final String currentStatus;
  final Future<void> Function(String) onStatusChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DeliverySectionHeader(
          label: 'delivery_update.header.select_status'.tr(),
        ),
        DSSpacing.hSm, // _kInnerGap equivalent
        DeliveryStatusSelector(
          key: statusSelectorKey,
          currentStatus: currentStatus,
          onStatusChanged: onStatusChanged,
        ),
        if (error != null)
          Padding(
            padding: EdgeInsets.only(top: DSSpacing.sm),
            child: Text(
              error!,
              style: DSTypography.body(
                color: DSColors.error,
              ).copyWith(fontSize: DSTypography.sizeSm),
            ),
          ),
      ],
    );
  }
}
