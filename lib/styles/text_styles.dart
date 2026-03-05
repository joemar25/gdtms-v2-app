
import 'package:flutter/material.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';

//fontSize
// const double textHeadline = 24.0;
// const double textSubhead = 20.0;
const double textTitle = 20.0;
const double textSubtitle = 14.0;
const double textBody = 14.0;
const double textCaption = 12.0;

class TextStyles {
  static title({Color? color, double? fontSize, FontWeight? fontWeight}) =>
      TextStyle(
          fontSize: fontSize ?? textTitle,
          color: color ?? ColorStyles.primary,
          fontWeight: fontWeight ?? FontWeight.w700);

  static subTitle({Color? color, double? fontSize, FontWeight? fontWeight}) =>
      TextStyle(
        fontSize: fontSize ?? textSubtitle,
        color: color ?? ColorStyles.primary,
        fontWeight: fontWeight ?? FontWeight.w500,
      );

  static caption({
    Color? color,
    double? fontSize,
  }) =>
      TextStyle(
        fontSize: fontSize ?? textCaption,
        color: color ?? ColorStyles.primary,
      );
}