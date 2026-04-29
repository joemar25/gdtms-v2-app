import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/utils/formatters.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';

/// A row widget for displaying a single payout request in the history list.
class PayoutHistoryRow extends StatelessWidget {
  const PayoutHistoryRow({super.key, required this.data, required this.onTap});

  final Map<String, dynamic> data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = '${data['status'] ?? ''}';
    final amount = double.tryParse('${data['amount'] ?? 0}') ?? 0.0;
    final rawDate =
        data['requested_at'] ??
        data['date'] ??
        data['updated_at'] ??
        data['created_at'] ??
        data['paid_at'] ??
        data['transaction_date'] ??
        data['to_date'] ??
        data['from_date'] ??
        '';
    final dateLabel = formatDate(
      '$rawDate',
      includeTime: rawDate.toString().contains('T'),
    ).trim();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String statusUpper = status.toUpperCase();
    final bool isCompleted = statusUpper == 'PAID' || statusUpper == 'RELEASED';
    final bool isPending =
        statusUpper == 'PENDING' || statusUpper == 'PROCESSING';
    final bool isApproved =
        statusUpper == 'APPROVED' ||
        statusUpper == 'OPS_APPROVED' ||
        statusUpper == 'HR_APPROVED';

    final Color iconBgColor = isCompleted
        ? DSColors.successSurface
        : (isPending
              ? DSColors.pendingSurface
              : (isApproved ? DSColors.primarySurface : DSColors.errorSurface));
    final Color iconColor = isCompleted
        ? DSColors.success
        : (isPending
              ? DSColors.pending
              : (isApproved ? DSColors.primary : DSColors.error));
    final IconData iconData = isCompleted
        ? Icons.payments_rounded
        : (isPending
              ? Icons.schedule_rounded
              : (isApproved
                    ? Icons.check_circle_outline_rounded
                    : Icons.cancel_outlined));

    final String title = isCompleted
        ? 'wallet.history_row.completed'.tr()
        : (isPending
              ? 'wallet.history_row.request'.tr()
              : (isApproved
                    ? 'wallet.history_row.approved'.tr()
                    : 'wallet.history_row.cancelled'.tr()));

    final reference = '${data['reference'] ?? data['payment_reference'] ?? ''}';

    return InkWell(
      onTap: onTap,
      borderRadius: DSStyles.cardRadius,
      child: Container(
        margin: const EdgeInsets.symmetric(
          vertical: DSSpacing.xs,
          horizontal: DSSpacing.xs,
        ),
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
              width: DSIconSize.heroSm,
              height: DSIconSize.heroSm,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: DSStyles.cardRadius,
              ),
              child: Center(
                child: Icon(iconData, color: iconColor, size: DSIconSize.md),
              ),
            ),
            DSSpacing.wMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: DSTypography.body().copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? DSColors.white : DSColors.labelPrimary,
                    ),
                  ),
                  DSSpacing.hXs,
                  Text(
                    [
                      if (dateLabel.isNotEmpty) dateLabel,
                      if (reference.isNotEmpty) reference,
                    ].join(' \u2022 '),
                    style: DSTypography.caption(
                      color: isDark
                          ? DSColors.labelSecondaryDark
                          : DSColors.labelSecondary,
                    ).copyWith(fontSize: DSTypography.sizeSm),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PayoutStatusBadge(status: status),
                DSSpacing.hSm,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppFormatters.currency(amount),
                      style:
                          DSTypography.title(
                            color: isDark
                                ? DSColors.white
                                : DSColors.labelPrimary,
                          ).copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: DSTypography.sizeMd,
                            letterSpacing: DSTypography.lsTight,
                          ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDark
                          ? DSColors.labelTertiaryDark
                          : DSColors.labelTertiary,
                      size: DSIconSize.sm,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PayoutStatusBadge extends StatelessWidget {
  const PayoutStatusBadge({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (bg, fg) = switch (status.toUpperCase()) {
      'PAID' => (
        DSColors.success.withValues(alpha: DSStyles.alphaSubtle),
        DSColors.success,
      ),
      'APPROVED' || 'OPS_APPROVED' || 'HR_APPROVED' => (
        DSColors.primary.withValues(alpha: DSStyles.alphaSubtle),
        DSColors.primary,
      ),
      'REJECTED' => (
        DSColors.error.withValues(alpha: DSStyles.alphaSubtle),
        DSColors.error,
      ),
      'PENDING' || 'PROCESSING' => (
        DSColors.warning.withValues(alpha: DSStyles.alphaSubtle),
        DSColors.warning,
      ),
      _ => (
        isDark ? DSColors.secondarySurfaceDark : DSColors.secondarySurfaceLight,
        isDark ? DSColors.labelTertiaryDark : DSColors.labelTertiary,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DSSpacing.md,
        vertical: DSSpacing.xs,
      ),
      decoration: BoxDecoration(color: bg, borderRadius: DSStyles.cardRadius),
      child: Text(
        status.isEmpty ? '' : status.replaceAll('_', ' ').toUpperCase(),
        style: DSTypography.label(
          color: fg,
        ).copyWith(fontSize: DSTypography.sizeSm),
      ),
    );
  }
}
