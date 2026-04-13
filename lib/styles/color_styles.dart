// DOCS: docs/styles.md — update that file when you edit this one.

import 'package:flutter/material.dart';

/// Modernized Color System for the FSI Courier App – iOS-inspired (2026)
///
/// This follows Apple's Human Interface Guidelines principles:
/// - Soft, clean light backgrounds with subtle depth
/// - Rich, deep dark mode with elevated layers for hierarchy
/// - Semantic colors for text, surfaces, and accents
/// - High contrast and accessibility-friendly
///
/// ## Usage Guidelines (Same as before)
/// - Scaffold: [scaffoldLight] / [scaffoldDark]
/// - AppBar: [appBarLight] / [appBarDark]
/// - Cards / Surfaces: [cardLight] / [cardDark] or [elevatedCardDark]
/// - Primary CTA: [primary] (grabGreen)
/// - Avoid hardcoding colors outside this file.

class ColorStyles {
  // ── Base Colors ────────────────────────────────────────────────────────────

  static const transparent = Colors.transparent;
  static const black = Color(0xFF000000);
  static const white = Color(0xFFFFFFFF);

  // ── Brand Colors ───────────────────────────────────────────────────────────

  /// Primary brand green – kept vibrant for CTAs and success
  /// HEX: #00B14F (very close to iOS system green)
  static const grabGreen = Color(0xFF00B14F);

  /// Darker green variant for text/high contrast on light surfaces
  static const grabDarkGreen = Color(0xFF007A36);

  /// Brand orange – slightly softened for modern warnings/offline
  /// Closer to iOS system orange
  static const grabOrange = Color(0xFFFF9500);

  // ── Semantic / System Colors ───────────────────────────────────────────────

  /// Primary accent (replaces old primary)
  static const primary = grabGreen;

  /// iOS-style system blue – perfect for links, Job Order IDs, interactive elements
  static const systemBlue = Color(0xFF007AFF);

  /// Destructive red – aligned with iOS system red
  static const red = Color(0xFFFF3B30);

  // Text / Label Colors (iOS-style hierarchy)
  /// Primary label / main text (near-black in light, near-white in dark)
  static const labelPrimary = Color(0xFF1C1C1E); // Light
  static const labelPrimaryDark = Color(0xFFF2F2F7); // Dark

  /// Secondary label / subtitles
  static const labelSecondary = Color(0xFF6E6E73); // Light
  static const labelSecondaryDark = Color(0xFF8E8E93); // Dark

  /// Tertiary / placeholder / subtle text
  static const labelTertiary = Color(0xFF9E9EA3); // Light
  static const labelTertiaryDark = Color(0xFF98989D); // Dark

  // ── Backgrounds & Surfaces ─────────────────────────────────────────────────

  /// Light mode scaffold – soft, clean off-white (very iOS-like)
  static const scaffoldLight = Color(0xFFF6F6F8);

  /// Dark mode scaffold – deep premium dark with subtle blue tone
  static const scaffoldDark = Color(0xFF0A0A0F);

  /// Light mode AppBar – pure white with subtle separation
  static const appBarLight = Color(0xFFFFFFFF);

  /// Dark mode AppBar – slightly elevated from scaffold
  static const appBarDark = Color(0xFF12121A);

  // ── Card / Elevated Surfaces ───────────────────────────────────────────────

  /// Light mode card background – very soft white/gray
  static const cardLight = Color(0xFFFFFFFF);

  /// Dark mode card background – rich dark with good contrast
  static const cardDark = Color(0xFF1C1C23);

  /// Elevated dark surface (modals, sheets, sub-cards)
  static const elevatedCardDark = Color(0xFF25252E);

  /// Light mode grouped / secondary surface (if needed)
  static const secondarySurfaceLight = Color(0xFFF2F2F7);

  // ── Separators / Borders ───────────────────────────────────────────────────

  /// Light mode divider
  static const separatorLight = Color(0xFFD1D1D6);

  /// Dark mode divider
  static const separatorDark = Color(0xFF38383E);

  // ── Legacy / Compatibility Aliases (keep for minimal breaking changes) ─────

  static const secondary = labelSecondary; // Old secondary text
  static const subSecondary = labelTertiary; // Old sub-secondary
  static const tertiary = separatorLight; // Old tertiary (borders)

  static const grabCardLight = cardLight;
  static const grabCardDark = cardDark;
  static const grabCardElevatedDark = elevatedCardDark;
  static const grabSurfaceDark = scaffoldDark;
}

// import 'package:flutter/material.dart';

// /// Central color system for the FSI Courier App.
// ///
// /// This class defines all the color constants used throughout the application
// /// to ensure a consistent visual identity.
// ///
// /// ## Usage Guidelines
// /// - **Scaffold backgrounds**: Use [scaffoldLight] or [scaffoldDark]. These are
// ///   applied globally in the theme.
// /// - **AppBar backgrounds**: Use [appBarLight] or [appBarDark]. These are
// ///   applied globally in the theme.
// /// - **Cards / Elevated Surfaces**: Use [grabCardLight] or [grabCardDark].
// /// - **Brand Colors**: Use [grabGreen] for primary actions and [grabOrange] for warnings.
// ///
// /// Avoid hardcoding `Color(0xFF...)` values in individual screen files. Always
// /// reference a named constant from this class.
// class ColorStyles {
//   // ── Base Colors ────────────────────────────────────────────────────────────

//   /// Fully transparent color. Used for overlays or containers that should not
//   /// obscure the background.
//   static const transparent = Colors.transparent;

//   /// Pure black color. Used sparingly for deep shadows or specific text.
//   static const black = Color(0xFF000000);

//   /// Pure white color. Used as the default surface color in light mode.
//   static const white = Color(0xFFFFFFFF);

//   // ── Brand Colors (Grab Express) ──────────────────────────────────────────

//   /// Primary brand green. Used for Call-to-Action (CTA) buttons, success states,
//   /// and key highlights.
//   /// HEX: #00B14F
//   static const grabGreen = Color(0xFF00B14F);

//   /// Darker variant of the brand green. Used for text on light backgrounds
//   /// that require higher contrast.
//   /// HEX: #007A36
//   static const grabDarkGreen = Color(0xFF007A36);

//   /// Brand orange. Used for warnings, offline indicators, and secondary highlights.
//   /// HEX: #FF6E00
//   static const grabOrange = Color(0xFFFF6E00);

//   // ── App Semantic Colors ────────────────────────────────────────────────────

//   /// Primary theme color. Alias for [grabGreen].
//   static const primary = grabGreen;

//   /// Secondary text or label color. Used for subtitles and less important info.
//   static const secondary = Color(0xFF526D82);

//   /// Sub-secondary color. Used for chip labels and placeholder text.
//   static const subSecondary = Color(0xFF9DB2BF);

//   /// Tertiary color. Used for dividers and borders in light mode.
//   static const tertiary = Color(0xFFDDE6ED);

//   /// Standard utility blue. Used for Job Order IDs and links.
//   static const blue = Color(0xFF2196F3);

//   /// Destructive or error red. Used for errors, RTS status, and critical alerts.
//   static const red = Color(0xFFD30000);

//   // ── Scaffold & AppBar Backgrounds ──────────────────────────────────────────
//   //
//   // These are set globally in [app.dart] via ThemeData.scaffoldBackgroundColor
//   // and ThemeData.appBarTheme. Individual screens should NOT override these
//   // unless there is a specific design requirement.

//   /// Light mode scaffold background color.
//   /// A very light off-white (#F4F5F9) to provide subtle contrast against white cards.
//   static const scaffoldLight = Color(0xFFF4F5F9);

//   /// Dark mode scaffold background color.
//   /// A deep, premium brand dark (#0D0D1A) instead of pure black.
//   static const scaffoldDark = Color(0xFF0D0D1A);

//   /// Light mode AppBar background color.
//   /// Typically pure white for a clean, professional look.
//   static const appBarLight = Color(0xFFFFFFFF);

//   /// Dark mode AppBar background color.
//   /// Slightly lighter than [scaffoldDark] (#12121F) to add subtle depth.
//   static const appBarDark = Color(0xFF12121F);

//   // ── Card / Surface Backgrounds ─────────────────────────────────────────────
//   //
//   // Used for DeliveryCard, BottomSheet, and any container that sits "above"
//   // the scaffold background.

//   /// Light mode card background color.
//   /// Very light cool-grey (#F5F6FA) for a flat, modern aesthetic.
//   static const grabCardLight = Color(0xFFF5F6FA);

//   /// Dark mode card background color.
//   /// Deep navy (#1A1A2E) that contrasts well with [scaffoldDark].
//   static const grabCardDark = Color(0xFF1A1A2E);

//   /// Elevated dark surface color.
//   /// Used for modals, dialogs, or sub-sections within a dark card.
//   static const grabCardElevatedDark = Color(0xFF252540);

//   /// Deep surface color for dark mode. Alias for [scaffoldDark].
//   static const grabSurfaceDark = Color(0xFF0D0D1A);
// }
