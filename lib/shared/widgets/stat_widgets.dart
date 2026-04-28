// DOCS: docs/shared/widgets.md — update that file when you edit this one.

import 'package:flutter/material.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

class StatCard extends StatefulWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    this.onTap,
    this.subdued = false,
    this.details,
    this.heroTag,
  });

  final String label;
  final String count;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool subdued;
  final String? details;
  final String? heroTag;

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<Offset> _iconOffset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _iconOffset = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 0.12),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap != null) _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onTap != null) {
      _controller.reverse();
      widget.onTap!();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? DSColors.cardDark : DSColors.cardLight;
    final effectiveColor = widget.subdued
        ? widget.color.withValues(alpha: DSStyles.alphaDisabled)
        : widget.color;
    final isDisabled = widget.onTap == null;

    final content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: DSSpacing.md,
      ),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: DSStyles.cardRadius,
        border: Border.all(
          color: widget.color.withValues(alpha: isDark ? 0.3 : 0.15),
          width: DSStyles.borderWidth * 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.color.withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: DSStyles.radiusLG,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(DSSpacing.sm),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: DSStyles.alphaSoft),
                  shape: BoxShape.circle,
                ),
                child: SlideTransition(
                  position: _iconOffset,
                  child: Icon(widget.icon, color: effectiveColor, size: DSIconSize.sm),
                ),
              ),
              const Spacer(),
            ],
          ),
          DSSpacing.hSm,
          Text(
            widget.count,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DSTypography.display(color: effectiveColor),
          ),
          DSSpacing.hXs,
          Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DSTypography.label(
              color: isDark
                  ? DSColors.labelSecondaryDark
                  : DSColors.labelSecondary,
            ).copyWith(letterSpacing: 1.1),
          ),
          if (widget.details != null) ...[
            DSSpacing.hSm,
            Text(
              widget.details!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DSTypography.caption(
                color: isDark
                    ? DSColors.labelSecondaryDark
                    : DSColors.labelSecondary,
              ).copyWith(height: DSStyles.heightNormal),
            ),
          ],
        ],
      ),
    );

    if (isDisabled) {
      return Opacity(opacity: DSAnimations.opacityMuted, child: content);
    }

    final animatedContent = content
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(
          duration: DSAnimations.dHeroX4,
          color: widget.color.withValues(alpha: DSStyles.alphaSoft),
          delay: DSAnimations.dHeroX3,
        );

    final card = GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(scale: _scale, child: animatedContent),
    );

    if (widget.heroTag != null) {
      return Hero(tag: widget.heroTag!, child: card);
    }
    return card;
  }
}

class ScanButton extends StatelessWidget {
  const ScanButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.details,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? details;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child:
          Container(
                padding: EdgeInsets.symmetric(
                  vertical: DSSpacing.lg,
                  horizontal: DSSpacing.md,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: DSStyles.alphaSubtle),
                      color.withValues(alpha: DSStyles.alphaSoft),
                    ],
                  ),
                  borderRadius: DSStyles.cardRadius,
                  border: Border.all(
                    color: color.withValues(alpha: isDark ? 0.4 : 0.25),
                    width: DSStyles.strokeWidth,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: DSStyles.alphaSoft),
                      blurRadius: DSStyles.radiusMD,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(DSSpacing.md),
                      decoration: BoxDecoration(
                        color: color.withValues(
                          alpha: DSStyles.alphaSubtle,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: DSIconSize.xl),
                    ),
                    DSSpacing.hSm,
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DSTypography.label(color: color).copyWith(
                        fontSize: DSTypography.sizeSm,
                        letterSpacing: DSTypography.lsExtraLoose,
                      ),
                    ),
                    if (details != null) ...[
                      DSSpacing.hSm,
                      Text(
                        details!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: DSTypography.caption(
                          color: isDark
                              ? DSColors.labelSecondaryDark
                              : DSColors.labelSecondary,
                        ).copyWith(height: DSStyles.heightTight),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(
                duration: DSAnimations.dHeroX4,
                color: color.withValues(alpha: DSStyles.alphaSoft),
              ),
    );
  }
}
