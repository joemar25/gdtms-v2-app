// DOCS: docs/development-standards.md
// DOCS: docs/features/wallet.md

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fsi_courier_app/core/config.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

/// A card with a vertical colored strip used for grouping rundown items.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: DSStyles.elevationNone,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: DSStyles.cardRadius,
        side: BorderSide(
          color: Theme.of(
            context,
          ).dividerColor.withValues(alpha: DSStyles.alphaMuted),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DSSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).brightness == Brightness.dark
                    ? DSColors.labelSecondaryDark
                    : DSColors.labelSecondary,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w600,
              ),
            ),
            DSSpacing.hSm,
            ...children,
          ],
        ),
      ),
    );
  }
}

/// A lightweight badge for showing payout status with high-contrast text.
class StatusBadgeLight extends StatelessWidget {
  const StatusBadgeLight(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status.toUpperCase()) {
      'PAID' => (
        DSColors.white.withValues(alpha: DSStyles.alphaMuted),
        DSColors.white,
      ),
      'REJECTED' => (
        DSColors.error.withValues(alpha: DSStyles.alphaMuted),
        DSColors.white,
      ),
      'PROCESSING' => (
        DSColors.warning.withValues(alpha: DSStyles.alphaMuted),
        DSColors.white,
      ),
      _ => (
        DSColors.white.withValues(alpha: DSStyles.alphaSubtle),
        DSColors.white.withValues(alpha: DSStyles.alphaDisabled),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DSSpacing.md, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: DSStyles.cardRadius),
      child: Text(
        status.isEmpty ? '—' : status.replaceAll('_', ' ').toUpperCase(),
        style: DSTypography.label(
          color: fg,
        ).copyWith(fontSize: DSTypography.sizeSm, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// A premium hero card for Payout Details that supports a flip animation to reveal breakdown.
class PayoutHeroFlipCard extends StatefulWidget {
  const PayoutHeroFlipCard({
    super.key,
    required this.amount,
    required this.status,
    required this.reference,
    required this.periodLabel,
    this.totalItems,
    required this.breakdown,
  });

  final double amount;
  final String status;
  final String reference;
  final String periodLabel;
  final int? totalItems;
  final Map<String, dynamic> breakdown;

  @override
  State<PayoutHeroFlipCard> createState() => _PayoutHeroFlipCardState();
}

class _PayoutHeroFlipCardState extends State<PayoutHeroFlipCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: DSAnimations.dSlow,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    _isFront = !_isFront;
  }

  String _formatKey(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  Widget _buildHeroDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: DSTypography.label().copyWith(
            fontSize: DSTypography.sizeXs,
            fontWeight: FontWeight.w800,
            letterSpacing: DSTypography.lsExtraLoose,
            color: DSColors.white.withValues(alpha: DSStyles.alphaDisabled),
          ),
        ),
        DSSpacing.hXs,
        Text(
          value,
          style: DSTypography.body(color: DSColors.white).copyWith(
            fontSize: DSTypography.sizeMd,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFront() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [DSColors.primary, DSColors.success],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: DSStyles.cardRadius,
        boxShadow: [
          BoxShadow(
            color: DSColors.primary.withValues(alpha: DSStyles.alphaMuted),
            blurRadius: DSStyles.radiusMD,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(DSSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'wallet.detail.payout_amount'.tr().toUpperCase(),
                  style: DSTypography.label().copyWith(
                    fontSize: DSTypography.sizeXs,
                    fontWeight: FontWeight.w800,
                    letterSpacing: DSTypography.lsExtraLoose,
                    color: DSColors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusBadgeLight(widget.status),
            ],
          ),
          DSSpacing.hXs,
          Text(
            '₱ ${widget.amount.toStringAsFixed(2)}',
            style: DSTypography.display(color: DSColors.white).copyWith(
              fontSize: DSIconSize.xl,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          DSSpacing.hMd,
          Divider(
            color: DSColors.white.withValues(alpha: DSStyles.alphaMuted),
            height: DSStyles.borderWidth,
          ),
          DSSpacing.hMd,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.totalItems != null)
                Expanded(
                  flex: 2,
                  child: _buildHeroDetail(
                    'wallet.detail.items'.tr(),
                    '${widget.totalItems}',
                  ),
                ),
              Expanded(
                flex: 3,
                child: _buildHeroDetail(
                  'wallet.detail.reference'.tr(),
                  widget.reference,
                ),
              ),
              Expanded(
                flex: 4,
                child: _buildHeroDetail(
                  'wallet.detail.period'.tr(),
                  widget.periodLabel,
                ),
              ),
            ],
          ),
          if (widget.breakdown.isNotEmpty) ...[
            DSSpacing.hMd,
            Center(
              child: Text(
                'wallet.detail.tap_to_reveal'.tr(),
                style:
                    DSTypography.caption(
                      color: DSColors.white.withValues(
                        alpha: DSStyles.alphaDisabled,
                      ),
                    ).copyWith(
                      fontSize: DSTypography.sizeSm,
                      letterSpacing: DSTypography.lsLoose,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBack(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? null : DSColors.primaryGradient,
        color: isDark ? DSColors.cardDark : null,
        borderRadius: DSStyles.cardRadius,
        boxShadow: DSStyles.shadowLG(context),
      ),
      padding: const EdgeInsets.all(DSSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'wallet.detail.breakdown_details'.tr().toUpperCase(),
                  style: DSTypography.label().copyWith(
                    fontSize: DSTypography.sizeXs,
                    fontWeight: FontWeight.w800,
                    letterSpacing: DSTypography.lsExtraLoose,
                    color: DSColors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusBadgeLight(widget.status),
            ],
          ),
          DSSpacing.hMd,
          ...widget.breakdown.entries
              .where((e) {
                if (e.key == 'coordinator_incentive') return kAppDebugMode;
                return true;
              })
              .map((e) {
                final val = double.tryParse('${e.value}') ?? 0.0;
                final isDeduction = val < 0;
                final label = _formatKey(e.key);

                return Padding(
                  padding: const EdgeInsets.only(bottom: DSSpacing.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        label,
                        style: DSTypography.body().copyWith(
                          color: DSColors.white.withValues(
                            alpha: DSStyles.alphaOpaque,
                          ),
                          fontSize: DSTypography.sizeSm,
                        ),
                      ),
                      Text(
                        '₱ ${val.abs().toStringAsFixed(2)}',
                        style: DSTypography.body().copyWith(
                          color: isDeduction
                              ? DSColors.errorSurface
                              : DSColors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: DSTypography.sizeMd,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          DSSpacing.hMd,
          Center(
            child: Text(
              'wallet.detail.tap_to_reveal'.tr(), // Fixed label to use tr()
              style:
                  DSTypography.caption(
                    color: DSColors.white.withValues(
                      alpha: DSStyles.alphaDisabled,
                    ),
                  ).copyWith(
                    fontSize: DSTypography.sizeSm,
                    letterSpacing: DSTypography.lsLoose,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.breakdown.isNotEmpty ? _flip : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final isUnder = _controller.value > 0.5;
          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.001) // perspective
            ..rotateX(_controller.value * math.pi);

          return Transform(
            transform: transform,
            alignment: Alignment.center,
            child: isUnder
                ? Transform(
                    transform: Matrix4.identity()..rotateX(math.pi),
                    alignment: Alignment.center,
                    child: _buildBack(context),
                  )
                : _buildFront(),
          );
        },
      ),
    );
  }
}
