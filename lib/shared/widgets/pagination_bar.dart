// DOCS: docs/shared/widgets.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.firstItem,
    required this.lastItem,
    required this.totalCount,
    required this.onPageChanged,
  });

  final int currentPage;
  final int totalPages;
  final int firstItem;
  final int lastItem;
  final int totalCount;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? DSColors.cardDark : DSColors.cardLight,
        border: Border(
          top: BorderSide(
            color: isDark ? DSColors.separatorDark : DSColors.separatorLight,
          ),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: DSSpacing.md,
        vertical: DSSpacing.md,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: Range details
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'LISTING $firstItem – $lastItem',
                  style:
                      DSTypography.label(
                        color: isDark
                            ? DSColors.labelSecondaryDark
                            : DSColors.labelSecondary,
                      ).copyWith(
                        fontSize: DSTypography.sizeXs,
                        letterSpacing: DSTypography.lsExtraLoose,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                DSSpacing.hXs,
                Text(
                  'OF $totalCount ENTRIES',
                  style:
                      DSTypography.label(
                        color: isDark
                            ? DSColors.labelPrimaryDark
                            : DSColors.labelPrimary,
                      ).copyWith(
                        fontSize: DSTypography.sizeSm,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),

            // Right: Page Indicator + Swipe Prompt
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: DSSpacing.md,
                vertical: DSSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? DSColors.white.withValues(alpha: DSStyles.alphaSoft)
                    : DSColors.secondarySurfaceLight,
                borderRadius: DSStyles.cardRadius,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (currentPage > 0)
                    InkWell(
                      borderRadius: DSStyles.cardRadius,
                      onTap: () => onPageChanged(currentPage - 1),
                      child: Padding(
                        padding: EdgeInsets.all(DSSpacing.xs),
                        child: Icon(
                          Icons.keyboard_arrow_left_rounded,
                          size: DSIconSize.sm,
                          color: cs.onSurface.withValues(
                            alpha: DSStyles.alphaMuted,
                          ),
                        ),
                      ),
                    ),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: DSSpacing.sm),
                    child: Text(
                      'PAGE ${currentPage + 1} / $totalPages',
                      style: DSTypography.label(color: DSColors.primary)
                          .copyWith(
                            fontSize: DSTypography.sizeSm,
                            fontWeight: FontWeight.w800,
                            letterSpacing: DSTypography.lsLoose,
                          ),
                    ),
                  ),

                  if (currentPage < totalPages - 1)
                    InkWell(
                      borderRadius: DSStyles.cardRadius,
                      onTap: () => onPageChanged(currentPage + 1),
                      child: Padding(
                        padding: EdgeInsets.all(DSSpacing.xs),
                        child: Icon(
                          Icons.keyboard_arrow_right_rounded,
                          size: DSIconSize.sm,
                          color: cs.onSurface.withValues(
                            alpha: DSStyles.alphaMuted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
