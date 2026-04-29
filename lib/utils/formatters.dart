import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class AppFormatters {
  AppFormatters._();

  // Always ₱ — language does not affect currency symbol.
  static String currency(double amount) {
    return NumberFormat.currency(
      locale: 'fil-PH',
      symbol: '₱',
      decimalDigits: 2,
    ).format(amount);
  }

  // Month name changes by language (e.g. "April" vs "Abril").
  static String date(DateTime date, BuildContext context) {
    final locale = context.locale.languageCode == 'fil' ? 'fil' : 'en';
    return DateFormat.yMMMMd(locale).format(date);
  }
}
