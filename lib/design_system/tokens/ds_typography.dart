import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_colors.dart';

// Font-size constants kept as top-level values for legacy compatibility.
const double textTitle = 20.0;
const double textSubtitle = 14.0;
const double textBody = 14.0;
const double textCaption = 12.0;

/// Design-system typography tokens.
///
/// Replaces the old `TextStyles` class. All text styles in the app should
/// originate here.
class DSTypography {
  static TextStyle title({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
  }) => TextStyle(
    fontFamily: 'Montserrat',
    fontSize: fontSize ?? textTitle,
    color: color ?? DSColors.labelPrimary,
    fontWeight: fontWeight ?? FontWeight.w700,
    letterSpacing: -0.5,
  );

  static TextStyle subTitle({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
  }) => TextStyle(
    fontFamily: 'Montserrat',
    fontSize: fontSize ?? textSubtitle,
    color: color ?? DSColors.labelSecondary,
    fontWeight: fontWeight ?? FontWeight.w600,
    letterSpacing: -0.2,
  );

  static TextStyle caption({Color? color, double? fontSize}) => TextStyle(
    fontFamily: 'Montserrat',
    fontSize: fontSize ?? textCaption,
    color: color ?? DSColors.labelTertiary,
  );
}
