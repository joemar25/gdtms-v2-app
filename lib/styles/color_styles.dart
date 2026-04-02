import 'package:flutter/material.dart';

/// Central color system for the FSI Courier App.
///
/// This class defines all the color constants used throughout the application
/// to ensure a consistent visual identity.
///
/// ## Usage Guidelines
/// - **Scaffold backgrounds**: Use [scaffoldLight] or [scaffoldDark]. These are
///   applied globally in the theme.
/// - **AppBar backgrounds**: Use [appBarLight] or [appBarDark]. These are
///   applied globally in the theme.
/// - **Cards / Elevated Surfaces**: Use [grabCardLight] or [grabCardDark].
/// - **Brand Colors**: Use [grabGreen] for primary actions and [grabOrange] for warnings.
///
/// Avoid hardcoding `Color(0xFF...)` values in individual screen files. Always
/// reference a named constant from this class.
class ColorStyles {
  // ── Base Colors ────────────────────────────────────────────────────────────

  /// Fully transparent color. Used for overlays or containers that should not
  /// obscure the background.
  static const transparent = Colors.transparent;

  /// Pure black color. Used sparingly for deep shadows or specific text.
  static const black = Color(0xFF000000);

  /// Pure white color. Used as the default surface color in light mode.
  static const white = Color(0xFFFFFFFF);

  // ── Brand Colors (Grab Express) ──────────────────────────────────────────

  /// Primary brand green. Used for Call-to-Action (CTA) buttons, success states,
  /// and key highlights.
  /// HEX: #00B14F
  static const grabGreen = Color(0xFF00B14F);

  /// Darker variant of the brand green. Used for text on light backgrounds
  /// that require higher contrast.
  /// HEX: #007A36
  static const grabDarkGreen = Color(0xFF007A36);

  /// Brand orange. Used for warnings, offline indicators, and secondary highlights.
  /// HEX: #FF6E00
  static const grabOrange = Color(0xFFFF6E00);

  // ── App Semantic Colors ────────────────────────────────────────────────────

  /// Primary theme color. Alias for [grabGreen].
  static const primary = grabGreen;

  /// Secondary text or label color. Used for subtitles and less important info.
  static const secondary = Color(0xFF526D82);

  /// Sub-secondary color. Used for chip labels and placeholder text.
  static const subSecondary = Color(0xFF9DB2BF);

  /// Tertiary color. Used for dividers and borders in light mode.
  static const tertiary = Color(0xFFDDE6ED);

  /// Standard utility blue. Used for Job Order IDs and links.
  static const blue = Color(0xFF2196F3);

  /// Destructive or error red. Used for errors, RTS status, and critical alerts.
  static const red = Color(0xFFD30000);

  // ── Scaffold & AppBar Backgrounds ──────────────────────────────────────────
  //
  // These are set globally in [app.dart] via ThemeData.scaffoldBackgroundColor
  // and ThemeData.appBarTheme. Individual screens should NOT override these
  // unless there is a specific design requirement.

  /// Light mode scaffold background color.
  /// A very light off-white (#F4F5F9) to provide subtle contrast against white cards.
  static const scaffoldLight = Color(0xFFF4F5F9);

  /// Dark mode scaffold background color.
  /// A deep, premium brand dark (#0D0D1A) instead of pure black.
  static const scaffoldDark = Color(0xFF0D0D1A);

  /// Light mode AppBar background color.
  /// Typically pure white for a clean, professional look.
  static const appBarLight = Color(0xFFFFFFFF);

  /// Dark mode AppBar background color.
  /// Slightly lighter than [scaffoldDark] (#12121F) to add subtle depth.
  static const appBarDark = Color(0xFF12121F);

  // ── Card / Surface Backgrounds ─────────────────────────────────────────────
  //
  // Used for DeliveryCard, BottomSheet, and any container that sits "above"
  // the scaffold background.

  /// Light mode card background color.
  /// Very light cool-grey (#F5F6FA) for a flat, modern aesthetic.
  static const grabCardLight = Color(0xFFF5F6FA);

  /// Dark mode card background color.
  /// Deep navy (#1A1A2E) that contrasts well with [scaffoldDark].
  static const grabCardDark = Color(0xFF1A1A2E);

  /// Elevated dark surface color.
  /// Used for modals, dialogs, or sub-sections within a dark card.
  static const grabCardElevatedDark = Color(0xFF252540);

  /// Deep surface color for dark mode. Alias for [scaffoldDark].
  static const grabSurfaceDark = Color(0xFF0D0D1A);
}
