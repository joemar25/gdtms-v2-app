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

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap ?? onLongPress,
            onLongPress: onLongPress,
            child: Padding(
              padding:
                  padding ??
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label.toUpperCase(),
                          style: DSTypography.label(
                            color: isDark
                                ? DSColors.labelTertiaryDark
                                : DSColors.labelTertiary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          value,
                          style: DSTypography.body(color: valueColor).copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onTap != null || icon != null) ...[
                    const SizedBox(width: 12),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: DSColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon ??
                            (label.toLowerCase().contains('address')
                                ? Icons.map_rounded
                                : Icons.phone_rounded),
                        size: 14,
                        color: DSColors.primary,
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
            padding: const EdgeInsets.only(left: 16),
            child: Divider(
              height: 1,
              thickness: 1,
              color: isDark ? DSColors.separatorDark : DSColors.separatorLight,
            ),
          ),
      ],
    );
  }
}
