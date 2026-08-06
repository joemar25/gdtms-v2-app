// DOCS: docs/development-standards.md
// DOCS: docs/design-system.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

/// Elevated bottom action dock for post-login screens.
///
/// Use with [DsAppScaffold.bottomNavigationBar] for Confirm / primary CTAs.
/// Provides a solid surface so transparent scaffolds never show a black void
/// under the bar (and disabled buttons stay readable).
///
/// Example:
/// ```dart
/// DsAppScaffold(
///   bottomNavigationBar: DsBottomActionBar(
///     child: FilledButton(...),
///   ),
///   body: ...,
/// )
/// ```
class DsBottomActionBar extends StatelessWidget {
  const DsBottomActionBar({
    super.key,
    required this.child,
    this.padding,
    this.elevation = 12,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? DSColors.cardElevatedDark : DSColors.cardLight,
      elevation: elevation,
      shadowColor: DSColors.black.withValues(alpha: isDark ? 0.4 : 0.12),
      child: SafeArea(
        top: false,
        child: Padding(
          padding:
              padding ??
              const EdgeInsets.fromLTRB(
                DSSpacing.md,
                DSSpacing.sm,
                DSSpacing.md,
                DSSpacing.md,
              ),
          child: child,
        ),
      ),
    );
  }
}
