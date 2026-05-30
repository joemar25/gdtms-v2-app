// DOCS: docs/development-standards.md
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_colors.dart';

/// Design-system typography tokens.
///
/// STABILITY RULE: Only 3 to 5 standard tiers allowed per category.
/// REJECT any new tier requests that exceed this scale.
class DSTypography {
  // ── Font Families ───────────────────────────────────────────────────────────
  static final String _fontFamily = GoogleFonts.poppins().fontFamily!;
  // Monospace — tracking numbers only
  static const String _monoFamily = 'ui-monospace';

  // ── Size scale (5 tiers) ───────────────────────────────────────────────────
  static const double sizeXs = 10.0; // labels, nav, micro badges
  static const double sizeSm = 12.0; // captions, badges, timestamps
  static const double sizeMd = 14.0; // body text (default)
  static const double sizeLg = 16.0; // section titles
  static const double sizeXl = 20.0; // section headings
  static const double sizeDisplay = 24.0; // page headings

  // ── Specialty Sizes ───────────────────────────────────────────────────────
  static const double sizeHero = 32.0;
  static const double sizeDisplayHero = 42.0; // large amounts (Wallet)

  // ── Line Height (3 tiers) ──────────────────────────────────────────────────
  static const double lineHeightTight = 1.2;
  static const double lineHeightDefault = 1.5;
  static const double lineHeightLoose = 1.75;

  // ── Letter spacing ─────────────────────────────────────────────────────────
  static const double lsTight = -0.5;
  static const double lsNone = 0.0;
  // 0.05em ≈ 0.7px at 14px — uppercase labels
  static const double lsWide = 0.7;
  static const double lsExtraWide = 1.2;

  // Aliases for backward compatibility
  static const double lsSlightlyTight = lsTight;
  static const double lsLoose = lsWide;
  static const double lsExtraLoose = lsExtraWide;

  // ── Semantic methods ───────────────────────────────────────────────────────

  /// Page heading — 24px / w700
  static TextStyle display({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
  }) => TextStyle(
    fontFamily: _fontFamily,
    fontSize: fontSize ?? sizeDisplay,
    fontWeight: fontWeight ?? FontWeight.w700,
    color: color,
    letterSpacing: lsTight,
    height: lineHeightTight,
  );

  /// Section heading — 20px / w600
  static TextStyle heading({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
  }) => TextStyle(
    fontFamily: _fontFamily,
    fontSize: fontSize ?? sizeXl,
    color: color,
    fontWeight: fontWeight ?? FontWeight.w600,
    letterSpacing: lsTight,
    height: lineHeightTight,
  );

  /// Card / screen title — 16px / w600
  static TextStyle title({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
  }) => TextStyle(
    fontFamily: _fontFamily,
    fontSize: fontSize ?? sizeLg,
    color: color,
    fontWeight: fontWeight ?? FontWeight.w600,
    letterSpacing: lsNone,
    height: lineHeightDefault,
  );

  /// Sub-title / emphasized body — 14px / w600
  static TextStyle subTitle({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
  }) => TextStyle(
    fontFamily: _fontFamily,
    fontSize: fontSize ?? sizeMd,
    color: color,
    fontWeight: fontWeight ?? FontWeight.w600,
    letterSpacing: lsNone,
    height: lineHeightDefault,
  );

  /// Body text — 14px / w400
  static TextStyle body({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
  }) => TextStyle(
    fontFamily: _fontFamily,
    fontSize: fontSize ?? sizeMd,
    color: color,
    fontWeight: fontWeight ?? FontWeight.w400,
    letterSpacing: lsNone,
    height: lineHeightDefault,
  );

  /// CTA button text — 14px / w600
  static TextStyle button({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
  }) => TextStyle(
    fontFamily: _fontFamily,
    fontSize: fontSize ?? sizeMd,
    color: color ?? DSColors.white,
    fontWeight: fontWeight ?? FontWeight.w600,
    letterSpacing: lsWide,
    height: lineHeightTight,
  );

  /// Caption / timestamp — 12px / w500
  static TextStyle caption({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
  }) => TextStyle(
    fontFamily: _fontFamily,
    fontSize: fontSize ?? sizeSm,
    color: color,
    fontWeight: fontWeight ?? FontWeight.w500,
    letterSpacing: lsNone,
    height: lineHeightDefault,
  );

  /// Uppercase label / badge — 12px / w600 / wide spacing
  static TextStyle label({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
  }) => TextStyle(
    fontFamily: _fontFamily,
    fontSize: fontSize ?? sizeSm,
    fontWeight: fontWeight ?? FontWeight.w600,
    color: color,
    letterSpacing: lsWide,
    height: lineHeightTight,
  );

  static TextStyle labelCaps({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
  }) => label(color: color, fontSize: fontSize, fontWeight: fontWeight);

  /// Tracking number — monospace, 14px / w600
  static TextStyle trackingNumber({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
  }) => TextStyle(
    fontFamilyFallback: const [_monoFamily, 'monospace'],
    fontSize: fontSize ?? sizeMd,
    fontWeight: fontWeight ?? FontWeight.w600,
    color: color,
    letterSpacing: lsNone,
    height: lineHeightDefault,
  );
}
