// DOCS: docs/development-standards.md
// DOCS: docs/features/delivery.md — update that file when you edit this one.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

/// Gradient full-width submit button rendered as a floating action button.
///
/// Displays a [CircularProgressIndicator] when [isLoading] is true and
/// disables [onPressed] to prevent double-submission.
class DeliverySubmitFab extends StatelessWidget {
  const DeliverySubmitFab({
    super.key,
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: DSSpacing.md),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: DSStyles.cardRadius,
          boxShadow: [
            BoxShadow(
              color: DSColors.primary.withValues(alpha: DSStyles.alphaMuted),
              blurRadius: DSStyles.radiusMD,
              offset: const Offset(0, DSSpacing.sm),
            ),
          ],
          gradient: LinearGradient(
            colors: [
              DSColors.primary,
              DSColors.primary.withValues(alpha: DSStyles.alphaOpaque),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: FilledButton.icon(
          icon: isLoading
              ? const SizedBox(
                  width: DSIconSize.lg,
                  height: DSIconSize.lg,
                  child: CircularProgressIndicator(
                    strokeWidth: DSStyles.strokeWidth,
                    color: DSColors.white,
                  ),
                )
              : const Icon(Icons.check_circle_outline_rounded),
          label: Text(
            'delivery_update.button.submit_update'.tr(),
            style: DSTypography.button().copyWith(
              letterSpacing: DSTypography.lsExtraLoose,
              fontSize: DSTypography.sizeMd,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: DSColors.transparent,
            shadowColor: DSColors.transparent,
            minimumSize: const Size(double.infinity, DSIconSize.heroSm),
            shape: RoundedRectangleBorder(borderRadius: DSStyles.cardRadius),
          ),
          onPressed: isLoading ? null : onPressed,
        ),
      ),
    );
  }
}
