import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/core/config.dart'; // for kAppDebugMode

class PayoutSummaryCard extends StatelessWidget {
  const PayoutSummaryCard({
    super.key,
    required this.eligibleCount,
    required this.estimatedGross,
    required this.estimatedPenalties,
    required this.estimatedIncentive,
    required this.estimatedNet,
    this.deliveriesLabel = 'Eligible Deliveries',
  });

  final int eligibleCount;
  final double estimatedGross;
  final double estimatedPenalties;
  final double estimatedIncentive;
  final double estimatedNet;
  final String deliveriesLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: DSColors.transparent,
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: 20,
              child: Icon(
                Icons.inventory_2_rounded,
                size: 140,
                color: DSColors.white.withValues(alpha: DSStyles.alphaMuted),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(DSSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        deliveriesLabel.toUpperCase(),
                        style: DSTypography.caption(color: DSColors.white)
                            .copyWith(
                              fontSize: DSTypography.sizeXs,
                              fontWeight: FontWeight.w800,
                              letterSpacing: DSTypography.lsExtraLoose,
                            ),
                      ),
                      const Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: DSSpacing.sm,
                          vertical: DSSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: DSColors.white.withValues(
                            alpha: DSStyles.alphaSubtle,
                          ),
                          borderRadius: DSStyles.fullRadius,
                        ),
                        child: Text(
                          '$eligibleCount items',
                          style: DSTypography.caption(color: DSColors.white)
                              .copyWith(
                                fontSize: DSTypography.sizeSm,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                  DSSpacing.hLg,
                  Text(
                    'ESTIMATED NET PAYOUT',
                    style: DSTypography.caption(color: DSColors.white).copyWith(
                      fontSize: DSTypography.sizeXs,
                      fontWeight: FontWeight.w800,
                      letterSpacing: DSTypography.lsExtraLoose,
                    ),
                  ),
                  DSSpacing.hSm,
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '₱',
                        style: DSTypography.title(color: DSColors.white)
                            .copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: DSTypography.sizeXl,
                            ),
                      ),
                      DSSpacing.wXs,
                      Text(
                        estimatedNet.toStringAsFixed(2),
                        style: DSTypography.display(color: DSColors.white)
                            .copyWith(
                              fontSize: DSTypography.sizeDisplayHero,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                      ),
                    ],
                  ),
                  if (estimatedGross != estimatedNet) ...[
                    DSSpacing.hLg,
                    Container(
                      padding: EdgeInsets.all(DSSpacing.md),
                      decoration: BoxDecoration(
                        color: DSColors.black.withValues(
                          alpha: DSStyles.alphaSoft,
                        ),
                        borderRadius: DSStyles.cardRadius,
                      ),
                      child: Column(
                        children: [
                          _PayoutAmountRow(
                            label: 'Gross Amount',
                            amount: estimatedGross,
                            color: DSColors.white,
                          ),
                          if (estimatedPenalties != 0) ...[
                            DSSpacing.hXs,
                            _PayoutAmountRow(
                              label: 'Penalties',
                              amount: estimatedPenalties,
                              isDeduction: true,
                              color: DSColors.white,
                            ),
                          ],
                          if (kAppDebugMode && estimatedIncentive != 0) ...[
                            DSSpacing.hXs,
                            _PayoutAmountRow(
                              label: '⚠ Coordinator Incentive',
                              amount: estimatedIncentive,
                              isDeduction: true,
                              isDebug: true,
                              color: DSColors.warning,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayoutAmountRow extends StatelessWidget {
  const _PayoutAmountRow({
    required this.label,
    required this.amount,
    this.isDeduction = false,
    this.isDebug = false,
    this.color,
  });

  final String label;
  final double amount;
  final bool isDeduction;
  final bool isDebug;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c =
        color ??
        (Theme.of(context).brightness == Brightness.dark
            ? DSColors.labelSecondaryDark
            : DSColors.labelSecondary);

    return Padding(
      padding: EdgeInsets.only(bottom: DSSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: DSTypography.caption(color: c).copyWith(
                  fontSize: DSTypography.sizeXs,
                  fontWeight: FontWeight.w800,
                  letterSpacing: DSTypography.lsExtraLoose,
                ),
              ),
              if (isDebug)
                Text(
                  'DEBUG ONLY — not visible in production',
                  style:
                      DSTypography.caption(
                        color: DSColors.warning.withValues(
                          alpha: DSStyles.alphaDisabled,
                        ),
                      ).copyWith(
                        fontSize: DSTypography.sizeXs,
                        letterSpacing: DSTypography.lsLoose,
                      ),
                ),
            ],
          ),
          Text(
            '${isDeduction ? '-' : ''}₱ ${amount.abs().toStringAsFixed(2)}',
            style: DSTypography.label(color: c).copyWith(
              fontSize: DSTypography.sizeMd,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
