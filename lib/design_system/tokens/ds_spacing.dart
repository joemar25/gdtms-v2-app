// DOCS: docs/development-standards.md
import 'package:flutter/material.dart';

/// Design-system spacing tokens.
///
/// STABILITY RULE: Only 3 to 5 standard tiers allowed per category.
/// REJECT any new tier requests that exceed this scale.
class DSSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0; // Standard gap/padding
  static const double lg = 24.0; // Section spacing
  static const double xl = 32.0; // Large container spacing
  static const double huge = xl * 2.0; // 64.0
  static const double massive = xl * 3.0; // 96.0

  // ── Vertical Spacing ──────────────────────────────────────────────────────
  static const hXs = SizedBox(height: xs);
  static const hSm = SizedBox(height: sm);
  static const hMd = SizedBox(height: md);
  static const hLg = SizedBox(height: lg);
  static const hXl = SizedBox(height: xl);
  static const hHuge = SizedBox(height: huge);
  static const hMassive = SizedBox(height: massive);

  // ── Horizontal Spacing ────────────────────────────────────────────────────
  static const wXs = SizedBox(width: xs);
  static const wSm = SizedBox(width: sm);
  static const wMd = SizedBox(width: md);
  static const wLg = SizedBox(width: lg);
  static const wXl = SizedBox(width: xl);
  static const wHuge = SizedBox(width: huge);
  static const wMassive = SizedBox(width: massive);
}
