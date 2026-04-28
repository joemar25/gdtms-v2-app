// DOCS: docs/development-standards.md
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

  /// Accent color for the gradient pill when this option is active.
  final Color color;

  /// Optional count shown as a small badge next to the label.
  final int? badge;
}

/// A segmented selector with an elastic sliding pill indicator.
///
/// Mirrors the animation used in [DeliveryUpdateScreen]'s status selector
/// (AnimatedAlign + Curves.elasticOut pill, AnimatedScale icon pop).
/// Works for 2–5 equally-weighted options.
class DSSegmentedSelector<T> extends StatelessWidget {
  const DSSegmentedSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.height = 72.0,
  }) : assert(options.length >= 2, 'Need at least 2 options');

  final List<DSSegmentOption<T>> options;
  final T selected;
  final void Function(T value) onChanged;

  /// Container height. Use ~72 when icons are present, ~56 for label-only.
  final double height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final n = options.length;
    final selectedIndex = options.indexWhere((o) => o.value == selected);
    final idx = selectedIndex >= 0 ? selectedIndex : 0;
    final activeOption = options[idx];

    // Maps idx 0 → -1.0 (left), n-1 → +1.0 (right).
    final alignX = n > 1 ? (-1.0 + 2.0 * idx / (n - 1)) : 0.0;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isDark
            ? DSColors.white.withValues(alpha: DSStyles.alphaSubtle)
            : DSColors.secondarySurfaceLight,
        borderRadius: DSStyles.cardRadius,
        border: Border.all(
          color: isDark
              ? DSColors.white.withValues(alpha: DSStyles.alphaSubtle)
              : DSColors.separatorLight,
        ),
      ),
      child: Stack(
        children: [
          // ── Elastic sliding pill ──────────────────────────────────────────
          AnimatedAlign(
            alignment: Alignment(alignX, 0),
            duration: DSAnimations.dNormal,
            curve: DSAnimations.curveElasticPill,
            child: FractionallySizedBox(
              widthFactor: 1.0 / n,
              heightFactor: 1.0,
              child: Padding(
                padding: EdgeInsets.all(DSSpacing.sm),
                child: AnimatedContainer(
                  duration: DSAnimations.dFast,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        activeOption.color,
                        activeOption.color.withValues(
                          alpha: DSStyles.alphaOpaque,
                        ),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: DSStyles.cardRadius,
                    boxShadow: [
                      BoxShadow(
                        color: activeOption.color.withValues(
                          alpha: DSStyles.alphaMuted,
                        ),
                        blurRadius: DSStyles.radiusMD,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Option labels / icons ─────────────────────────────────────────
          Row(
            children: options.map((opt) {
              final isSelected = opt.value == selected;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (isSelected) return;
                    HapticFeedback.selectionClick();
                    onChanged(opt.value);
                  },
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (opt.icon != null) ...[
                          AnimatedScale(
                            scale: isSelected ? 1.15 : 1.0,
                            duration: DSAnimations.dFast,
                            curve: DSAnimations.curveIconPop,
                            child: Icon(
                              opt.icon,
                              color: isSelected
                                  ? DSColors.white
                                  : (isDark
                                        ? DSColors.white.withValues(
                                            alpha: DSStyles.alphaDisabled,
                                          )
                                        : DSColors.labelSecondary),
                              size: isSelected ? DSIconSize.lg : DSIconSize.md,
                            ),
                          ),
                          DSSpacing.hXs,
                        ],
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedDefaultTextStyle(
                              duration: DSAnimations.dFast,
                              style: DSTypography.label().copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                fontSize: isSelected ? 11.0 : 10.0,
                                color: isSelected
                                    ? DSColors.white
                                    : (isDark
                                          ? DSColors.labelSecondaryDark
                                          : DSColors.labelSecondary),
                                letterSpacing: DSTypography.lsLoose,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  opt.label,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            if ((opt.badge ?? 0) > 0) ...[
                              DSSpacing.wXs,
                              AnimatedContainer(
                                duration: DSAnimations.dFast,
                                padding: EdgeInsets.symmetric(
                                  horizontal: DSSpacing.xs,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? DSColors.white.withValues(
                                          alpha: DSStyles.alphaMuted,
                                        )
                                      : (isDark
                                            ? DSColors.white.withValues(
                                                alpha: DSStyles.alphaSubtle,
                                              )
                                            : DSColors.separatorLight),
                                  borderRadius: DSStyles.pillRadius,
                                ),
                                child: Text(
                                  '${opt.badge}',
                                  style: DSTypography.label().copyWith(
                                    fontSize: DSTypography.sizeXs,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? DSColors.white
                                        : (isDark
                                              ? DSColors.labelSecondaryDark
                                              : DSColors.labelSecondary),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
