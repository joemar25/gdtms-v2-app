// DOCS: docs/development-standards.md
import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

/// A premium, gradient-styled card used for "Hero" sections (e.g., Profile header, Dispatch info).
///
/// It handles the complex gradient, border, and shadow logic consistently
/// across light and dark modes.
class DSHeroCard extends StatelessWidget {
  const DSHeroCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.accentColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  /// Optional base color for the gradient. Defaults to [DSColors.primary].
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = accentColor ?? DSColors.primary;
    final pressedColor = accentColor != null
        ? accentColor!.withValues(alpha: 0.8) // Simple approximation
        : DSColors.primaryPressed;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [DSColors.cardElevatedDark, DSColors.cardDark]
              : [baseColor, pressedColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: DSStyles.cardRadius,
        border: Border.all(
          color: isDark
              ? DSColors.separatorDark
              : DSColors.white.withValues(alpha: 0.2),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? DSColors.black : baseColor).withValues(
              alpha: isDark ? DSStyles.alphaMuted : DSStyles.alphaSubtle,
            ),
            blurRadius: DSSpacing.lg,
            offset: const Offset(0, DSSpacing.md),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: DSStyles.cardRadius,
        child: Padding(
          padding: padding ?? EdgeInsets.all(DSSpacing.md),
          child: child,
        ),
      ),
    );
  }
}
