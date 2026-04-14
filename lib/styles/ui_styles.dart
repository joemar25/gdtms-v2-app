// DOCS: docs/styles.md — update that file when you edit this one.

import 'package:flutter/material.dart';

/// Global UI Design System Tokens
///
/// Replaces arbitrary hardcoded constraints across the app with consistent
/// logical tokens. Unifies border radiuses, soft opacities, and spacing.
class UIStyles {
  // ── Border Radii ──────────────────────────────────────────────────────────

  /// Primary containers (Cards, Modals, Bottom Sheets, Search Bars)
  static const double radiusCard = 16.0;
  static final BorderRadius cardRadius = BorderRadius.circular(radiusCard);

  /// Secondary containers (Inner Pills, Tags, Badges)
  static const double radiusPill = 8.0;
  static final BorderRadius pillRadius = BorderRadius.circular(radiusPill);

  /// Circular forms (Floating Nav)
  static const double radiusCircular = 24.0;
  static final BorderRadius circularRadius = BorderRadius.circular(
    radiusCircular,
  );

  // ── Opacities / Alpha (Glassmorphism & Shadows) ───────────────────────────

  /// The standard incredibly soft shadow / background fill alpha
  static const double alphaSoft = 0.05;

  /// Background tone for active or highlighted UI tiles
  static const double alphaActiveAccent = 0.12;

  /// Strong borders or outlines
  static const double alphaBorder = 0.20;

  /// Base multiplier for dark mode shadow presence (stronger shadows in dark mode)
  static const double alphaDarkShadow = 0.35;

  /// Base multiplier for light mode shadow presence (softer shadows in light mode)
  static const double alphaLightShadow = 0.04;

  /// Base for glassmorphism panels (Nav bar)
  static const double alphaGlass = 0.70;
}
