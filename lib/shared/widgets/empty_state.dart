// DOCS: docs/development-standards.md
// DOCS: docs/shared/widgets.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_rounded,
    this.iconColor,
    this.subMessage,
  });

  final String message;
  final IconData icon;
  final Color? iconColor;
  final String? subMessage;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = iconColor ?? (isDark ? DSColors.white : DSColors.primary);
    final subtextColor = isDark
        ? DSColors.labelTertiaryDark
        : DSColors.labelTertiary;

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                  width: DSIconSize.heroMd,
                  height: DSIconSize.heroMd,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: DSStyles.alphaSoft),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: DSStyles.alphaSubtle),
                      width: DSStyles.strokeWidth,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: DSIconSize.xl,
                    color: color.withValues(alpha: DSStyles.alphaMuted),
                  ),
                )
                .animate()
                .fadeIn(duration: 500.ms)
                .slideY(begin: 0.1, duration: 500.ms, curve: Curves.easeOut),
            DSSpacing.hMd,
            Text(
              message,
              textAlign: TextAlign.center,
              style: DSTypography.label().copyWith(
                fontSize: DSTypography.sizeMd,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? DSColors.labelPrimaryDark
                    : DSColors.labelPrimary,
              ),
            ),
            if (subMessage != null) ...[
              DSSpacing.hSm,
              Text(
                subMessage!,
                textAlign: TextAlign.center,
                style: DSTypography.caption().copyWith(
                  fontSize: DSTypography.sizeSm,
                  color: subtextColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
