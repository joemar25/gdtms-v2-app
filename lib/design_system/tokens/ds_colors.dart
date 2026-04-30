// DOCS: docs/development-standards.md
import 'package:flutter/material.dart';

/// DSColors - The centralized color palette for the FSI Design System.
///
/// STABILITY RULE: Only 3 to 5 standard tiers allowed per category.
/// REJECT any new tier requests that exceed this scale.
class DSColors {
  // ── Base ──────────────────────────────────────────────────────────────────
  static const transparent = Colors.transparent;
  static const black = Color(0xFF020617); // Slate 950
  static const white = Color(0xFFFFFFFF);

  // ── Brand ─────────────────────────────────────────────────────────────────
  static const primary = Color(0xFF22C55E); // Green 500
  static const primaryPressed = Color(0xFF16A34A); // Green 600
  static const primarySurface = Color(0xFFDCFCE7); // Green 100
  static const primaryDark = Color(0xFF4ADE80); // Green 400
  static const primaryDarkPressed = Color(0xFF22C55E); // Green 500

  static const primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF15803D)], // Green 500 to Green 700
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const accent = Color(0xFF2563EB); // Blue 600
  static const accentSurface = Color(0xFFE0F2FE); // Light blue surface

  // ── Semantic Status ───────────────────────────────────────────────────────
  static const success = Color(0xFF10B981); // Emerald 500
  static const successText = Color(0xFF047857); // Emerald 700
  static const successSurface = Color(0xFFD1FAE5); // Emerald 100
  static const successDark = Color(0xFF34D399); // Emerald 400

  static const error = Color(0xFFF43F5E); // Rose 500
  static const errorText = Color(0xFFBE123C); // Rose 700
  static const errorSurface = Color(0xFFFFE4E6); // Rose 100
  static const errorDark = Color(0xFFFB7185); // Rose 400

  static const warning = Color(0xFFF59E0B); // Amber 500
  static const warningText = Color(0xFF92400E); // Amber 800
  static const warningSurface = Color(0xFFFEF3C7); // Amber 100
  static const warningDark = Color(0xFFFBBF24); // Amber 400

  static const pending = Color(0xFFF97316); // Orange 500
  static const pendingText = Color(0xFF7C2D12); // Orange 900
  static const pendingSurface = Color(0xFFFFEDD5); // Orange 100
  static const pendingDark = Color(0xFFFB923C); // Orange 400

  // ── Text & Content (Slate Neutrals) ───────────────────────────────────────
  static const labelPrimary = Color(0xFF0F172A); // Slate 900
  static const labelSecondary = Color(0xFF475569); // Slate 600
  static const labelTertiary = Color(0xFF94A3B8); // Slate 400

  static const labelPrimaryDark = Color(0xFFF8FAFC); // Slate 50
  static const labelSecondaryDark = Color(0xFFCBD5E1); // Slate 300
  static const labelTertiaryDark = Color(0xFF64748B); // Slate 500

  // ── Surfaces & Backgrounds ────────────────────────────────────────────────
  static const scaffoldLight = Color(0xFFF8FAFC); // Slate 50
  static const scaffoldDark = Color(0xFF020617); // Slate 950

  static const cardLight = Color(0xFFFFFFFF);
  static const cardDark = Color(0xFF0F172A); // Slate 900
  static const cardElevatedDark = Color(0xFF1E293B); // Slate 800

  static const secondarySurfaceLight = Color(0xFFF1F5F9); // Slate 100
  static const secondarySurfaceDark = Color(0xFF1E293B); // Slate 800

  static const separatorLight = Color(0xFFE2E8F0); // Slate 200
  static const separatorDark = Color(0xFF334155); // Slate 700

  // ── Social & Brand ────────────────────────────────────────────────────────
  static const socialSms = Color(0xFF34C759);
  static const socialCall = Color(0xFF007AFF);
  static const socialViber = Color(0xFF7360F2);
  static const socialWhatsApp = Color(0xFF25D366);
  static const socialTelegram = Color(0xFF229ED9);

  // ── Status Helper ─────────────────────────────────────────────────────────
  static Color statusColor(String status, {bool isDark = false}) {
    switch (status.toLowerCase()) {
      case 'delivered':
      case 'success':
        return isDark ? successDark : success;
      case 'failed_delivery':
      case 'failed':
        return isDark ? errorDark : error;
      case 'rts':
      case 'return_to_sender':
        return accent; // Accent is already balanced
      case 'osa':
      case 'out_of_service_area':
        return isDark ? warningDark : warning;
      case 'for_delivery':
        return isDark ? pendingDark : pending;
      default:
        return isDark ? labelSecondaryDark : labelSecondary;
    }
  }
}
