// DOCS: docs/development-standards.md
// DOCS: docs/features/wallet.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';

/// Shows a bottom sheet containing only the transaction history/stepper for a payout.
///
/// ### Features
/// - Implements a vertical stepper for the [transaction_history] with the latest
///   event highlighted at the top.
/// - Integrates with [DesignSystem] tokens for spacing, colors, and typography.
///
/// [history] is the raw list of transaction events from the payout data.
Future<void> showPayoutHistorySheet({
  required BuildContext context,
  required List<dynamic> history,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  final sortedHistory = history
      .whereType<Map<String, dynamic>>()
      .toList()
      .reversed
      .toList();

  if (sortedHistory.isEmpty) return;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: DSColors.transparent,
    builder: (ctx) {
      return SecureView(
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? DSColors.cardDark : DSColors.cardLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: DSColors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                blurRadius: DSStyles.radiusXL,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(
            DSSpacing.lg,
            DSSpacing.sm,
            DSSpacing.lg,
            MediaQuery.of(context).padding.bottom + DSSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Handle ───────────────────────────────────────────────────
              Center(
                child: Container(
                  width: DSIconSize.heroSm,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark
                        ? DSColors.separatorDark
                        : DSColors.separatorLight,
                    borderRadius: DSStyles.cardRadius,
                  ),
                ),
              ),
              DSSpacing.hMd,

              // ── Header ───────────────────────────────────────────────────
              DSSectionHeader(
                title: 'wallet.detail.request_lifecycle'.tr(),
                padding: EdgeInsets.zero,
                trailing: const SecureBadge(),
              ),

              DSSpacing.hMd,

              // ── Stepper Content ──────────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sortedHistory.length,
                    itemBuilder: (context, index) {
                      final item = sortedHistory[index];
                      final isLatest = index == 0;
                      final isLast = index == sortedHistory.length - 1;

                      return _StatusStepItem(
                        item: item,
                        isFirst: isLatest,
                        isLast: isLast,
                        isDark: isDark,
                      ).dsCardEntry(
                        delay: DSAnimations.stagger(
                          index,
                          step: DSAnimations.staggerNormal,
                        ),
                        duration: DSAnimations.dFast,
                      );
                    },
                  ),
                ),
              ),
              DSSpacing.hMd,
            ],
          ),
        ),
      );
    },
  );
}

/// A single item in the payout status stepper.
class _StatusStepItem extends StatelessWidget {
  const _StatusStepItem({
    required this.item,
    required this.isFirst,
    required this.isLast,
    required this.isDark,
  });

  final Map<String, dynamic> item;
  final bool isFirst;
  final bool isLast;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final label = '${item['label'] ?? item['event'] ?? ''}';
    final timestamp = formatDate(
      '${item['timestamp'] ?? ''}',
      includeTime: true,
    );
    final remarks = item['remarks']?.toString() ?? '';

    // The entire trail is treated as "Accepted" (Success)
    final Color accentColor = DSColors.success;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Stepper Spine ──────────────────────────────────────────────────
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor,
                  border: Border.all(color: accentColor, width: 2),
                ),
                child: Center(
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: DSColors.white,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),
          DSSpacing.wMd,

          // ── Content ────────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.replaceAll('_', ' ').toUpperCase(),
                  style: DSTypography.label().copyWith(
                    fontSize: DSTypography.sizeSm,
                    fontWeight: isFirst ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: DSTypography.lsLoose,
                    color: isFirst
                        ? (isDark ? DSColors.white : DSColors.labelPrimary)
                        : (isDark
                              ? DSColors.labelSecondaryDark
                              : DSColors.labelSecondary),
                  ),
                ),
                Text(
                  timestamp,
                  style: DSTypography.caption(
                    color: isDark
                        ? DSColors.labelTertiaryDark
                        : DSColors.labelTertiary,
                  ).copyWith(fontSize: DSTypography.sizeXs),
                ),
                if (remarks.isNotEmpty) ...[
                  DSSpacing.hXs,
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(DSSpacing.sm),
                    decoration: BoxDecoration(
                      color: isDark
                          ? DSColors.white.withValues(alpha: 0.05)
                          : DSColors.black.withValues(alpha: 0.03),
                      borderRadius: DSStyles.cardRadius,
                      border: Border.all(
                        color: isDark
                            ? DSColors.separatorDark
                            : DSColors.separatorLight,
                      ),
                    ),
                    child: Text(
                      remarks,
                      style: DSTypography.body().copyWith(
                        fontSize: DSTypography.sizeSm,
                        fontStyle: FontStyle.italic,
                        color: isDark
                            ? DSColors.labelSecondaryDark
                            : DSColors.labelSecondary,
                      ),
                    ),
                  ),
                ],
                if (!isLast) DSSpacing.hLg,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
