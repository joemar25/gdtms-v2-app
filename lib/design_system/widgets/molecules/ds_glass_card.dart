// DOCS: docs/development-standards.md
// DOCS: docs/design-system.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_glass.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_spacing.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_styles.dart';

/// Frosted elevated surface used on gate screens (auth, permissions, update)
/// and floating chrome (debug chip, splash feature chips).
///
/// Prefer this over ad-hoc white boxes so login / reset / permissions / dev
/// chrome share one look via [DSGlass].
class DSGlassCard extends StatelessWidget {
  const DSGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderColor,
    this.width = double.infinity,
    this.height,
    this.borderRadius,
    this.compact = false,
    this.alignment,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;

  /// Defaults to full width (form cards). Pass a fixed size for chips.
  final double? width;
  final double? height;

  /// Defaults: [DSStyles.radius2XL] (cards) or pill when [compact].
  final BorderRadius? borderRadius;

  /// Tighter padding + lighter shadow for small floating chips.
  final bool compact;

  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    final radius =
        borderRadius ??
        (compact
            ? DSStyles.fullRadius
            : BorderRadius.circular(DSStyles.radius2XL));
    final resolvedPadding =
        padding ??
        (compact ? EdgeInsets.zero : const EdgeInsets.all(DSSpacing.lg));

    return Container(
      width: width,
      height: height,
      alignment: alignment,
      padding: resolvedPadding,
      decoration: BoxDecoration(
        color: DSGlass.fill(
          context,
          tone: compact ? DSGlassTone.chrome : DSGlassTone.card,
        ),
        borderRadius: radius,
        border: Border.all(
          color: borderColor ?? DSGlass.border(context),
          width: DSStyles.borderWidth,
        ),
        boxShadow: compact
            ? DSGlass.shadowCompact(context)
            : DSGlass.shadow(context, tone: DSGlassTone.card),
      ),
      child: child,
    );
  }
}
