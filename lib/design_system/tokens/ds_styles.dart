import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_colors.dart';

/// Design-system shape and opacity tokens.
///
/// Replaces the old `UIStyles` class. Single source of truth for border
/// radii and alpha/opacity constants.
class DSStyles {
  // ── Border Radii ──────────────────────────────────────────────────────────
  static const double radiusXS = 4.0;
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0; // Legacy radiusCard
  static const double radiusXL = 20.0;
  static const double radiusXXL = 28.0; // Legacy radiusSheet

  static const double radiusSheet = radiusXXL;
  static final BorderRadius sheetRadius = BorderRadius.circular(radiusSheet);

  static const double radiusCard = radiusLG;
  static final BorderRadius cardRadius = BorderRadius.circular(radiusCard);

  static const double radiusPill = radiusSM;
  static final BorderRadius pillRadius = BorderRadius.circular(radiusPill);

  static const double radiusBadge = 10.0;
  static final BorderRadius badgeRadius = BorderRadius.circular(radiusBadge);

  static const double radiusCircular = 24.0;
  static final BorderRadius circularRadius = BorderRadius.circular(
    radiusCircular,
  );

  // ── Opacities / Alpha ─────────────────────────────────────────────────────
  static const double alphaSoft = 0.05;
  static const double alphaActiveAccent = 0.12;
  static const double alphaBorder = 0.20;
  static const double alphaDarkShadow = 0.35;
  static const double alphaLightShadow = 0.04;
  static const double alphaGlass = 0.70;

  // ── Shadows ───────────────────────────────────────────────────────────────
  static List<BoxShadow> shadowSoft(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: (isDark ? DSColors.black : DSColors.primary).withValues(
          alpha: isDark ? 0.4 : 0.06,
        ),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ];
  }

  static List<BoxShadow> shadowHeavy(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: (isDark ? DSColors.black : DSColors.primary).withValues(
          alpha: isDark ? 0.4 : 0.12,
        ),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
    ];
  }
}
