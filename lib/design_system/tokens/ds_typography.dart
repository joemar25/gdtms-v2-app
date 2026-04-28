import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_colors.dart';

/// Design-system typography tokens.
///
/// Primary API: use the semantic methods — label(), caption(), body(),
/// subTitle(), title(), heading(), display(), button().
///
/// 5-point size scale — override only when genuinely needed:
///   DSTypography.body(fontSize: DSTypography.sizeLg)
class DSTypography {
  // ── Size scale (5 tiers) ───────────────────────────────────────────────────
  static const double sizeXs = 10.0; // labels, nav, micro badges
  static const double sizeSm = 12.0; // captions, timestamps, meta
  static const double sizeMd = 14.0; // body text (default)
  static const double sizeLg = 20.0; // section titles
  static const double sizeXl = 24.0; // headings, display

  // ── Letter spacing ─────────────────────────────────────────────────────────
  static const double lsTight = -1.0;
  static const double lsSlightlyTight = -0.5;
  static const double lsMicroTight = -0.2;
  static const double lsTadTight = -0.1;
  static const double lsNone = 0.0;
  static const double lsSlightlyLoose = 0.2;
  static const double lsSmallLoose = 0.3;
  static const double lsLoose = 0.5;
  static const double lsMediumLoose = 0.7;
  static const double lsExtraLoose = 0.8;
  static const double lsMegaLoose = 1.2;
  static const double lsGiantLoose = 1.5;

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
    letterSpacing: lsMicroTight,
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
    letterSpacing: lsSlightlyLoose,
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
