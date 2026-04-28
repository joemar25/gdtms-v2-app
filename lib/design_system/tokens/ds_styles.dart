import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_colors.dart';

/// Design-system shape and opacity tokens.
///
/// STABILITY RULE: Only 3 to 5 standard tiers allowed per category.
/// REJECT any new tier requests that exceed this scale.
class DSStyles {
  // ── Border Radii ──────────────────────────────────────────────────────────
  static const double radiusXS = 4.0;
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0; 
  static const double radiusXL = 24.0;

  static const double radiusSheet = radiusXL;
  static final BorderRadius sheetRadius = BorderRadius.circular(radiusSheet);

  static const double radiusCard = radiusLG;
  static final BorderRadius cardRadius = BorderRadius.circular(radiusCard);

  static const double radiusPill = radiusSM;
  static final BorderRadius pillRadius = BorderRadius.circular(radiusPill);

  static const double radiusBadge = radiusMD;
  static final BorderRadius badgeRadius = BorderRadius.circular(radiusBadge);

  static const double radiusCircular = radiusXL;
  static final BorderRadius circularRadius = BorderRadius.circular(radiusCircular);

  static const double radiusFull = 999.0;
  static final BorderRadius fullRadius = BorderRadius.circular(radiusFull);

  static const double shadowBlurHero = 40.0;
  static const Offset shadowOffsetHero = Offset(0, 16);

  // ── Opacities / Alpha ─────────────────────────────────────────────────────
  static const double alphaSoft = 0.05;
  static const double alphaSubtle = 0.12;
  static const double alphaMuted = 0.25;
  static const double alphaDisabled = 0.54;
  static const double alphaOpaque = 0.90;
  static const double alphaTransparent = 0.0;

  // ── Borders & Strokes ─────────────────────────────────────────────────────
  static const double borderWidth = 1.0;
  static const double strokeWidth = 2.0;

  // ── Text Heights ──────────────────────────────────────────────────────────
  static const double heightTight = 1.1;
  static const double heightNormal = 1.4;
  static const double heightRelaxed = 1.6;

  // ── Elevations ────────────────────────────────────────────────────────────
  static const double elevationNone = 0.0;
  static const double elevationXS = 2.0;
  static const double elevationSM = 4.0;
  static const double elevationMD = 8.0;
  static const double elevationLG = 12.0;

  // ── Shadows ───────────────────────────────────────────────────────────────
  static List<BoxShadow> shadowXS(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: (isDark ? DSColors.black : DSColors.primary).withValues(
          alpha: isDark ? alphaMuted : alphaSoft,
        ),
        blurRadius: radiusSM,
        offset: const Offset(0, radiusXS),
      ),
    ];
  }

  static List<BoxShadow> shadowSM(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: (isDark ? DSColors.black : DSColors.primary).withValues(
          alpha: isDark ? alphaMuted : alphaSoft,
        ),
        blurRadius: radiusMD,
        offset: const Offset(0, radiusXS),
      ),
    ];
  }

  static List<BoxShadow> shadowMD(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: (isDark ? DSColors.black : DSColors.primary).withValues(
          alpha: isDark ? alphaMuted : alphaSubtle,
        ),
        blurRadius: radiusLG,
        offset: const Offset(0, radiusSM),
      ),
    ];
  }

  static List<BoxShadow> shadowLG(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: (isDark ? DSColors.black : DSColors.primary).withValues(
          alpha: isDark ? alphaDisabled : alphaMuted,
        ),
        blurRadius: radiusXL,
        offset: const Offset(0, radiusMD),
      ),
    ];
  }

  static List<BoxShadow> shadowXL(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: (isDark ? DSColors.black : DSColors.primary).withValues(
          alpha: isDark ? alphaOpaque : alphaMuted,
        ),
        blurRadius: shadowBlurHero,
        offset: shadowOffsetHero,
      ),
    ];
  }
}
