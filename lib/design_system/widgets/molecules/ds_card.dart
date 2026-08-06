// DOCS: docs/development-standards.md
// DOCS: docs/design-system.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

/// Elevated content card for post-login lists and settings groups.
///
/// Solid surfaces only (not glass). Optional [accentBar] matches the dashboard
/// metric-tile left rail for brand/status emphasis.
class DSCard extends StatelessWidget {
  const DSCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.backgroundColor,
    this.showBorder = true,
    this.showShadow = true,
    this.accentBar,
    this.accentBarWidth = 3,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final bool showBorder;
  final bool showShadow;

  /// Optional left accent strip (brand primary/gold or semantic status).
  final Color? accentBar;
  final double accentBarWidth;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBorderRadius = borderRadius ?? DSStyles.cardRadius;
    final surface =
        backgroundColor ??
        (isDark ? DSColors.cardElevatedDark : DSColors.cardLight);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: effectiveBorderRadius,
        border: showBorder
            ? Border.all(
                color: isDark
                    ? DSColors.separatorDark
                    : DSColors.separatorLight,
                width: DSStyles.borderWidth,
              )
            : null,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: DSColors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                  blurRadius: DSStyles.radiusLG,
                  offset: const Offset(0, DSSpacing.xs),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: Stack(
          children: [
            if (accentBar != null)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: accentBarWidth, color: accentBar),
              ),
            Padding(
              padding: padding ?? EdgeInsets.zero,
              child: accentBar != null
                  ? Padding(
                      // Keep body clear of the rail.
                      padding: EdgeInsets.only(left: accentBarWidth),
                      child: child,
                    )
                  : child,
            ),
          ],
        ),
      ),
    );
  }
}
