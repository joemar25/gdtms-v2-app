// DOCS: docs/development-standards.md
// DOCS: docs/styles.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fsi_courier_app/design_system/design_system.dart';

/// A single option in a [DSSegmentedSelector].
class DSSegmentOption<T> {
  const DSSegmentOption({
    required this.value,
    required this.label,
    this.icon,
    required this.color,
    this.badge,
  });

  final T value;
  final String label;
  final IconData? icon;

  /// Sliding pill fill when this option is active.
  final Color color;

  /// Optional count badge next to the label.
  final int? badge;
}

/// Icon/label arrangement inside each segment.
enum DSSegmentLayout {
  /// Icon above label (taller tracks, default standalone).
  vertical,

  /// Icon beside label (chrome strips — comfortable at height 48).
  horizontal,
}

/// Segmented control with elastic sliding pill.
///
/// Features stay decoupled. Chrome strips use
/// [DsIntegratedSubHeader.segment] for shared colors + layout.
class DSSegmentedSelector<T> extends StatelessWidget {
  const DSSegmentedSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.selectedTextColor,
    this.unselectedTextColor,
    this.backgroundColor,
    this.showBorder = true,
    this.height = 72.0,
    this.layout = DSSegmentLayout.vertical,
    this.pillInset,
  }) : assert(options.length >= 2, 'Need at least 2 options');

  final List<DSSegmentOption<T>> options;
  final T selected;
  final void Function(T value) onChanged;
  final Color? selectedTextColor;
  final Color? unselectedTextColor;
  final Color? backgroundColor;
  final bool showBorder;
  final double height;
  final DSSegmentLayout layout;

  /// Padding between track edge and sliding pill. Default scales with height.
  final double? pillInset;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final n = options.length;
    final selectedIndex = options.indexWhere((o) => o.value == selected);
    final idx = selectedIndex >= 0 ? selectedIndex : 0;
    final activeOption = options[idx];
    final horizontal = layout == DSSegmentLayout.horizontal;

    final alignX = n > 1 ? (-1.0 + 2.0 * idx / (n - 1)) : 0.0;

    final inset = pillInset ?? (horizontal ? 4.0 : DSSpacing.sm);
    final trackRadius = BorderRadius.circular(
      horizontal ? DSStyles.radiusLG : DSStyles.radiusXL,
    );
    // Pill radius slightly smaller than track so it sits inside cleanly.
    final pillRadius = BorderRadius.circular(
      horizontal ? DSStyles.radiusMD : DSStyles.radiusLG,
    );

    final trackBg =
        backgroundColor ??
        (isDark
            ? DSColors.white.withValues(alpha: DSStyles.alphaSubtle)
            : DSColors.secondarySurfaceLight);

    // Prefer exact brand greens from callers; default white for gradient pills.
    final selectedFg = selectedTextColor ?? DSColors.white;
    final unselectedFg =
        unselectedTextColor ??
        (isDark
            ? DSColors.white.withValues(alpha: DSStyles.alphaDisabled)
            : DSColors.labelSecondary);

    final isWhitePill = activeOption.color == DSColors.white;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: trackBg,
        borderRadius: trackRadius,
        border: Border.all(
          color: showBorder
              ? (isDark
                    ? DSColors.white.withValues(alpha: DSStyles.alphaSubtle)
                    : DSColors.separatorLight)
              : DSColors.white.withValues(alpha: 0.22),
          width: DSStyles.borderWidth,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Sliding pill ────────────────────────────────────────────────
          AnimatedAlign(
            alignment: Alignment(alignX, 0),
            duration: DSAnimations.dNormal,
            curve: DSAnimations.curveElasticPill,
            child: FractionallySizedBox(
              widthFactor: 1.0 / n,
              heightFactor: 1.0,
              child: Padding(
                padding: EdgeInsets.all(inset),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isWhitePill ? DSColors.white : null,
                    gradient: isWhitePill
                        ? null
                        : LinearGradient(
                            colors: [
                              activeOption.color,
                              activeOption.color.withValues(
                                alpha: DSStyles.alphaOpaque,
                              ),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    borderRadius: pillRadius,
                    boxShadow: [
                      BoxShadow(
                        color:
                            (isWhitePill ? DSColors.black : activeOption.color)
                                .withValues(alpha: isWhitePill ? 0.12 : 0.28),
                        blurRadius: horizontal ? 4 : 8,
                        offset: Offset(0, horizontal ? 1 : 3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Options ─────────────────────────────────────────────────────
          Row(
            children: [
              for (final opt in options)
                Expanded(
                  child: _SegmentCell(
                    option: opt,
                    selected: opt.value == selected,
                    selectedFg: selectedFg,
                    unselectedFg: unselectedFg,
                    horizontal: horizontal,
                    trackRadius: trackRadius,
                    onTap: () {
                      if (opt.value == selected) return;
                      HapticFeedback.selectionClick();
                      onChanged(opt.value);
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentCell<T> extends StatelessWidget {
  const _SegmentCell({
    required this.option,
    required this.selected,
    required this.selectedFg,
    required this.unselectedFg,
    required this.horizontal,
    required this.trackRadius,
    required this.onTap,
  });

  final DSSegmentOption<T> option;
  final bool selected;
  final Color selectedFg;
  final Color unselectedFg;
  final bool horizontal;
  final BorderRadius trackRadius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? selectedFg : unselectedFg;
    final iconSize = horizontal
        ? DSIconSize.md
        : (selected ? DSIconSize.lg : DSIconSize.md);
    final labelSize = horizontal
        ? (selected ? 12.0 : 11.0)
        : (selected ? 11.0 : 10.0);

    final label = Text(
      option.label,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: DSTypography.label().copyWith(
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        fontSize: labelSize,
        height: 1.0,
        color: fg,
        letterSpacing: selected
            ? DSTypography.lsSlightlyTight
            : DSTypography.lsLoose,
      ),
    );

    final badge = (option.badge ?? 0) > 0
        ? Padding(
            padding: const EdgeInsets.only(left: 4),
            child: _SegmentBadge(
              count: option.badge!,
              selected: selected,
              selectedFg: selectedFg,
              unselectedFg: unselectedFg,
              compact: horizontal,
            ),
          )
        : null;

    final icon = option.icon != null
        ? Icon(option.icon, color: fg, size: iconSize)
        : null;

    final Widget content;
    if (horizontal) {
      // Icon | label | badge — sits cleanly in height 48 with 4px pill pad.
      content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[icon, const SizedBox(width: 6)],
            Flexible(child: label),
            ?badge,
          ],
        ),
      );
    } else {
      content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: DSSpacing.xs),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[icon, const SizedBox(height: 4)],
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: label),
                ?badge,
              ],
            ),
          ],
        ),
      );
    }

    return Material(
      color: DSColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: trackRadius,
        splashColor: selectedFg.withValues(alpha: 0.10),
        highlightColor: selectedFg.withValues(alpha: 0.05),
        child: SizedBox.expand(child: Center(child: content)),
      ),
    );
  }
}

class _SegmentBadge extends StatelessWidget {
  const _SegmentBadge({
    required this.count,
    required this.selected,
    required this.selectedFg,
    required this.unselectedFg,
    required this.compact,
  });

  final int count;
  final bool selected;
  final Color selectedFg;
  final Color unselectedFg;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    final bg = selected
        ? selectedFg.withValues(alpha: 0.14)
        : DSColors.white.withValues(alpha: 0.22);
    final fg = selected ? selectedFg : unselectedFg;
    final h = compact ? 16.0 : 18.0;

    return Container(
      constraints: BoxConstraints(minWidth: h),
      height: h,
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: DSStyles.fullRadius),
      child: Text(
        label,
        style: DSTypography.label().copyWith(
          fontSize: compact ? 10 : DSTypography.sizeXs,
          fontWeight: FontWeight.w800,
          height: 1.0,
          color: fg,
        ),
      ),
    );
  }
}
