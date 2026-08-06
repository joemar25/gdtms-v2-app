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
/// - [DSGlassTone.chrome] — **primary-tinted** header / bottom nav (iOS frost)
/// - [DSGlassTone.card] — neutral elevated panels / form cards
///
/// Real iPhone glass = heavy blur of content behind + translucent tint +
/// specular rims. Never paint opaque solid under [BackdropFilter].
class DSGlass {
  DSGlass._();

  /// Header / bottom-nav height (72).
  static const double chromeHeight = DSSpacing.huge + DSSpacing.sm;

  /// Brand green wash (light). Rich FSI green over white lists (bottom nav).
  /// Low α → mint; target ~solid primary family while blur still reads.
  static const double chromeAlphaLight = 0.72;

  /// Brand green wash (dark). Slightly stronger so glass holds over dark cards.
  static const double chromeAlphaDark = 0.74;

  /// White frost film over blur. Keep low — high frost turns brand green mint.
  static const double frostAlphaLight = 0.04;
  static const double frostAlphaDark = 0.03;

  /// Default blur for neutral cards / chips.
  static const double blurSigma = DSSpacing.lg; // 24

  /// Chrome blur — strong frost, but not so soft that UI edges vanish.
  static double blurSigmaFor(BuildContext context) =>
      _isDark(context) ? 36.0 : 28.0;

  static ImageFilter get filter =>
      ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma);

  /// Mode-aware blur for header / nav chrome.
  static ImageFilter filterFor(BuildContext context) {
    final s = blurSigmaFor(context);
    return ImageFilter.blur(sigmaX: s, sigmaY: s, tileMode: TileMode.clamp);
  }

  /// Real content frost for chrome. Pure blur only — no post-blur brightness
  /// lift (that matrix washed green to pale mint and hid UI structure).
  static ImageFilter liquidFilterFor(BuildContext context) =>
      filterFor(context);

  /// Top inset for scroll bodies under glass [AppHeaderBar] when the scaffold
  /// uses [Scaffold.extendBodyBehindAppBar] (content must paint under chrome
  /// so [BackdropFilter] can sample real UI, not empty air).
  ///
  /// Uses [MediaQuery.viewPadding] (never zeroed by Scaffold) + [chromeHeight].
  static double bodyTopUnderChrome(
    BuildContext context, {
    double gap = DSSpacing.md,
  }) {
    return MediaQuery.viewPaddingOf(context).top + chromeHeight + gap;
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
        // Bright glass rim — catches light like real material.
        return DSColors.white.withValues(alpha: isDark ? 0.32 : 0.55);
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

  static Color onChrome(BuildContext context) => DSColors.white;

  static Color onChromeMuted(BuildContext context) =>
      DSColors.white.withValues(alpha: _isDark(context) ? 0.75 : 0.90);

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
    // Floating glass pill — ambient green glow + depth + soft top lift.
    return [
      BoxShadow(
        color: DSColors.primary.withValues(alpha: isDark ? 0.48 : 0.40),
        blurRadius: DSSpacing.xl + DSSpacing.sm,
        spreadRadius: 0,
        offset: const Offset(0, DSSpacing.sm + DSSpacing.xs),
      ),
      BoxShadow(
        color: DSColors.black.withValues(alpha: isDark ? 0.40 : 0.16),
        blurRadius: DSSpacing.xl,
        offset: const Offset(0, DSSpacing.md),
      ),
      BoxShadow(
        color: DSColors.white.withValues(alpha: isDark ? 0.04 : 0.22),
        blurRadius: DSSpacing.sm,
        offset: const Offset(0, -1),
      ),
    ];
  }

  /// Soft lift under full-bleed header (not a hard card shadow).
  ///
  /// **No black shadow** — black under rounded bottom corners reads as dirty
  /// dark spots (see flutter_01 Dispatch header). Brand-green ambient only.
  static List<BoxShadow> headerShadow(BuildContext context) {
    final isDark = _isDark(context);
    return [
      BoxShadow(
        color: DSColors.primary.withValues(alpha: isDark ? 0.28 : 0.18),
        blurRadius: DSSpacing.lg,
        offset: const Offset(0, DSSpacing.sm),
        spreadRadius: 0,
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

/// Visual edge treatment for [DSGlassChrome].
enum DSGlassChromeEdge {
  /// Full-bleed app bar (status bar continuous). Soft bottom glass fade.
  header,

  /// Floating pill (bottom nav). Full rim + lift shadows.
  floating,

  /// Strip under header (filters / status). Continuous with header.
  strip,
}
