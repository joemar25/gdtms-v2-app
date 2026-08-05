// DOCS: docs/development-standards.md
// DOCS: docs/design-system.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_colors.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_spacing.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_typography.dart';

/// Right-aligned text action inside a form stack (e.g. Forgot password).
///
/// Spacing uses [DSSpacing.formFieldToAction] / [DSSpacing.formActionToCta]
/// (sm = 8) so the link sits close to the field but still readable.
///
/// ```dart
/// TextField(...),
/// DSFormActionLink(
///   label: 'Forgot Password?',
///   onPressed: () => context.push('/reset-password'),
/// ),
/// FilledButton(...), // no extra SizedBox above
/// ```
class DSFormActionLink extends StatelessWidget {
  const DSFormActionLink({
    super.key,
    required this.label,
    required this.onPressed,
    this.alignment = Alignment.centerRight,
    this.includeTopSpacing = true,
    this.includeBottomSpacing = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AlignmentGeometry alignment;
  final bool includeTopSpacing;
  final bool includeBottomSpacing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? DSColors.primaryDark : DSColors.primary;

    return Padding(
      padding: EdgeInsets.only(
        top: includeTopSpacing ? DSSpacing.formFieldToAction : 0,
        bottom: includeBottomSpacing ? DSSpacing.formActionToCta : 0,
      ),
      child: Align(
        alignment: alignment,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: color,
            // Compact vertical padding — outer DSSpacing owns the gap.
            padding: const EdgeInsets.symmetric(
              horizontal: DSSpacing.sm,
              vertical: DSSpacing.xs,
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          child: Text(
            label,
            style: DSTypography.button(color: color).copyWith(
              fontSize: DSTypography.sizeSm,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
