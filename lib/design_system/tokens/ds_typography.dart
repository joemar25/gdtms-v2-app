// DOCS: docs/development-standards.md
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_colors.dart';

/// Design-system typography tokens.
///
/// STABILITY RULE: Only 3 to 5 standard tiers allowed per category.
/// REJECT any new tier requests that exceed this scale.
class DSTypography {
  // ── Font Family Constants (Cached) ──────────────────────────────────────────
  // Pre-cache Google Fonts to avoid repeated lookups
  static final String _fontFamily = GoogleFonts.montserrat().fontFamily!;

  // ── Size scale (5 tiers) ───────────────────────────────────────────────────
  static const double sizeXs = 10.0; // labels, nav, micro badges
  static const double sizeSm = 12.0; // captions, timestamps, meta
  static const double sizeMd = 14.0; // body text (default)
  static const double sizeLg = 16.0; // section titles
  static const double sizeXl = 18.0; // headings, display

  // ── Specialty Sizes ───────────────────────────────────────────────────────
  static const double sizeHero = sizeLg * 2; // Large hero text
  static const double sizeDisplayHero = 42.0; // Premium large amounts (Wallet)

  // ── Line Height (5 tiers) ──────────────────────────────────────────────────
  static const double lineHeightTight = 1.2;
  static const double lineHeightDefault = 1.5;
  static const double lineHeightLoose = 1.75;

  // ── Letter spacing (5 tiers) ────────────────────────────────────────────────
  static const double lsTight = -1.0;
  static const double lsSlightlyTight = -0.5;
  static const double lsNone = 0.0;
  static const double lsLoose = 0.3;
  static const double lsExtraLoose = 0.8;

  // ── Semantic methods ───────────────────────────────────────────────────────

  static TextStyle display({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
  }) => TextStyle(
    fontFamily: _fontFamily,
    fontSize: fontSize ?? sizeXl,
    fontWeight: fontWeight ?? FontWeight.w900,
    color: color,
    letterSpacing: lsSlightlyTight,
    height: lineHeightTight,
  );

  static TextStyle heading({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
  }) => TextStyle(
    fontFamily: _fontFamily,
    fontSize: fontSize ?? sizeXl,
    color: color,
    fontWeight: fontWeight ?? FontWeight.w900,
    letterSpacing: lsTight,
    height: lineHeightTight,
  );

  static TextStyle title({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
  }) => TextStyle(
    fontFamily: _fontFamily,
    fontSize: fontSize ?? sizeLg,
    color: color,
    fontWeight: fontWeight ?? FontWeight.w800,
    letterSpacing: lsSlightlyTight,
    height: lineHeightDefault,
  );

  static TextStyle subTitle({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
  }) => TextStyle(
    fontFamily: _fontFamily,
    fontSize: fontSize ?? sizeMd,
    color: color,
    fontWeight: fontWeight ?? FontWeight.w800,
    letterSpacing: lsSlightlyTight,
    height: lineHeightDefault,
  );

  static TextStyle body({
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

  static TextStyle button({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
  }) => TextStyle(
    fontFamily: _fontFamily,
    fontSize: fontSize ?? sizeMd,
    color: color ?? DSColors.white,
    fontWeight: fontWeight ?? FontWeight.w800,
    letterSpacing: lsLoose,
    height: lineHeightTight,
  );

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

  static TextStyle label({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
  }) => TextStyle(
    fontFamily: _fontFamily,
    fontSize: fontSize ?? sizeXs,
    fontWeight: fontWeight ?? FontWeight.w900,
    color: color,
    letterSpacing: lsExtraLoose,
    height: lineHeightTight,
  );

  static TextStyle labelCaps({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
  }) => label(color: color, fontSize: fontSize, fontWeight: fontWeight);
}
