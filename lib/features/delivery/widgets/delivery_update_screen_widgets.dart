// DOCS: docs/development-standards.md
// DOCS: docs/features/delivery.md — update that file when you edit this one.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_form_helpers.dart';

/// App bar title column (heading + barcode subtitle) for [DeliveryUpdateScreen].
class DeliveryUpdateAppBarTitle extends StatelessWidget {
  const DeliveryUpdateAppBarTitle({super.key, required this.barcode});

  final String barcode;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'delivery_update.header.update_status'.tr(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DSTypography.heading().copyWith(
            fontSize: DSTypography.sizeMd,
            fontWeight: FontWeight.w800,
            letterSpacing: DSTypography.lsExtraLoose,
            color: isDark ? DSColors.labelPrimaryDark : DSColors.labelPrimary,
          ),
        ),
        Text(
          barcode,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DSTypography.caption().copyWith(
            fontSize: DSTypography.sizeSm,
            color: isDark
                ? DSColors.labelSecondaryDark
                : DSColors.labelSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Read-only transaction date field pre-filled with PST timestamp.
class DeliveryTransactionDateField extends StatelessWidget {
  const DeliveryTransactionDateField({super.key});

  static DateTime _pstNow() =>
      DateTime.now().toUtc().add(const Duration(hours: 8));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateStr = DateFormat(
      'delivery_update.datetime.format'.tr(),
    ).format(_pstNow());

    return TextFormField(
      initialValue: dateStr,
      enabled: false,
      style: DSTypography.body().copyWith(
        fontWeight: FontWeight.w600,
        fontSize: DSTypography.sizeMd,
        color: isDark ? DSColors.labelPrimaryDark : DSColors.labelPrimary,
      ),
      decoration: deliveryFieldDecoration(context).copyWith(
        prefixIcon: const Icon(
          Icons.calendar_today_rounded,
          size: DSIconSize.md,
          color: DSColors.labelTertiary,
        ),
        suffixIcon: const Icon(
          Icons.lock_outline_rounded,
          size: DSIconSize.sm,
          color: DSColors.labelTertiary,
        ),
      ),
    );
  }
}
