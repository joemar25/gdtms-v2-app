// DOCS: docs/development-standards.md
// DOCS: docs/features/dispatch.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';

/// Dispatch summary card — gold hero (start-work hierarchy) + detail tiles.
///
/// Used on [DispatchEligibilityScreen] (dispatch details).
class DispatchInfoCard extends StatelessWidget {
  const DispatchInfoCard({
    super.key,
    required this.maskedCode,
    required this.info,
  });

  final String maskedCode;
  final Map<String, dynamic> info;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final branch = info['branch'] is Map
        ? info['branch'] as Map
        : <String, dynamic>{};
    final branchName = branch['branch_name']?.toString() ?? '—';
    final volume = info['volume']?.toString() ?? '—';
    final tat = info['tat']?.toString() ?? '';
    final transmittalDate = info['transmittal_date']?.toString() ?? '';

    return DSCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Gold = start-work accent (same hierarchy as dashboard Dispatch).
          DSHeroCard(
            accentColor: DSColors.gold,
            padding: EdgeInsets.all(DSSpacing.md),
            child: Row(
              children: [
                Container(
                  width: DSIconSize.heroSm,
                  height: DSIconSize.heroSm,
                  decoration: BoxDecoration(
                    color: DSColors.white.withValues(
                      alpha: DSStyles.alphaSubtle,
                    ),
                    borderRadius: DSStyles.pillRadius,
                  ),
                  child: const Icon(
                    Icons.qr_code_rounded,
                    color: DSColors.white,
                    size: DSIconSize.md,
                  ),
                ),
                DSSpacing.wMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DISPATCH CODE',
                        style:
                            DSTypography.caption(
                              color: DSColors.white.withValues(
                                alpha: DSStyles.alphaDisabled,
                              ),
                            ).copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: DSTypography.sizeXs,
                              letterSpacing: DSTypography.lsLoose,
                            ),
                      ),
                      DSSpacing.hXs,
                      Text(
                        maskedCode,
                        style: DSTypography.heading().copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: DSTypography.sizeMd,
                          color: DSColors.white,
                          letterSpacing: DSTypography.lsLoose,
                          height: DSStyles.heightTight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              DSSpacing.md,
              DSSpacing.sm,
              DSSpacing.md,
              DSSpacing.md,
            ),
            child: Column(
              children: [
                DSDetailTile(
                  title: branchName,
                  subtitle: 'BRANCH',
                  isSubtitleTop: true,
                  icon: Icons.store_outlined,
                  iconColor: DSColors.primary,
                ),
                DSDetailTile(
                  title: volume,
                  subtitle: 'ITEMS',
                  isSubtitleTop: true,
                  icon: Icons.inventory_2_outlined,
                  iconColor: DSColors.primary,
                ),
                DSDetailTile(
                  title: transmittalDate.isNotEmpty
                      ? formatDate(transmittalDate)
                      : '—',
                  subtitle: 'TRANSMITTAL DATE',
                  isSubtitleTop: true,
                  icon: Icons.event_outlined,
                  iconColor: DSColors.primary,
                ),
                DSDetailTile(
                  title: tat.isNotEmpty
                      ? formatDate(tat, includeTime: false)
                      : '—',
                  subtitle: 'TAT',
                  isSubtitleTop: true,
                  icon: Icons.schedule_outlined,
                  iconColor: isDark
                      ? DSColors.labelSecondaryDark
                      : DSColors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
