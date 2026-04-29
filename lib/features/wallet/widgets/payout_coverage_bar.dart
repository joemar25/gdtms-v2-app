import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

class PayoutCoverageBar extends StatelessWidget {
  const PayoutCoverageBar({
    super.key,
    required this.fromDate,
    required this.toDate,
    required this.fmtShort,
  });

  final String fromDate;
  final String toDate;
  final String Function(String) fmtShort;

  @override
  Widget build(BuildContext context) {
    // If from == to (single day), just say "Up to [date]"
    final isSingleDay = fromDate == toDate || fromDate.isEmpty;
    final label = isSingleDay
        ? 'Up to ${fmtShort(toDate)}'
        : '${fmtShort(fromDate)}  –  ${fmtShort(toDate)}';

    // Calculate dynamic duration label
    String? durationLabel;
    if (!isSingleDay && fromDate.isNotEmpty && toDate.isNotEmpty) {
      try {
        final start = DateTime.parse(fromDate);
        final end = DateTime.parse(toDate);
        final days = end.difference(start).inDays + 1;
        durationLabel = '$days DAYS';
      } catch (_) {
        // Fallback if parsing fails
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DSSpacing.md, // Replaced 14 with md (16)
        vertical: DSSpacing.md,
      ),
      decoration: BoxDecoration(
        color: DSColors.primary.withValues(alpha: DSStyles.alphaSoft),
        borderRadius: DSStyles.cardRadius,
        border: Border.all(
          color: DSColors.primary.withValues(alpha: DSStyles.alphaMuted),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.date_range_rounded,
            size: DSIconSize.md,
            color: DSColors.primary,
          ),
          DSSpacing.wSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'COVERAGE PERIOD',
                  style: DSTypography.caption(color: DSColors.primary).copyWith(
                    fontSize: DSTypography.sizeXs,
                    fontWeight: FontWeight.w800,
                    letterSpacing: DSTypography.lsExtraLoose,
                  ),
                ),
                DSSpacing.hXs,
                Text(
                  label,
                  style: DSTypography.body().copyWith(
                    fontSize: DSTypography.sizeMd,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (durationLabel != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DSSpacing.md,
                vertical: DSSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: DSColors.primary.withValues(alpha: DSStyles.alphaSubtle),
                borderRadius: DSStyles.cardRadius,
              ),
              child: Text(
                durationLabel,
                style: DSTypography.caption(color: DSColors.primary).copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: DSTypography.sizeXs,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
