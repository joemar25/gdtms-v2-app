// DOCS: docs/styles.md — update that file when you edit this one.

import 'package:flutter/material.dart';

/// Modernized Color System for the FSI Courier App – Premium Dribbble-like UI
///
/// This follows modern app design principles:
/// - Creamy, sophisticated light backgrounds instead of flat whites
/// - Deep, sleek dark mode palettes that feel premium
/// - Softly saturated primary colors
/// - High contrast layered surfacing
///
/// ## Usage Guidelines
/// - Scaffold: [scaffoldLight] / [scaffoldDark]
/// - AppBar: Transparent or [appBarLight] / [appBarDark]
/// - Cards / Surfaces: [cardLight] / [cardDark] or [elevatedCardDark]
/// - Primary CTA: [primary] (grabGreen)
/// - Avoid hardcoding colors outside this file.

class ColorStyles {
  // ── Base Colors ────────────────────────────────────────────────────────────

  static const transparent = Colors.transparent;
  static const black = Color(0xFF000000);
  static const white = Color(0xFFFFFFFF);

  // ── Brand Colors ───────────────────────────────────────────────────────────

  /// Primary brand green – slightly brightened for a modern, 'glowy' aesthetic
  static const grabGreen = Color(0xFF00B14F);

  /// Darker variant for high contrast needs
  static const grabDarkGreen = Color(0xFF008D3E);

  /// Brand orange – soft and punchy for modern warnings/offline
  static const grabOrange = Color(0xFFFF9F0A);

  // ── Semantic / System Colors ───────────────────────────────────────────────

  /// Primary accent
  static const primary = grabGreen;

  /// Modern sleek utility blue – perfect for Job Order IDs
  static const systemBlue = Color(0xFF0A7AFF);

  /// Destructive red – soft but clear
  static const red = Color(0xFFFF453A);

  // Text / Label Colors (Modern Hierarchy)
  /// Primary label / main text (Deep rich greys instead of stark black)
  static const labelPrimary = Color(0xFF111114); // Light
  static const labelPrimaryDark = Color(0xFFF9FAFB); // Dark

  /// Secondary label / subtitles
  static const labelSecondary = Color(0xFF6B7280); // Light
  static const labelSecondaryDark = Color(0xFF9CA3AF); // Dark

  /// Tertiary / placeholder / subtle text
  static const labelTertiary = Color(0xFF9CA3AF); // Light
  static const labelTertiaryDark = Color(0xFF6B7280); // Dark

  // ── Backgrounds & Surfaces ─────────────────────────────────────────────────

  /// Light mode scaffold – an ultra-soft cool grey for Dribbble-style separation
  static const scaffoldLight = Color(0xFFF8F9FA);

  /// Dark mode scaffold – extremely deep, sleek charcoal (nearly black)
  static const scaffoldDark = Color(0xFF0B0D0F);

  /// Light mode AppBar – pure white
  static const appBarLight = Color(0xFFFFFFFF);

  /// Dark mode AppBar – slightly elevated from pure scaffold
  static const appBarDark = Color(0xFF15171A);

  // ── Card / Elevated Surfaces ───────────────────────────────────────────────

  /// Light mode card background – clean bright white
  static const cardLight = Color(0xFFFFFFFF);

  /// Dark mode card background – a rich, slightly elevated grey
  static const cardDark = Color(0xFF15171A);

  /// Elevated dark surface (modals, sheets, sub-cards)
  static const elevatedCardDark = Color(0xFF1E2125);

  /// Light mode secondary / filled surface (e.g. for text inputs)
  static const secondarySurfaceLight = Color(0xFFF3F4F6);

  /// Dark mode secondary / filled surface
  static const secondarySurfaceDark = Color(0xFF1E2125);

  // ── Separators / Borders ───────────────────────────────────────────────────

  /// Light mode divider (extremely soft)
  static const separatorLight = Color(0xFFE5E7EB);

  /// Dark mode divider
  static const separatorDark = Color(0xFF272A30);

  // ── Legacy / Compatibility Aliases (keep for minimal breaking changes) ─────

  static const secondary = labelSecondary;
  static const subSecondary = labelTertiary;
  static const tertiary = separatorLight;

  static const grabCardLight = cardLight;
  static const grabCardDark = cardDark;
  static const grabCardElevatedDark = elevatedCardDark;
  static const grabSurfaceDark = scaffoldDark;
}
