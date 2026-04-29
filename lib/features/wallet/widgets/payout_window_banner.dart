import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/core/config.dart';

class PayoutWindowBanner extends StatelessWidget {
  const PayoutWindowBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (kAppDebugMode) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: DSSpacing.md,
        ),
        decoration: BoxDecoration(
          color: DSColors.accent.withValues(alpha: DSStyles.alphaSoft),
          borderRadius: DSStyles.cardRadius,
          border: Border.all(
            color: DSColors.accent.withValues(alpha: DSStyles.alphaMuted),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.bug_report_rounded,
              color: DSColors.primary,
              size: DSIconSize.md,
            ),
            DSSpacing.wMd,
            Expanded(
              child: Text(
                '(DEBUG) Time restriction bypassed — requests allowed at any hour.',
                style: DSTypography.caption(color: DSColors.primary).copyWith(
                  fontSize: DSTypography.sizeSm,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: DSSpacing.md,
      ),
      decoration: BoxDecoration(
        color: DSColors.error.withValues(alpha: DSStyles.alphaSoft),
        borderRadius: DSStyles.cardRadius,
        border: Border.all(
          color: DSColors.error.withValues(alpha: DSStyles.alphaMuted),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_clock_rounded,
            color: DSColors.error,
            size: DSIconSize.md,
          ),
          DSSpacing.wMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payout Requests: Morning Only',
                  style: DSTypography.body(color: DSColors.error).copyWith(
                    fontSize: DSTypography.sizeMd,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                DSSpacing.hXs,
                Text(
                  'You can request a payout between '
                  '${kPayoutWindowStartHour.toString().padLeft(2, '0')}:00 AM '
                  'and '
                  '${kPayoutWindowEndHour == 12 ? '12:00 PM (noon)' : '${kPayoutWindowEndHour.toString().padLeft(2, '0')}:00'}. '
                  'Please come back during that window.',
                  style: DSTypography.caption(
                    color: DSColors.error.withValues(
                      alpha: DSStyles.alphaDisabled,
                    ),
                  ).copyWith(height: DSStyles.heightNormal),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
