import 'package:flutter/material.dart';

/// Design-system spacing tokens.
///
/// Use these instead of raw double literals for padding/margin/gap values.
class DSSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double base = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;

  // ── Vertical Spacing ──────────────────────────────────────────────────────
  static const hXs = SizedBox(height: xs);
  static const hSm = SizedBox(height: sm);
  static const hMd = SizedBox(height: md);
  static const hBase = SizedBox(height: base);
  static const hLg = SizedBox(height: lg);
  static const hXl = SizedBox(height: xl);
  static const hXxl = SizedBox(height: xxl);
  static const hXxxl = SizedBox(height: xxxl);

  // ── Horizontal Spacing ────────────────────────────────────────────────────
  static const wXs = SizedBox(width: xs);
  static const wSm = SizedBox(width: sm);
  static const wMd = SizedBox(width: md);
  static const wBase = SizedBox(width: base);
  static const wLg = SizedBox(width: lg);
  static const wXl = SizedBox(width: xl);
  static const wXxl = SizedBox(width: xxl);
  static const wXxxl = SizedBox(width: xxxl);
}
