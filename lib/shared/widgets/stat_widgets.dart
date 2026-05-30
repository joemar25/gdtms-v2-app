// DOCS: docs/development-standards.md
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
    this.minHeight,
  });

  final String label;
  final String count;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool subdued;
  final String? details;
  final String? heroTag;
  final double? minHeight;

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
    Color effectiveColor = widget.subdued
        ? widget.color.withValues(alpha: DSStyles.alphaDisabled)
        : widget.color;

    // Adjust color for legibility in Dark Mode if it's the primary brand color
    if (isDark && !widget.subdued) {
      if (widget.color == DSColors.primary) {
        effectiveColor = const Color(0xFF4ADE80); // Green 400 for high contrast
      } else if (widget.color == DSColors.success) {
        effectiveColor = DSColors.successDark;
      }
    }

    final isDisabled = widget.onTap == null;

    final displayLabel = widget.label
        .split(' ')
        .map(
          (s) => s.isEmpty
              ? ''
              : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}',
        )
        .join(' ');

    final content = Container(
      constraints: widget.minHeight != null
          ? BoxConstraints(minHeight: widget.minHeight!)
          : null,
      padding: const EdgeInsets.all(DSSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  DSColors.cardDark,
                  Color.alphaBlend(
                    widget.color.withValues(alpha: 0.04),
                    DSColors.cardDark,
                  ),
                ]
              : [
                  DSColors.cardLight,
                  Color.alphaBlend(
                    widget.color.withValues(alpha: 0.02),
                    DSColors.cardLight,
                  ),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DSStyles.radiusXL),
        border: Border.all(
          color: widget.color.withValues(alpha: isDark ? 0.25 : 0.12),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.color.withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
                padding: const EdgeInsets.all(DSSpacing.sm),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.color.withValues(alpha: isDark ? 0.22 : 0.15),
                      widget.color.withValues(alpha: isDark ? 0.08 : 0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color.withValues(alpha: isDark ? 0.35 : 0.20),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(
                        alpha: isDark ? 0.15 : 0.08,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SlideTransition(
                  position: _iconOffset,
                  child: Icon(widget.icon, color: effectiveColor, size: 20.0),
                ),
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .shimmer(
                duration: 3000.ms,
                color: widget.color.withValues(alpha: 0.25),
              ),
          DSSpacing.wSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayLabel.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      DSTypography.caption(
                        color: isDark
                            ? DSColors.labelSecondaryDark
                            : DSColors.labelSecondary,
                      ).copyWith(
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                        fontSize: 9.0,
                      ),
                ),
                Text(
                  widget.count,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DSTypography.display(color: effectiveColor).copyWith(
                    height: 1.0,
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                  ),
                ),
                if (widget.details != null) ...[
                  DSSpacing.hXs,
                  Text(
                    widget.details!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DSTypography.caption(
                      color: isDark
                          ? DSColors.labelSecondaryDark
                          : DSColors.labelSecondary,
                    ).copyWith(height: DSStyles.heightTight, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (isDisabled) {
      return Opacity(opacity: DSAnimations.opacityMuted, child: content);
    }

    final animatedContent = content
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(
          duration: 4000.ms,
          color: widget.color.withValues(alpha: 0.08),
          delay: 2000.ms,
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
    this.minHeight,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? details;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child:
          Container(
                constraints: minHeight != null
                    ? BoxConstraints(minHeight: minHeight!)
                    : null,
                padding: const EdgeInsets.symmetric(
                  vertical: DSSpacing.lg,
                  horizontal: DSSpacing.md,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            color.withValues(alpha: 0.15),
                            color.withValues(alpha: 0.05),
                          ]
                        : [
                            color.withValues(alpha: 0.08),
                            color.withValues(alpha: 0.02),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(DSStyles.radiusXL),
                  border: Border.all(
                    color: color.withValues(alpha: isDark ? 0.35 : 0.18),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: isDark ? 0.15 : 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                          padding: const EdgeInsets.all(DSSpacing.md),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                color.withValues(alpha: 0.25),
                                color.withValues(alpha: 0.1),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color.withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(icon, color: color, size: 28.0),
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(
                          begin: const Offset(1.0, 1.0),
                          end: const Offset(1.05, 1.05),
                          duration: 1500.ms,
                          curve: Curves.easeInOut,
                        ),
                    DSSpacing.hMd,
                    Text(
                      label.toUpperCase(),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DSTypography.labelCaps(color: color).copyWith(
                        fontSize: 11.0,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (details != null) ...[
                      DSSpacing.hSm,
                      Text(
                        details!,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: DSTypography.caption(
                          color: isDark
                              ? DSColors.labelSecondaryDark
                              : DSColors.labelSecondary,
                        ).copyWith(fontSize: 10.0, height: 1.3),
                      ),
                    ],
                  ],
                ),
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .shimmer(
                duration: 4000.ms,
                color: color.withValues(alpha: 0.08),
                delay: 2000.ms,
              ),
    );
  }
}
