import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/shared/widgets/delivery_card_components.dart';

/// A reusable widget that displays the "Other Information" section of a delivery.
/// Shows: Product (if any), Special Instruction (if any), Transmittal Date, and TAT.
class DeliveryOtherInfoSection extends StatelessWidget {
  const DeliveryOtherInfoSection({
    super.key,
    required this.product,
    this.specialInstruction,
    this.transmittalDate,
    this.tat,
    this.isDark = false,
    this.subtextColor,
    this.showTitle = true,
    this.isExpandedCard = false,
  });

  final String product;
  final String? specialInstruction;
  final String? transmittalDate;
  final String? tat;
  final bool isDark;
  final Color? subtextColor;
  final bool showTitle;
  final bool isExpandedCard;

  @override
  Widget build(BuildContext context) {
    final effectiveSubtextColor =
        subtextColor ??
        (isDark ? DSColors.labelSecondaryDark : DSColors.labelSecondary);

    final List<({String label, String value, bool isItalic})> items = [
      if (product.isNotEmpty)
        (
          label: 'delivery_card.details.product'.tr(),
          value: product,
          isItalic: false,
        ),
      if (specialInstruction != null && specialInstruction!.isNotEmpty)
        (
          label: 'delivery_card.details.special_instructions'.tr(),
          value: specialInstruction!,
          isItalic: true,
        ),
      if (transmittalDate != null && transmittalDate!.isNotEmpty)
        (
          label: 'delivery_card.details.transmittal_date'.tr(),
          value: transmittalDate!,
          isItalic: false,
        ),
      if (tat != null && tat!.isNotEmpty)
        (label: 'delivery_card.details.tat'.tr(), value: tat!, isItalic: false),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    if (!showTitle) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: i < items.length - 1 ? DSSpacing.md : 0,
            ),
            child: DeliveryDetailCell(
              label: item.label,
              value: item.value,
              isDark: isDark,
              subtextColor: effectiveSubtextColor,
              isItalic: item.isItalic,
            ),
          );
        }).toList(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DSSpacing.hMd,
        DSSectionHeader(
          title: 'delivery_card.details.other_information'.tr(),
          padding: EdgeInsets.zero,
        ),
        DSCard(
          margin: EdgeInsets.only(top: DSSpacing.sm),
          padding: EdgeInsets.symmetric(vertical: DSSpacing.xs),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              return DSInfoTile(
                label: item.label,
                value: item.value,
                showDivider: i < items.length - 1,
                padding: EdgeInsets.symmetric(
                  horizontal: DSSpacing.md,
                  vertical: DSSpacing.sm + 2,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
