// DOCS: docs/development-standards.md
// DOCS: docs/design-system.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/shared/widgets/ds_segmented_selector.dart';

/// **Header extension** foot under [AppHeaderBar] — same brand green paint.
///
/// Pair with `AppHeaderBar(showBottomBorder: false)`.
/// Features stay **decoupled**: own options/callbacks; share look via [segment].
class DsIntegratedSubHeader extends StatelessWidget {
  const DsIntegratedSubHeader({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// Outer inset of the strip around the segment track.
  static const EdgeInsets contentPadding = EdgeInsets.fromLTRB(
    DSSpacing.md,
    DSSpacing.sm,
    DSSpacing.md,
    DSSpacing.md,
  );

  /// Track height — horizontal icon+label (not a tall vertical stack).
  static const double segmentHeight = 48;

  /// White sliding pill.
  static const Color segmentPill = DSColors.white;

  /// Frosted track on solid primary strip.
  static Color segmentTrack(BuildContext context) =>
      DSColors.white.withValues(alpha: 0.20);

  /// Selected glyphs on white pill — **exact** brand green (not seed primary).
  static Color segmentSelectedText(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? DSColors.primaryDark : DSColors.primary;
  }

  /// Unselected glyphs on green chrome.
  static Color segmentUnselectedText(BuildContext context) =>
      DSColors.white.withValues(alpha: 0.90);

  /// Pre-styled chrome [DSSegmentedSelector]. Features only pass options.
  static Widget segment<T>({
    required BuildContext context,
    required List<DSSegmentOption<T>> options,
    required T selected,
    required void Function(T value) onChanged,
  }) {
    final brand = segmentSelectedText(context);
    return DSSegmentedSelector<T>(
      height: segmentHeight,
      selected: selected,
      selectedTextColor: brand,
      unselectedTextColor: segmentUnselectedText(context),
      backgroundColor: segmentTrack(context),
      showBorder: false,
      // Chrome: horizontal icon+label, tight inner pad.
      layout: DSSegmentLayout.horizontal,
      pillInset: 4,
      onChanged: onChanged,
      options: [
        for (final o in options)
          DSSegmentOption(
            value: o.value,
            label: o.label,
            icon: o.icon,
            color: segmentPill,
            badge: o.badge,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brand = isDark ? DSColors.primaryDark : DSColors.primary;
    final radius = BorderRadius.only(
      bottomLeft: Radius.circular(DSStyles.radiusXL),
      bottomRight: Radius.circular(DSStyles.radiusXL),
    );

    // Solid brand paint only — no extra glass/frost that drifts the green.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: brand,
        borderRadius: radius,
        boxShadow: DSGlass.headerShadow(context),
      ),
      child: Padding(padding: padding ?? contentPadding, child: child),
    );
  }
}
