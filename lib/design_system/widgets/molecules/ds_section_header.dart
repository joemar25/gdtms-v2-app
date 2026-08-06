// DOCS: docs/development-standards.md
// DOCS: docs/design-system.md — update that file when you edit this one.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

/// Caption tone for post-login section titles.
///
/// - [shell] — secondary label (dashboard language; default for work screens).
/// - [brand] — primary green emphasis (rare; marketing / brand callouts).
enum DsSectionTone { shell, brand }

/// Uppercase section title used across shell tabs and lists.
///
/// Prefer [DsSectionTone.shell] so gold/green CTAs stay louder than labels.
class DSSectionHeader extends StatelessWidget {
  const DSSectionHeader({
    super.key,
    required this.title,
    this.padding,
    this.trailing,
    this.useLocalization = false,
    this.tone = DsSectionTone.shell,
  });

  final String title;
  final EdgeInsetsGeometry? padding;
  final Widget? trailing;
  final bool useLocalization;

  /// Visual tone. Defaults to [DsSectionTone.shell] (dashboard standard).
  final DsSectionTone tone;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = switch (tone) {
      DsSectionTone.brand => DSColors.primary,
      DsSectionTone.shell =>
        isDark ? DSColors.labelSecondaryDark : DSColors.labelSecondary,
    };

    final effectivePadding =
        padding ??
        const EdgeInsets.fromLTRB(
          DSSpacing.md,
          DSSpacing.lg,
          DSSpacing.md,
          DSSpacing.sm,
        );

    return Padding(
      padding: effectivePadding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            (useLocalization ? title.tr() : title).toUpperCase(),
            style: DSTypography.caption(color: color).copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              fontSize: DSTypography.sizeXs,
            ),
          ),
          ...[trailing].nonNulls,
        ],
      ),
    );
  }
}
