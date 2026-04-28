// DOCS: docs/development-standards.md
import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_colors.dart';

/// Design-system typography tokens.
///
/// STABILITY RULE: Only 3 to 5 standard tiers allowed per category.
/// REJECT any new tier requests that exceed this scale.
class DSTypography {
  // ── Size scale (5 tiers) ───────────────────────────────────────────────────
  static const double sizeXs = 12.0; // labels, nav, micro badges
  static const double sizeSm = 14.0; // captions, timestamps, meta
  static const double sizeMd = 16.0; // body text (default)
  static const double sizeLg = 18.0; // section titles
  static const double sizeXl = 20.0; // headings, display

  // ── Specialty Sizes (Calculations in Config) ──────────────────────────────
  static const double sizeHero = 32.0; // Large hero text

  // ── Letter spacing (5 tiers) ────────────────────────────────────────────────
  static const double lsTight = -1.0;
  static const double lsSlightlyTight = -0.5;
  static const double lsNone = 0.0;
  static const double lsLoose = 0.3;
  static const double lsExtraLoose = 0.8;

  // ── Semantic methods ───────────────────────────────────────────────────────

  static TextStyle display({Color? color}) => TextStyle(
    fontFamily: 'Montserrat',
    fontSize: sizeXl,
    fontWeight: FontWeight.w900,
    color: color,
    letterSpacing: lsSlightlyTight,
  );

  static TextStyle heading({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
  }) => TextStyle(
    fontFamily: 'Montserrat',
    fontSize: fontSize ?? sizeXl,
    color: color,
    fontWeight: fontWeight ?? FontWeight.w800,
    letterSpacing: lsTight,
  );

  static TextStyle title({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
  }) => TextStyle(
    fontFamily: 'Montserrat',
    fontSize: fontSize ?? sizeLg,
    color: color,
    fontWeight: fontWeight ?? FontWeight.w700,
    letterSpacing: lsSlightlyTight,
  );

  static TextStyle subTitle({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
  }) => TextStyle(
    fontFamily: 'Montserrat',
    fontSize: fontSize ?? sizeMd,
    color: color,
    fontWeight: fontWeight ?? FontWeight.w600,
    letterSpacing: lsSlightlyTight,
  );

  static TextStyle body({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
  }) => TextStyle(
    fontFamily: 'Montserrat',
    fontSize: fontSize ?? sizeMd,
    color: color,
    fontWeight: fontWeight ?? FontWeight.w400,
    letterSpacing: lsNone,
  );

  static TextStyle button({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
  }) => TextStyle(
    fontFamily: 'Montserrat',
    fontSize: fontSize ?? sizeMd,
    color: color ?? DSColors.white,
    fontWeight: fontWeight ?? FontWeight.w700,
    letterSpacing: lsLoose,
  );

  static TextStyle caption({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
  }) => TextStyle(
    fontFamily: 'Montserrat',
    fontSize: fontSize ?? sizeSm,
    color: color,
    fontWeight: fontWeight ?? FontWeight.w400,
    letterSpacing: lsNone,
  );

  static TextStyle label({Color? color}) => TextStyle(
    fontFamily: 'Montserrat',
    fontSize: sizeXs,
    fontWeight: FontWeight.w700,
    color: color,
    letterSpacing: lsExtraLoose,
  );

  static TextStyle get labelCaps => label();
}
