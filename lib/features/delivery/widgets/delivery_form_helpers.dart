// DOCS: docs/features/delivery.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

// ─── Theme-aware field decoration ───────────────────────────────────────────
InputDecoration deliveryFieldDecoration(
  BuildContext context, {
  String? labelText,
  String? hintText,
  String? errorText,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final fill = isDark
      ? DSColors.secondarySurfaceDark
      : DSColors.secondarySurfaceLight;
  final borderColor = isDark ? DSColors.separatorDark : DSColors.separatorLight;

  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    errorText: errorText,
    filled: true,
    fillColor: fill,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: DSSpacing.base,
      vertical: DSSpacing.base,
    ),
    labelStyle: DSTypography.body().copyWith(
      color: isDark ? DSColors.labelSecondaryDark : DSColors.labelSecondary,
      fontSize: DSTypography.sizeMd,
      fontWeight: FontWeight.w500,
    ),
    hintStyle: DSTypography.body().copyWith(
      color: isDark ? DSColors.labelTertiaryDark : DSColors.labelTertiary,
      fontSize: DSTypography.sizeMd,
    ),
    errorStyle: DSTypography.caption().copyWith(
      color: DSColors.error,
      fontSize: DSTypography.sizeSm,
      fontWeight: FontWeight.w500,
    ),
    border: OutlineInputBorder(
      borderRadius: DSStyles.cardRadius,
      borderSide: BorderSide(color: borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: DSStyles.cardRadius,
      borderSide: BorderSide(color: borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: DSStyles.cardRadius,
      borderSide: const BorderSide(color: DSColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: DSStyles.cardRadius,
      borderSide: const BorderSide(color: DSColors.error, width: 1.0),
    ),
  );
}

// ─── Section header ──────────────────────────────────────────────────────────
class DeliverySectionHeader extends StatelessWidget {
  const DeliverySectionHeader({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: DSColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: DSTypography.label().copyWith(
              fontSize: DSTypography.sizeSm,
              fontWeight: FontWeight.w900,
              letterSpacing: DSTypography.lsGiantLoose,
              color: isDark
                  ? DSColors.labelTertiaryDark
                  : DSColors.labelSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Photo source button ──────────────────────────────────────────────────────
class DeliveryPhotoSourceButton extends StatelessWidget {
  const DeliveryPhotoSourceButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: DSSpacing.md,
        ),
        decoration: BoxDecoration(
          color: enabled
              ? color.withValues(alpha: 0.1)
              : (isDark
                    ? DSColors.white.withValues(alpha: 0.05)
                    : DSColors.secondarySurfaceLight),
          borderRadius: DSStyles.cardRadius,
          border: Border.all(
            color: enabled
                ? color.withValues(alpha: 0.2)
                : (isDark ? DSColors.separatorDark : DSColors.separatorLight),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: enabled
                  ? color
                  : (isDark ? DSColors.white : DSColors.labelTertiary),
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: DSTypography.label().copyWith(
                fontSize: DSTypography.sizeSm,
                fontWeight: FontWeight.w800,
                color: enabled
                    ? color
                    : (isDark
                          ? DSColors.labelTertiaryDark
                          : DSColors.labelTertiary),
                letterSpacing: DSTypography.lsExtraLoose,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
