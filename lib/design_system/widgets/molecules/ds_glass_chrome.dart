// DOCS: docs/development-standards.md
// DOCS: docs/styles.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_glass.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_styles.dart';

/// Frosted **primary** chrome panel — header flexibleSpace / bottom nav shell.
///
/// Uses [BackdropFilter] + translucent primary fill. Parent [Material] / theme
/// must be transparent or blur is blocked (see [DSTheme] appBar / bottomNav).
///
/// Light mode adds a soft white top sheen so dense primary still reads as glass.
class DSGlassChrome extends StatelessWidget {
  const DSGlassChrome({
    super.key,
    this.child,
    this.borderRadius,
    this.showBottomBorder = false,
    this.showBorder = true,
    this.boxShadow = true,
  });

  final Widget? child;
  final BorderRadius? borderRadius;
  final bool showBottomBorder;
  final bool showBorder;
  final bool boxShadow;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.zero;
    final fill = DSGlass.fill(context, tone: DSGlassTone.chrome);
    final edge = DSGlass.border(context, tone: DSGlassTone.chrome);

    final Border? border = showBorder
        ? Border.all(color: edge, width: DSStyles.borderWidth)
        : (showBottomBorder
              ? Border(
                  bottom: BorderSide(color: edge, width: DSStyles.borderWidth),
                )
              : null);

    final frosted = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: DSGlass.filterFor(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Primary tint (mode-aware density via [DSGlass.fill]).
            ColoredBox(color: fill),
            // Light-only sheen — keeps dense green from looking like solid paint.
            if (!isDark)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x26FFFFFF), // white @ ~0.15
                      Color(0x00FFFFFF),
                    ],
                  ),
                ),
              ),
            // Edge + optional child content.
            DecoratedBox(
              decoration: BoxDecoration(borderRadius: radius, border: border),
              child: child ?? const SizedBox.expand(),
            ),
          ],
        ),
      ),
    );

    if (!boxShadow) return frosted;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: DSGlass.shadow(context, tone: DSGlassTone.chrome),
      ),
      child: frosted,
    );
  }
}
