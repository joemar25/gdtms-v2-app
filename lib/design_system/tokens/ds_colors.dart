import 'package:flutter/material.dart';

/// Design-system color tokens. Single source of truth for all colors.
///
/// Usage: `DSColors.primary`, `DSColors.scaffoldLight`, etc.
/// Do NOT hard-code colors outside this file.
class DSColors {
  // ── Base ──────────────────────────────────────────────────────────────────
  static const transparent = Colors.transparent;
  static const black = Color(0xFF000000);
  static const white = Color(0xFFFFFFFF);

  // ── Brand ─────────────────────────────────────────────────────────────────
  static const primary = Color(0xFF00B14F);
  static const systemBlue = Color(0xFF0A7AFF);
  static const red = Color(0xFFFF453A);

  // ── Text / Labels ─────────────────────────────────────────────────────────
  static const labelPrimary = Color(0xFF111114);
  static const labelPrimaryDark = Color(0xFFF9FAFB);
  static const labelSecondary = Color(0xFF6B7280);
  static const labelSecondaryDark = Color(0xFF9CA3AF);
  static const labelTertiary = Color(0xFF9CA3AF);
  static const labelTertiaryDark = Color(0xFF6B7280);

  // ── Scaffolds ─────────────────────────────────────────────────────────────
  static const scaffoldLight = Color(0xFFF8F9FA);
  static const scaffoldDark = Color(0xFF0B0D0F);

  // ── App Bar ───────────────────────────────────────────────────────────────
  static const appBarLight = Color(0xFFFFFFFF);
  static const appBarDark = Color(0xFF15171A);

  // ── Cards / Surfaces ──────────────────────────────────────────────────────
  static const cardLight = Color(0xFFFFFFFF);
  static const cardDark = Color(0xFF15171A);
  static const elevatedCardDark = Color(0xFF1E2125);
  static const secondarySurfaceLight = Color(0xFFF3F4F6);
  static const secondarySurfaceDark = Color(0xFF1E2125);

  // ── Separators / Borders ──────────────────────────────────────────────────
  static const separatorLight = Color(0xFFE5E7EB);
  static const separatorDark = Color(0xFF272A30);

  // ── Semantic Aliases ──────────────────────────────────────────────────────
  static const secondary = labelSecondary;
  static const subSecondary = labelTertiary;
  static const tertiary = separatorLight;
}
