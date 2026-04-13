// DOCS: docs/shared/helpers.md — update that file when you edit this one.

import 'package:flutter/services.dart';

/// A [TextInputFormatter] that converts all input text to uppercase.
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}
