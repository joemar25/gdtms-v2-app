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

  // ── Form rhythm (aliases of existing tiers — no new magic numbers) ──────
  //
  // Standard vertical stack for forms across the app:
  //   field → formFieldGap → field → formFieldToAction → link → formActionToCta → CTA
  //
  // Use these instead of ad-hoc SizedBox heights so login, reset, profile,
  // and future forms stay consistent.

  /// Between stacked form fields (phone → password).
  static const double formFieldGap = md; // 16
  static const hFormField = hMd;

  /// Between a field and its related inline action (e.g. Forgot password).
  /// Tighter than field gap — action is secondary, not another field.
  static const double formFieldToAction = sm; // 8
  static const hFormFieldToAction = hSm;

  /// Between an inline form action and the primary CTA.
  static const double formActionToCta = sm; // 8
  static const hFormActionToCta = hSm;

  /// Between last field and CTA when there is no inline action.
  static const double formFieldToCta = lg; // 24
  static const hFormFieldToCta = hLg;
}
