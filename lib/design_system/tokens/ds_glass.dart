// DOCS: docs/development-standards.md
// DOCS: docs/styles.md — update that file when you edit this one.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_colors.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_spacing.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_styles.dart';

/// Shared frosted-glass surface language.
///
/// Tone:
/// - [DSGlassTone.chrome] — **primary-tinted** header / bottom nav (brand base)
/// - [DSGlassTone.card] — neutral elevated panels / form cards
///
/// Chrome is **mode-aware**: light needs denser green (pale scaffolds wash it
/// out); dark stays thinner so glass reads over dark content. Prefer [DSGlass]
/// over raw colors/alphas.
class DSGlass {
  DSGlass._();

  /// Header / bottom-nav height (72).
  static const double chromeHeight = DSSpacing.huge + DSSpacing.sm;

  /// Light chrome: denser primary — pale scaffolds wash green out; white
  /// glyphs need solid brand behind them. Still < 1.0 so blur can frost.
  static const double chromeAlphaLight = 0.88;

  /// Dark chrome: thinner frosted brand over dark UI / scenery.
  static const double chromeAlphaDark = 0.50;

  /// Blur: light slightly softer (fill is denser); dark stronger frost.
  static double blurSigmaFor(BuildContext context) => _isDark(context)
      ? DSSpacing.xl - DSSpacing.xs
      : DSSpacing.md + DSSpacing.sm;

  /// Default blur when no context (cards / chips).
  static const double blurSigma = DSSpacing.lg;

  static ImageFilter get filter =>
      ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma);

  /// Mode-aware blur for header / nav chrome.
  static ImageFilter filterFor(BuildContext context) {
    final s = blurSigmaFor(context);
    return ImageFilter.blur(sigmaX: s, sigmaY: s);
  }

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // ── Fills ────────────────────────────────────────────────────────────────

  /// Chrome = frosted **primary** (brand). Card = neutral elevated surface.
  static Color fill(
    BuildContext context, {
    DSGlassTone tone = DSGlassTone.chrome,
  }) {
    final isDark = _isDark(context);
    switch (tone) {
      case DSGlassTone.chrome:
        // Brand green glass — density flips by theme (see alphas above).
        final base = isDark ? DSColors.primaryDark : DSColors.primary;
        return base.withValues(
          alpha: isDark ? chromeAlphaDark : chromeAlphaLight,
        );
      case DSGlassTone.card:
        return isDark
            ? DSColors.cardElevatedDark.withValues(alpha: DSStyles.alphaOpaque)
            : DSColors.white.withValues(alpha: DSStyles.alphaOpaque);
    }
  }

  // ── Border ───────────────────────────────────────────────────────────────

  static Color border(
    BuildContext context, {
    DSGlassTone tone = DSGlassTone.chrome,
  }) {
    final isDark = _isDark(context);
    switch (tone) {
      case DSGlassTone.chrome:
        // Light: stronger white edge so bar separates from pale scaffold.
        // Dark: subtle rim on green glass.
        return DSColors.white.withValues(
          alpha: isDark ? DSStyles.alphaSubtle : DSStyles.alphaMuted,
        );
      case DSGlassTone.card:
        return isDark
            ? DSColors.white.withValues(alpha: DSStyles.alphaSubtle)
            : DSColors.primary.withValues(alpha: DSStyles.alphaSubtle);
    }
  }

  static BorderSide borderSide(
    BuildContext context, {
    DSGlassTone tone = DSGlassTone.chrome,
  }) => BorderSide(
    color: border(context, tone: tone),
    width: DSStyles.borderWidth,
  );

  // ── Foreground on chrome (primary glass → white glyphs) ──────────────────

  /// Primary text / icons on primary glass chrome.
  static Color onChrome(BuildContext context) => DSColors.white;

  /// Secondary text on primary glass (greeting).
  static Color onChromeMuted(BuildContext context) =>
      DSColors.white.withValues(alpha: _isDark(context) ? 0.75 : 0.90);

  /// Inactive nav items on primary glass.
  static Color onChromeInactive(BuildContext context) =>
      DSColors.white.withValues(alpha: _isDark(context) ? 0.68 : 0.82);

  // ── Foreground on neutral card glass ─────────────────────────────────────

  static Color onSurface(BuildContext context) {
    return _isDark(context) ? DSColors.labelPrimaryDark : DSColors.labelPrimary;
  }

  static Color onSurfaceMuted(BuildContext context) {
    return _isDark(context)
        ? DSColors.labelSecondaryDark
        : DSColors.labelSecondary;
  }

  // ── Shadows ──────────────────────────────────────────────────────────────

  static List<BoxShadow> shadow(
    BuildContext context, {
    DSGlassTone tone = DSGlassTone.chrome,
  }) {
    final isDark = _isDark(context);
    if (tone == DSGlassTone.card) {
      return [
        BoxShadow(
          color: DSColors.primary.withValues(
            alpha: isDark ? DSStyles.alphaMuted : DSStyles.alphaSubtle,
          ),
          blurRadius: DSSpacing.lg + DSSpacing.xs,
          offset: const Offset(0, DSStyles.elevationLG),
        ),
        BoxShadow(
          color: DSColors.black.withValues(
            alpha: isDark ? DSStyles.alphaMuted : DSStyles.alphaSoft,
          ),
          blurRadius: DSSpacing.md,
          offset: const Offset(0, DSSpacing.sm),
        ),
      ];
    }
    // Primary chrome — stronger lift in light so bar floats on white scaffold.
    return [
      BoxShadow(
        color: DSColors.primary.withValues(
          alpha: isDark ? DSStyles.alphaMuted : 0.22,
        ),
        blurRadius: DSSpacing.lg + DSSpacing.xs,
        offset: const Offset(0, DSStyles.elevationLG),
      ),
      BoxShadow(
        color: DSColors.black.withValues(
          alpha: isDark ? DSStyles.alphaMuted : DSStyles.alphaSoft,
        ),
        blurRadius: DSSpacing.lg,
        offset: Offset(0, DSSpacing.md - DSSpacing.xs),
      ),
    ];
  }

  /// Compact chip shadow (DEBUG chip, splash chips).
  static List<BoxShadow> shadowCompact(BuildContext context) {
    final isDark = _isDark(context);
    return [
      BoxShadow(
        color: DSColors.primary.withValues(
          alpha: isDark ? DSStyles.alphaMuted : DSStyles.alphaSubtle,
        ),
        blurRadius: blurSigma,
        offset: const Offset(0, DSSpacing.sm),
      ),
    ];
  }
}

enum DSGlassTone {
  /// Floating header / bottom nav — frosted **primary** brand base.
  chrome,

  /// Form cards / dense neutral panels.
  card,
}
