// DOCS: docs/styles.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';

const double textTitle = 20.0;
const double textSubtitle = 14.0;
const double textBody = 14.0;
const double textCaption = 12.0;

class TextStyles {
  static TextStyle title({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
  }) => TextStyle(
    fontFamily: 'Montserrat',
    fontSize: fontSize ?? textTitle,
    color:
        color ?? ColorStyles.labelPrimary, // Updated to a more sensible default
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
    color: color ?? ColorStyles.labelSecondary,
    fontWeight: fontWeight ?? FontWeight.w600,
    letterSpacing: -0.2,
  );

  static TextStyle caption({Color? color, double? fontSize}) => TextStyle(
    fontFamily: 'Montserrat',
    fontSize: fontSize ?? textCaption,
    color: color ?? ColorStyles.labelTertiary,
  );
}
