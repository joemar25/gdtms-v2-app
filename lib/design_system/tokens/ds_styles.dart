import 'package:flutter/material.dart';

/// Design-system shape and opacity tokens.
///
/// Replaces the old `UIStyles` class. Single source of truth for border
/// radii and alpha/opacity constants.
class DSStyles {
  // ── Border Radii ──────────────────────────────────────────────────────────
  static const double radiusCard = 16.0;
  static final BorderRadius cardRadius = BorderRadius.circular(radiusCard);

  static const double radiusPill = 8.0;
  static final BorderRadius pillRadius = BorderRadius.circular(radiusPill);

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
}
