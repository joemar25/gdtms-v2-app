import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_colors.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_spacing.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_typography.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_styles.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_icon_sizes.dart';

/// A premium information or action tile with a prominent icon on the left.
///
/// This component supports two main layouts:
/// 1. **Detail Style** (default): Small label on top of a prominent value.
/// 2. **Action Style**: Prominent title on top of a small description/subtitle.
///
/// Example (Detail Style):
/// ```dart
/// DSDetailTile(
///   icon: Icons.store_outlined,
///   title: 'Manila Hub',
///   subtitle: 'BRANCH',
///   isSubtitleTop: true,
/// )
/// ```
///
/// Example (Action Style):
/// ```dart
/// DSDetailTile(
///   icon: Icons.lock_reset_rounded,
///   title: 'Change Password',
///   subtitle: 'Update your account security',
///   onTap: () => ...,
/// )
/// ```
class DSDetailTile extends StatelessWidget {
  const DSDetailTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.isSubtitleTop = false,
    this.iconColor,
    this.trailing,
    this.onTap,
    this.padding,
    this.titleColor,
    this.isDestructive = false,
  });

  /// The icon to display on the left.
  final IconData icon;

  /// The color of the icon and its subtle background container.
  /// If null, defaults to DSColors.primary (themed).
  final Color? iconColor;

  /// The primary text (prominent).
  final String title;

  /// The secondary text (smaller).
  final String? subtitle;

  /// Whether the subtitle should be displayed above the title.
  /// Set to true for "Detail" style (e.g. LABEL on top of VALUE).
  final bool isSubtitleTop;

  /// Optional widget to display on the far right.
  final Widget? trailing;

  /// Optional callback when the tile is tapped.
  final VoidCallback? onTap;

  /// Custom padding for the tile.
  final EdgeInsetsGeometry? padding;

  /// Optional custom color for the title text.
  final Color? titleColor;

  /// Whether the title should use the error color (for logout/delete actions).
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Standardize colors using semantic tokens
    final resolvedIconColor =
        iconColor ?? (isDark ? DSColors.primaryDark : DSColors.primary);
    final resolvedTitleColor = isDestructive
        ? DSColors.error
        : (titleColor ??
              (isDark ? DSColors.labelPrimaryDark : DSColors.labelPrimary));
    final resolvedSubtitleColor = isDark
        ? DSColors.labelSecondaryDark
        : DSColors.labelSecondary;

    final defaultPadding = EdgeInsets.symmetric(
      horizontal: DSSpacing.md,
      vertical: DSSpacing.sm + 2,
    );

    // Build subtitle with proper typography tokens
    final subtitleWidget = subtitle != null
        ? Text(
            isSubtitleTop ? subtitle!.toUpperCase() : subtitle!,
            style: isSubtitleTop
                ? DSTypography.label(color: resolvedSubtitleColor)
                : DSTypography.caption(color: resolvedSubtitleColor),
          )
        : null;

    final titleWidget = Text(
      title,
      style: DSTypography.title(
        color: resolvedTitleColor,
        fontSize: DSTypography.sizeMd,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    final content = Padding(
      padding: padding ?? defaultPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Premium Icon Container
          Container(
            width: DSIconSize.heroSm,
            height: DSIconSize.heroSm,
            decoration: BoxDecoration(
              color: resolvedIconColor.withValues(
                alpha: isDark ? 0.15 : DSStyles.alphaSubtle,
              ),
              borderRadius: DSStyles.pillRadius,
              // Subtle border for better definition in light mode
              border: isDark
                  ? null
                  : Border.all(
                      color: resolvedIconColor.withValues(alpha: 0.1),
                      width: 0.5,
                    ),
            ),
            child: Icon(icon, size: DSIconSize.md, color: resolvedIconColor),
          ),
          DSSpacing.wMd,

          // Main Content Area
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSubtitleTop && subtitleWidget != null) ...[
                  subtitleWidget,
                  const SizedBox(height: 3),
                ],
                titleWidget,
                if (!isSubtitleTop && subtitleWidget != null) ...[
                  const SizedBox(height: 2),
                  subtitleWidget,
                ],
              ],
            ),
          ),

          // Trailing Widget or Navigation Indicator
          if (trailing != null) ...[
            DSSpacing.wMd,
            trailing!,
          ] else if (onTap != null) ...[
            DSSpacing.wMd,
            Icon(
              Icons.chevron_right_rounded,
              size: DSIconSize.md,
              color: isDark
                  ? DSColors.labelTertiaryDark
                  : DSColors.labelTertiary,
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DSSpacing.sm),
        splashColor: resolvedIconColor.withValues(alpha: 0.05),
        highlightColor: resolvedIconColor.withValues(alpha: 0.02),
        child: content,
      );
    }

    return content;
  }
}
