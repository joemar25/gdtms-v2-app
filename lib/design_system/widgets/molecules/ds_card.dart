// DOCS: docs/development-standards.md
import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

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
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final bool showBorder;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBorderRadius = borderRadius ?? DSStyles.cardRadius;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color:
            backgroundColor ??
            (isDark ? DSColors.cardDark : DSColors.cardLight),
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
      child: ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
  }
}
