import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/utils/formatters.dart';

/// A card widget that displays earnings information, typically showing
/// tentative payout and pending request amounts.
class EarningsCard extends StatelessWidget {
  const EarningsCard({
    super.key,
    required this.tentativePayout,
    required this.pendingRequestAmt,
    required this.canConsolidate,
    required this.canRequest,
    this.onTap,
    this.onConsolidate,
    this.onRequest,
    this.watermarkIcon = Icons.account_balance_wallet_rounded,
    this.isFlipping = true,
    this.isLatestPending = false,
    this.showPending = true,
    this.child,
  });

  final dynamic tentativePayout;
  final dynamic pendingRequestAmt;
  final bool canConsolidate;
  final bool canRequest;
  final VoidCallback? onTap;
  final VoidCallback? onConsolidate;
  final VoidCallback? onRequest;
  final IconData watermarkIcon;
  final bool isFlipping;
  final bool isLatestPending;
  final bool showPending;

  /// Optional child for the back-side of a flipping card.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final tentativeAmt = double.tryParse('$tentativePayout') ?? 0.0;
    final pendingAmt = double.tryParse('$pendingRequestAmt') ?? 0.0;

    final displayAmt = (isLatestPending && !showPending) ? 0.0 : tentativeAmt;
    final displayLabel = (isLatestPending && !showPending)
        ? 'wallet.card.accumulated_earnings'.tr()
        : 'wallet.card.available_balance'.tr();

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: DSColors.primary,
        borderRadius: DSStyles.cardRadius,
        boxShadow: [
          BoxShadow(
            color: DSColors.primary.withValues(alpha: DSStyles.alphaMuted),
            blurRadius: DSSpacing.xl,
            offset: const Offset(0, DSStyles.radiusSM),
          ),
        ],
      ),
      child: Material(
        color: DSColors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: DSStyles.cardRadius,
          highlightColor: DSColors.white.withValues(alpha: DSStyles.alphaSoft),
          splashColor: DSColors.white.withValues(alpha: DSStyles.alphaSoft),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                top: 20,
                child: Icon(
                  watermarkIcon,
                  size: 180,
                  color: DSColors.white.withValues(alpha: DSStyles.alphaMuted),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.all(DSSpacing.xl),
                    child:
                        child ??
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  displayLabel.toUpperCase(),
                                  style:
                                      DSTypography.caption(
                                        color: DSColors.white,
                                      ).copyWith(
                                        fontSize: DSTypography.sizeXs,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing:
                                            DSTypography.lsExtraLoose,
                                      ),
                                ),
                                DSSpacing.wXs,
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: DSColors.white.withValues(
                                    alpha: DSStyles.alphaDisabled,
                                  ),
                                  size: DSIconSize.xs,
                                ),
                              ],
                            ),
                            DSSpacing.hSm,
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '₱',
                                  style:
                                      DSTypography.title(
                                        color: DSColors.white,
                                      ).copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: DSTypography.sizeXl,
                                      ),
                                ),
                                DSSpacing.wXs,
                                Text(
                                  _fmt(displayAmt),
                                  style:
                                      DSTypography.display(
                                        color: DSColors.white,
                                      ).copyWith(
                                        fontWeight: FontWeight.w900,
                                        fontSize: DSTypography.sizeDisplayHero,
                                        letterSpacing: -0.5,
                                      ),
                                ),
                              ],
                            ),
                            if (isFlipping) ...[
                              DSSpacing.hMd,
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: DSSpacing.md,
                                  vertical: DSSpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: DSColors.white.withValues(
                                    alpha: DSStyles.alphaSoft,
                                  ),
                                  borderRadius: DSStyles.cardRadius,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.touch_app_rounded,
                                      color: DSColors.white,
                                      size: DSIconSize.xs,
                                    ),
                                    DSSpacing.wXs,
                                    Flexible(
                                      child: Text(
                                        'wallet.card.tap_to_view_account'.tr(),
                                        style:
                                            DSTypography.caption(
                                              color: DSColors.white,
                                            ).copyWith(
                                              fontWeight: FontWeight.w800,
                                              letterSpacing:
                                                  DSTypography.lsExtraLoose,
                                              fontSize: DSTypography.sizeXs,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                  ),
                  if ((showPending && isLatestPending && pendingAmt > 0) ||
                      (canRequest && onRequest != null))
                    Container(
                      padding: EdgeInsets.all(
                        isLatestPending ? DSSpacing.lg : DSSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: DSColors.black.withValues(
                          alpha: DSStyles.alphaSoft,
                        ),
                      ),
                      child: isLatestPending
                          ? Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(DSSpacing.md),
                                  decoration: const BoxDecoration(
                                    color: DSColors.pendingSurface,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.schedule_rounded,
                                    color: DSColors.pending,
                                    size: DSIconSize.md,
                                  ),
                                ),
                                DSSpacing.wMd,
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'wallet.card.pending_payout'.tr(),
                                        style:
                                            DSTypography.caption(
                                              color: DSColors.white,
                                            ).copyWith(
                                              fontWeight: FontWeight.w800,
                                              letterSpacing:
                                                  DSTypography.lsExtraLoose,
                                              fontSize: DSTypography.sizeXs,
                                            ),
                                      ),
                                      Text(
                                        AppFormatters.currency(pendingAmt),
                                        style:
                                            DSTypography.body(
                                              color: DSColors.white.withValues(
                                                alpha: DSStyles.alphaDisabled,
                                              ),
                                            ).copyWith(
                                              fontWeight: FontWeight.w600,
                                              fontSize: DSTypography.sizeMd,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (canConsolidate && onConsolidate != null)
                                  ElevatedButton.icon(
                                    onPressed: onConsolidate,
                                    icon: const Icon(
                                      Icons.swap_calls_rounded,
                                      size: 20,
                                    ),
                                    label: Text('wallet.card.consolidate'.tr()),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: DSColors.white,
                                      foregroundColor: DSColors.primary,
                                      elevation: 0,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: DSSpacing.lg,
                                        vertical: DSSpacing.md,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: DSStyles.cardRadius,
                                      ),
                                    ),
                                  ),
                              ],
                            )
                          : Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: DSSpacing.sm,
                              ),
                              child: ElevatedButton.icon(
                                onPressed: onRequest,
                                icon: const Icon(
                                  Icons.payments_rounded,
                                  size: 20,
                                ),
                                label: Text(
                                  'wallet.screen.request_payout'.tr(),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: DSColors.white,
                                  foregroundColor: DSColors.primary,
                                  elevation: 0,
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: DSStyles.cardRadius,
                                  ),
                                ),
                              ),
                            ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(dynamic val) {
    final n = double.tryParse('$val') ?? 0.0;
    return n.toStringAsFixed(2);
  }
}
