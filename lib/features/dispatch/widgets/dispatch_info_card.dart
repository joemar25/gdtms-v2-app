import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';

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
    final branch = info['branch'] is Map
        ? info['branch'] as Map
        : <String, dynamic>{};
    final branchName = branch['branch_name']?.toString() ?? '-';
    final volume = info['volume']?.toString() ?? '-';
    final tat = info['tat']?.toString() ?? '';
    final transmittalDate = info['transmittal_date']?.toString() ?? '';

    return DSCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          DSHeroCard(
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
                    Icons.local_shipping_outlined,
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
                      Text(
                        maskedCode,
                        style: DSTypography.heading().copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: DSTypography.sizeMd,
                          color: DSColors.white,
                          letterSpacing: DSTypography.lsLoose,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Details List (Icon First)
          Padding(
            padding: EdgeInsets.all(DSSpacing.md),
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
                  iconColor: DSColors.pending,
                ),
                DSDetailTile(
                  title: transmittalDate.isNotEmpty
                      ? formatDate(transmittalDate)
                      : '-',
                  subtitle: 'TRANSMITTAL DATE',
                  isSubtitleTop: true,
                  icon: Icons.event_outlined,
                  iconColor: DSColors.success,
                ),
                DSDetailTile(
                  title: tat.isNotEmpty
                      ? formatDate(tat, includeTime: false)
                      : '-',
                  subtitle: 'TAT',
                  isSubtitleTop: true,
                  icon: Icons.schedule_outlined,
                  iconColor: DSColors.warning,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
