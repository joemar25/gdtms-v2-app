// DOCS: docs/development-standards.md
// DOCS: docs/shared/widgets.md — update that file when you edit this one.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

/// Dashboard metric tile — solid brand surfaces (not glass, not rainbow).
///
/// Prefer [DSColors.primary] or [DSColors.gold] for [color]. Active state is a
/// soft brand tint; empty tiles stay neutral.
///
/// **Hold-to-reveal (NBA 2K style):** when [details] is set, press-and-hold
/// flips to a detail panel that **stays open** so it is readable. Tap the
/// close (X) icon to hide details; tap anywhere else on the card to run
/// [onTap] (open the list). Short tap on the compact face also opens the list.
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

  /// Brand accent only — use primary / gold (not a full status rainbow).
  final Color color;
  final VoidCallback? onTap;
  final bool subdued;

  /// Shown on the reverse face after a hold; stays until close is tapped.
  final String? details;
  final String? heroTag;
  final double? minHeight;

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard> with TickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final AnimationController _revealCtrl;
  late final Animation<double> _pressScale;
  late final Animation<double> _reveal;
  late final Animation<double> _liftScale;

  /// True once details are open (stays until close icon).
  bool _revealed = false;

  bool get _hasActivity {
    final n = int.tryParse(widget.count);
    return n != null && n > 0 && !widget.subdued;
  }

  bool get _canReveal =>
      widget.details != null && widget.details!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: DSAnimations.dMicro,
    );
    _pressScale = Tween<double>(
      begin: 1.0,
      end: DSAnimations.scalePressed,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));

    _revealCtrl = AnimationController(
      vsync: this,
      duration: DSAnimations.dFast,
    );
    _reveal = CurvedAnimation(
      parent: _revealCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    // Slight lift while details are open — 2K card “pop”.
    _liftScale = Tween<double>(begin: 1.0, end: 1.04).animate(_reveal);
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    _revealCtrl.dispose();
    super.dispose();
  }

  void _showDetails() {
    if (!_canReveal || _revealed) return;
    setState(() => _revealed = true);
    _pressCtrl.reverse();
    _revealCtrl.forward();
    HapticFeedback.mediumImpact();
  }

  void _hideDetails() {
    if (!_revealed) return;
    setState(() => _revealed = false);
    _revealCtrl.reverse();
    HapticFeedback.selectionClick();
  }

  void _openList() {
    if (widget.onTap == null) return;
    HapticFeedback.selectionClick();
    widget.onTap!();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap != null || _canReveal) _pressCtrl.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _pressCtrl.reverse();
  }

  void _onTapCancel() {
    _pressCtrl.reverse();
  }

  /// Compact face or revealed body (not the close control) → open list.
  void _onCardTap() {
    if (widget.onTap == null) return;
    _openList();
  }

  void _onLongPress() {
    if (!_canReveal) return;
    if (_revealed) return; // already open — long-press is a no-op
    _showDetails();
  }

  String get _displayLabel => widget.label
      .split(' ')
      .map(
        (s) => s.isEmpty
            ? ''
            : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}',
      )
      .join(' ');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = _hasActivity;

    final accent = widget.subdued
        ? widget.color.withValues(alpha: DSStyles.alphaDisabled)
        : widget.color;

    final surface = isDark
        ? (active
              ? Color.alphaBlend(
                  DSColors.primary.withValues(alpha: 0.10),
                  DSColors.cardElevatedDark,
                )
              : DSColors.cardElevatedDark)
        : (active
              ? Color.alphaBlend(
                  DSColors.primary.withValues(alpha: 0.06),
                  DSColors.cardLight,
                )
              : DSColors.cardLight);

    // Reverse face — slightly richer brand wash.
    final reverseSurface = isDark
        ? Color.alphaBlend(
            accent.withValues(alpha: 0.18),
            DSColors.cardElevatedDark,
          )
        : Color.alphaBlend(accent.withValues(alpha: 0.10), DSColors.cardLight);

    final border = isDark
        ? (active
              ? DSColors.primary.withValues(alpha: 0.35)
              : DSColors.separatorDark)
        : (active
              ? DSColors.primary.withValues(alpha: 0.22)
              : DSColors.separatorLight);

    final labelColor = isDark
        ? DSColors.labelSecondaryDark
        : DSColors.labelSecondary;
    final countColor = active
        ? (isDark ? DSColors.labelPrimaryDark : DSColors.labelPrimary)
        : (isDark ? DSColors.labelSecondaryDark : DSColors.labelSecondary);
    final detailsColor = isDark
        ? DSColors.labelSecondaryDark
        : DSColors.labelSecondary;
    final hintColor = isDark
        ? DSColors.labelTertiaryDark
        : DSColors.labelTertiary;

    // Face content (icon + count + label + optional hold hint) needs ≥128
    // after padding — default +24 (124) overflowed by ~3px with hold hint.
    final minH = widget.minHeight ?? DSStyles.statCardHeight + 32;

    final card = AnimatedBuilder(
      animation: Listenable.merge([_pressScale, _reveal, _liftScale]),
      builder: (context, _) {
        final reveal = _reveal.value;
        final scale = _pressScale.value * _liftScale.value;
        final glow = Border.all(
          color: Color.lerp(
            border,
            accent.withValues(alpha: isDark ? 0.55 : 0.4),
            reveal,
          )!,
          width: 1 + reveal,
        );

        // Fixed footprint — face / reverse never change the card size.
        final faceAndReverse = SizedBox(
          width: double.infinity,
          height: minH,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color.lerp(surface, reverseSurface, reveal),
              borderRadius: BorderRadius.circular(DSStyles.radius2XL),
              border: glow,
              boxShadow: [
                BoxShadow(
                  color: DSColors.black.withValues(
                    alpha: (isDark ? 0.28 : 0.06) + reveal * 0.12,
                  ),
                  blurRadius: 12 + reveal * 10,
                  offset: Offset(0, 4 + reveal * 4),
                ),
                if (reveal > 0.01)
                  BoxShadow(
                    color: accent.withValues(alpha: 0.22 * reveal),
                    blurRadius: 18 * reveal,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(DSStyles.radius2XL),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: _AccentBar(
                      width: 3 + reveal * 2,
                      color: active || reveal > 0.2
                          ? accent
                          : DSColors.primary.withValues(alpha: 0.25),
                      pulse: active && reveal < 0.5,
                    ),
                  ),
                  // Compact face
                  Opacity(
                    opacity: (1.0 - reveal).clamp(0.0, 1.0),
                    child: _StatCardFace(
                      icon: widget.icon,
                      count: widget.count,
                      label: _displayLabel,
                      accent: accent,
                      active: active,
                      isDark: isDark,
                      labelColor: labelColor,
                      countColor: countColor,
                      hintColor: hintColor,
                      showHoldHint: _canReveal,
                    ),
                  ),
                  // Detail reverse (stays until X)
                  if (_canReveal)
                    Opacity(
                      opacity: reveal.clamp(0.0, 1.0),
                      child: IgnorePointer(
                        ignoring: reveal < 0.5,
                        child: _StatCardReverse(
                          icon: widget.icon,
                          count: widget.count,
                          label: _displayLabel,
                          details: widget.details!,
                          accent: accent,
                          isDark: isDark,
                          labelColor: labelColor,
                          countColor: countColor,
                          detailsColor: detailsColor,
                          hintColor: hintColor,
                          canOpen: widget.onTap != null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );

        // Close is a *sibling* of the open-list GestureDetector so it never
        // competes in the same arena — X hides details, body opens the list.
        return Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          child: SizedBox(
            width: double.infinity,
            height: minH,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTapDown: _onTapDown,
                    onTapUp: _onTapUp,
                    onTapCancel: _onTapCancel,
                    onTap: widget.onTap != null ? _onCardTap : null,
                    onLongPress: _canReveal ? _onLongPress : null,
                    behavior: HitTestBehavior.opaque,
                    child: faceAndReverse,
                  ),
                ),
                if (_canReveal && _revealed)
                  Positioned(
                    top: DSSpacing.sm,
                    right: DSSpacing.sm,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _hideDetails,
                      child: Tooltip(
                        message: 'dashboard.stats.hold_close_hint'.tr(),
                        child: Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isDark
                                ? DSColors.secondarySurfaceDark
                                : DSColors.secondarySurfaceLight,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? DSColors.separatorDark
                                  : DSColors.separatorLight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: DSColors.black.withValues(alpha: 0.18),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: DSIconSize.sm,
                            color: hintColor,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (widget.onTap == null && !_canReveal) {
      return Opacity(opacity: DSAnimations.opacityMuted, child: card);
    }

    if (widget.heroTag != null) {
      return Hero(tag: widget.heroTag!, child: card);
    }
    return card;
  }
}

/// Left accent strip — soft opacity pulse when the card has active work.
class _AccentBar extends StatelessWidget {
  const _AccentBar({
    required this.width,
    required this.color,
    required this.pulse,
  });

  final double width;
  final Color color;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    Widget bar = Container(width: width, color: color);
    if (pulse && !reduceMotion) {
      bar = bar
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .fade(
            begin: 0.55,
            end: 1,
            duration: DSAnimations.dHero,
            curve: Curves.easeInOut,
          );
    }
    return bar;
  }
}

/// Compact face — count + label; modern micro-motion when active.
class _StatCardFace extends StatelessWidget {
  const _StatCardFace({
    required this.icon,
    required this.count,
    required this.label,
    required this.accent,
    required this.active,
    required this.isDark,
    required this.labelColor,
    required this.countColor,
    required this.hintColor,
    required this.showHoldHint,
  });

  final IconData icon;
  final String count;
  final String label;
  final Color accent;
  final bool active;
  final bool isDark;
  final Color labelColor;
  final Color countColor;
  final Color hintColor;
  final bool showHoldHint;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final countValue = int.tryParse(count);

    Widget iconBadge = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: active
            ? accent.withValues(alpha: isDark ? 0.22 : 0.14)
            : (isDark
                  ? DSColors.secondarySurfaceDark
                  : DSColors.secondarySurfaceLight),
        borderRadius: BorderRadius.circular(DSStyles.radiusLG),
      ),
      child: Icon(
        icon,
        size: DSIconSize.md,
        color: active
            ? accent
            : (isDark ? DSColors.labelTertiaryDark : DSColors.labelTertiary),
      ),
    );

    // Soft pulse on active work tiles (respect reduced motion).
    if (active && !reduceMotion) {
      iconBadge = iconBadge
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.07, 1.07),
            duration: DSAnimations.dHeroX2,
            curve: Curves.easeInOut,
          );
    }

    Widget? openChip;
    if (active) {
      openChip = Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DSSpacing.sm,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: DSColors.primary.withValues(alpha: isDark ? 0.2 : 0.12),
          borderRadius: DSStyles.fullRadius,
        ),
        child: Text(
          'OPEN',
          style:
              DSTypography.label(
                color: isDark ? DSColors.primaryDark : DSColors.primary,
              ).copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
        ),
      );
      if (!reduceMotion) {
        openChip = openChip
            .animate()
            .fadeIn(duration: DSAnimations.dFast)
            .scale(
              begin: const Offset(0.6, 0.6),
              end: const Offset(1, 1),
              duration: DSAnimations.dNormal,
              curve: Curves.easeOutBack,
            );
      }
    }

    final countStyle = DSTypography.display(color: countColor).copyWith(
      height: 1.0,
      fontWeight: FontWeight.w800,
      fontSize: 26,
      letterSpacing: -0.5,
    );

    Widget countWidget;
    if (countValue != null && !reduceMotion) {
      countWidget = TweenAnimationBuilder<double>(
        key: ValueKey(countValue),
        tween: Tween(begin: 0, end: countValue.toDouble()),
        duration: DSAnimations.dNormal,
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return Text(
            '${value.round()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: countStyle,
          );
        },
      );
    } else {
      countWidget = Text(
        count,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: countStyle,
      );
    }
    if (!reduceMotion) {
      countWidget = countWidget
          .animate()
          .fadeIn(duration: DSAnimations.dFast)
          .slideY(
            begin: 0.25,
            end: 0,
            duration: DSAnimations.dNormal,
            curve: Curves.easeOutCubic,
          );
    }

    // Fixed footprint from parent SizedBox — never let Column exceed it.
    // Top: icon row. Bottom: count + label (+ hold hint). Spacer absorbs slack.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DSSpacing.md + 4,
        DSSpacing.sm + 4, // 12 — was 16; holds hint without 3px overflow
        DSSpacing.md,
        DSSpacing.sm + 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              iconBadge,
              const Spacer(),
              if (openChip != null)
                openChip
              else if (showHoldHint)
                Icon(
                      Icons.touch_app_outlined,
                      size: 14,
                      color: hintColor.withValues(alpha: 0.7),
                    )
                    .animate(
                      onPlay: reduceMotion
                          ? null
                          : (c) => c.repeat(reverse: true),
                    )
                    .fade(
                      begin: 0.45,
                      end: 1,
                      duration: DSAnimations.dHero,
                      curve: Curves.easeInOut,
                    ),
            ],
          ),
          const Spacer(),
          countWidget,
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DSTypography.label(color: labelColor).copyWith(
              fontWeight: FontWeight.w700,
              fontSize: DSTypography.sizeSm,
              height: 1.1,
            ),
          ),
          if (showHoldHint) ...[
            const SizedBox(height: 2),
            Text(
              'dashboard.stats.hold_hint'.tr(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DSTypography.caption(color: hintColor).copyWith(
                height: 1.1,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Reverse face — stays open after hold until the close control is tapped.
class _StatCardReverse extends StatelessWidget {
  const _StatCardReverse({
    required this.icon,
    required this.count,
    required this.label,
    required this.details,
    required this.accent,
    required this.isDark,
    required this.labelColor,
    required this.countColor,
    required this.detailsColor,
    required this.hintColor,
    required this.canOpen,
  });

  final IconData icon;
  final String count;
  final String label;
  final String details;
  final Color accent;
  final bool isDark;
  final Color labelColor;
  final Color countColor;
  final Color detailsColor;
  final Color hintColor;
  final bool canOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DSSpacing.md + 4,
        DSSpacing.md,
        // Room for the floating close control (top-right).
        DSSpacing.md + 28,
        DSSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.28 : 0.16),
                  borderRadius: BorderRadius.circular(DSStyles.radiusMD),
                ),
                child: Icon(icon, size: DSIconSize.sm, color: accent),
              ),
              DSSpacing.wSm,
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DSTypography.label(color: accent).copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.9,
                  ),
                ),
              ),
              Text(
                count,
                style: DSTypography.label(color: countColor).copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: DSTypography.sizeLg,
                ),
              ),
            ],
          ),
          DSSpacing.hSm,
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                details,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: DSTypography.body(color: detailsColor).copyWith(
                  height: 1.25,
                  fontSize: DSTypography.sizeSm,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Text(
            canOpen
                ? 'dashboard.stats.hold_open_hint'.tr()
                : 'dashboard.stats.hold_close_hint'.tr(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DSTypography.caption(color: hintColor).copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Solid scan CTA — brand primary or gold only (not status rainbow).
///
/// Keeps a **fixed-height** box (same footprint as the original quick-scan
/// tiles). When [details] is set: hold reveals an overlay *inside* that box
/// (stays open until X); tap the rest of the tile to run [onTap].
class ScanButton extends StatefulWidget {
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
  State<ScanButton> createState() => _ScanButtonState();
}

class _ScanButtonState extends State<ScanButton> with TickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final AnimationController _revealCtrl;
  late final Animation<double> _pressScale;
  late final Animation<double> _reveal;

  bool _revealed = false;

  bool get _canReveal =>
      widget.details != null && widget.details!.trim().isNotEmpty;

  double get _boxHeight => widget.minHeight ?? DSStyles.scanButtonHeight - 10;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: DSAnimations.dMicro,
    );
    _pressScale = Tween<double>(
      begin: 1.0,
      end: DSAnimations.scalePressed,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));

    _revealCtrl = AnimationController(
      vsync: this,
      duration: DSAnimations.dFast,
    );
    _reveal = CurvedAnimation(
      parent: _revealCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    _revealCtrl.dispose();
    super.dispose();
  }

  void _showDetails() {
    if (!_canReveal || _revealed) return;
    setState(() => _revealed = true);
    _pressCtrl.reverse();
    _revealCtrl.forward();
    HapticFeedback.mediumImpact();
  }

  void _hideDetails() {
    if (!_revealed) return;
    setState(() => _revealed = false);
    _revealCtrl.reverse();
    HapticFeedback.selectionClick();
  }

  void _onTap() {
    HapticFeedback.mediumImpact();
    widget.onTap();
  }

  void _onLongPress() {
    if (!_canReveal || _revealed) return;
    _showDetails();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillTop = widget.color;
    final fillBottom =
        Color.lerp(widget.color, DSColors.black, isDark ? 0.18 : 0.10) ??
        widget.color;
    final h = _boxHeight;

    return AnimatedBuilder(
      animation: Listenable.merge([_pressScale, _reveal]),
      builder: (context, _) {
        final reveal = _reveal.value;
        final scale = _pressScale.value;

        // Fixed footprint — face and reverse always share this box.
        final tile = SizedBox(
          width: double.infinity,
          height: h,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [fillTop, fillBottom],
              ),
              borderRadius: BorderRadius.circular(DSStyles.radius2XL),
              border: reveal > 0.01
                  ? Border.all(
                      color: DSColors.white.withValues(alpha: 0.22 * reveal),
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: isDark ? 0.35 : 0.22),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(DSStyles.radius2XL),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Face: centered CTA — denser padding so fixed height never
                  // overflows (128h − padding left only ~80–96 for content).
                  Opacity(
                    opacity: (1.0 - reveal).clamp(0.0, 1.0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: DSSpacing.md,
                        horizontal: DSSpacing.md,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Builder(
                              builder: (context) {
                                final reduce = MediaQuery.disableAnimationsOf(
                                  context,
                                );
                                Widget badge = Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: DSColors.white.withValues(
                                      alpha: 0.18,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      DSStyles.radiusXL,
                                    ),
                                  ),
                                  child: Icon(
                                    widget.icon,
                                    color: DSColors.white,
                                    size: DSIconSize.lg,
                                  ),
                                );
                                if (!reduce && reveal < 0.5) {
                                  badge = badge
                                      .animate(
                                        onPlay: (c) => c.repeat(reverse: true),
                                      )
                                      .scale(
                                        begin: const Offset(1, 1),
                                        end: const Offset(1.06, 1.06),
                                        duration: DSAnimations.dHeroX2,
                                        curve: Curves.easeInOut,
                                      );
                                }
                                return badge;
                              },
                            ),
                            DSSpacing.hSm,
                            Text(
                              widget.label,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: DSTypography.label(color: DSColors.white)
                                  .copyWith(
                                    fontSize: DSTypography.sizeSm,
                                    letterSpacing: DSTypography.lsWide,
                                    fontWeight: FontWeight.w800,
                                    height: 1.15,
                                  ),
                            ),
                            if (_canReveal) ...[
                              const SizedBox(height: 2),
                              Text(
                                'dashboard.stats.hold_hint'.tr(),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    DSTypography.caption(
                                      color: DSColors.white.withValues(
                                        alpha: 0.75,
                                      ),
                                    ).copyWith(
                                      height: 1.0,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Reverse: details overlay inside the same fixed box
                  if (_canReveal)
                    Opacity(
                      opacity: reveal.clamp(0.0, 1.0),
                      child: IgnorePointer(
                        ignoring: reveal < 0.5,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            DSSpacing.md,
                            DSSpacing.md,
                            DSSpacing.md + 28,
                            DSSpacing.md,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: DSColors.white.withValues(
                                        alpha: 0.18,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        DSStyles.radiusLG,
                                      ),
                                    ),
                                    child: Icon(
                                      widget.icon,
                                      color: DSColors.white,
                                      size: DSIconSize.md,
                                    ),
                                  ),
                                  DSSpacing.wSm,
                                  Expanded(
                                    child: Text(
                                      widget.label,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          DSTypography.label(
                                            color: DSColors.white,
                                          ).copyWith(
                                            fontWeight: FontWeight.w800,
                                            fontSize: DSTypography.sizeSm,
                                            letterSpacing: 0.4,
                                            height: 1.15,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              DSSpacing.hSm,
                              Expanded(
                                child: Text(
                                  widget.details!,
                                  maxLines: 5,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      DSTypography.body(
                                        color: DSColors.white.withValues(
                                          alpha: 0.95,
                                        ),
                                      ).copyWith(
                                        height: 1.3,
                                        fontSize: DSTypography.sizeSm,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ),
                              Text(
                                'dashboard.stats.hold_open_hint'.tr(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    DSTypography.caption(
                                      color: DSColors.white.withValues(
                                        alpha: 0.78,
                                      ),
                                    ).copyWith(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );

        return Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          child: SizedBox(
            width: double.infinity,
            height: h,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTapDown: (_) => _pressCtrl.forward(),
                    onTapUp: (_) => _pressCtrl.reverse(),
                    onTapCancel: () => _pressCtrl.reverse(),
                    onTap: _onTap,
                    onLongPress: _canReveal ? _onLongPress : null,
                    behavior: HitTestBehavior.opaque,
                    child: tile,
                  ),
                ),
                if (_canReveal && _revealed)
                  Positioned(
                    top: DSSpacing.sm,
                    right: DSSpacing.sm,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _hideDetails,
                      child: Tooltip(
                        message: 'dashboard.stats.hold_close_hint'.tr(),
                        child: Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: DSColors.white.withValues(alpha: 0.22),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: DSColors.white.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: DSIconSize.sm,
                            color: DSColors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
