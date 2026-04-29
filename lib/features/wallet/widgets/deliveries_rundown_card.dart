import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/utils/formatters.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';

/// Unified card showing the aggregate rundown of deliveries grouped by date.
///
/// Security note: intentionally omits individual delivery details — only
/// the aggregated daily total is shown to reduce information exposure.
class DeliveriesRundownCard extends StatelessWidget {
  const DeliveriesRundownCard({super.key, required this.dailyBreakdown});

  final List<Map<String, dynamic>> dailyBreakdown;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < dailyBreakdown.length; i++) ...[
          _RundownRow(
            data: dailyBreakdown[i],
          ).dsFadeEntry(delay: DSAnimations.stagger(i + 3)),
          if (i < dailyBreakdown.length - 1) DSSpacing.hXs,
        ],
      ],
    );
  }
}

class _RundownRow extends StatelessWidget {
  const _RundownRow({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final dateStr = '${data['date'] ?? ''}';
    final count =
        data['delivery_count'] ?? (data['deliveries'] as List?)?.length ?? 0;
    final total = double.tryParse('${data['day_total'] ?? 0}') ?? 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(DSSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? DSColors.cardDark : DSColors.white,
        borderRadius: DSStyles.cardRadius,
        border: Border.all(
          color: Theme.of(
            context,
          ).dividerColor.withValues(alpha: DSStyles.alphaSoft),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: DSSpacing.xl,
            height: DSSpacing.xl,
            decoration: BoxDecoration(
              color: isDark
                  ? DSColors.white.withValues(alpha: DSStyles.alphaSubtle)
                  : DSColors.black.withValues(alpha: DSStyles.alphaSubtle),
              borderRadius: DSStyles.cardRadius,
            ),
            child: Icon(
              Icons.calendar_today_rounded,
              size: DSIconSize.sm,
              color: isDark ? DSColors.white : DSColors.labelPrimary,
            ),
          ),
          DSSpacing.wMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatDate(dateStr).toUpperCase(),
                  style: DSTypography.label().copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: DSTypography.sizeXs,
                    letterSpacing: DSTypography.lsExtraLoose,
                    color: isDark
                        ? DSColors.labelSecondaryDark
                        : DSColors.labelSecondary,
                  ),
                ),
                const SizedBox(height: DSSpacing.xs / 2),
                Text(
                  count == 1
                      ? 'wallet.rundown.one_delivery_item'.tr()
                      : 'wallet.rundown.delivery_items'.tr(
                          namedArgs: {'count': '$count'},
                        ),
                  style: DSTypography.body().copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: DSTypography.sizeMd,
                    color: isDark ? DSColors.white : DSColors.labelPrimary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            AppFormatters.currency(total),
            style:
                DSTypography.title(
                  color: isDark ? DSColors.white : DSColors.labelPrimary,
                ).copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: DSTypography.sizeMd,
                ),
          ),
        ],
      ),
    );
  }
}
