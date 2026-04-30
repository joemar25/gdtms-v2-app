// DOCS: docs/development-standards.md
import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

class DSInfoTile extends StatelessWidget {
  const DSInfoTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.onTap,
    this.onLongPress,
    this.accentColor,
    this.showDivider = true,
    this.padding,
  });

  final String label;
  final String value;
  final IconData? icon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? accentColor;
  final bool showDivider;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Standardize on labelPrimary for all values to maintain consistency.
    // Interactivity is indicated by the trailing icon/button.
    final valueColor = isDark
        ? DSColors.labelPrimaryDark
        : DSColors.labelPrimary;
    final resolvedAccentColor =
        accentColor ?? (isDark ? DSColors.primaryDark : DSColors.primary);

    return Column(
      children: [
        Material(
          color: DSColors.transparent,
          child: InkWell(
            onTap: onTap ?? onLongPress,
            onLongPress: onLongPress,
            child: Padding(
              padding:
                  padding ??
                  EdgeInsets.symmetric(
                    vertical: DSSpacing.md,
                    horizontal: DSSpacing.md,
                  ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (label.isNotEmpty) ...[
                          Text(
                            label.toUpperCase(),
                            style: DSTypography.label(
                              color: isDark
                                  ? DSColors.labelTertiaryDark
                                  : DSColors.labelTertiary,
                            ),
                          ),
                          DSSpacing.hXs,
                        ],
                        Text(
                          value,
                          style: DSTypography.body(color: valueColor).copyWith(
                            fontSize: DSIconSize.sm,
                            fontWeight: FontWeight.w600,
                            height: DSStyles.heightNormal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onTap != null || icon != null) ...[
                    DSSpacing.wMd,
                    Container(
                      width: DSIconSize.heroSm,
                      height: DSIconSize.heroSm,
                      decoration: BoxDecoration(
                        color: resolvedAccentColor.withValues(
                          alpha: isDark ? 0.15 : DSStyles.alphaSubtle,
                        ),
                        borderRadius: DSStyles.pillRadius,
                      ),
                      child: Icon(
                        icon ??
                            (label.toLowerCase().contains('address')
                                ? Icons.map_rounded
                                : Icons.phone_rounded),
                        size: DSIconSize.md,
                        color: resolvedAccentColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: EdgeInsets.only(left: DSSpacing.md),
            child: Divider(
              height: DSStyles.borderWidth,
              thickness: 1,
              color: isDark ? DSColors.separatorDark : DSColors.separatorLight,
            ),
          ),
      ],
    );
  }
}
