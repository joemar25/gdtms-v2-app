// DOCS: docs/development-standards.md
import 'package:flutter/material.dart';

/// DSColors - The centralized color palette for the FSI Design System.
///
/// STABILITY RULE: Only 3 to 5 standard tiers allowed per category.
/// REJECT any new tier requests that exceed this scale.
class DSColors {
  // ── Base ──────────────────────────────────────────────────────────────────
  static const transparent = Colors.transparent;
  static const black = Color(0xFF111111);
  static const white = Color(0xFFFFFFFF);

  // ── Brand ─────────────────────────────────────────────────────────────────
  static const primary = Color(0xFF307539); // FSI Green
  static const primaryPressed = Color(0xFF286530); // FSI Green pressed
  static const primarySurface = Color(0xFFDCFCE7); // Green 100
  static const primaryDark = Color(0xFF3D8A47); // FSI Green light
  static const primaryDarkPressed = Color(0xFF307539); // FSI Green

  static const primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF286530)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gold = Color(0xFFCC9853); // FSI Gold — FAB, map pin
  static const goldSurface = Color(0xFFFDF3E3);

  static const accent = Color(0xFF1E40AF); // Blue 800 — pickup, links
  static const accentSurface = Color(0xFFDBEAFE); // Blue 100

  // ── Semantic Status ───────────────────────────────────────────────────────

  // Delivered (green)
  static const success = Color(0xFF22C55E); // dot
  static const successText = Color(0xFF166534); // text
  static const successSurface = Color(0xFFDCFCE7); // bg
  static const successBorder = Color(0xFFBBF7D0);
  static const successDark = Color(0xFF22C55E);

  // Failed Delivery (red)
  static const error = Color(0xFFDC2626);
  static const errorText = Color(0xFF991B1B);
  static const errorSurface = Color(0xFFFEE2E2);
  static const errorBorder = Color(0xFFFECACA);
  static const errorDark = Color(0xFFEF4444);

  // In Transit (yellow)
  static const warning = Color(0xFFEAB308); // dot
  static const warningText = Color(0xFF854D0E);
  static const warningSurface = Color(0xFFFEF9C3);
  static const warningBorder = Color(0xFFFEF08A);
  static const warningDark = Color(0xFFEAB308);

  // Out for Delivery (orange)
  static const pending = Color(0xFFF97316); // dot
  static const pendingText = Color(0xFF9A3412);
  static const pendingSurface = Color(0xFFFFEDD5);
  static const pendingBorder = Color(0xFFFED7AA);
  static const pendingDark = Color(0xFFF97316);

  // Returned to Sender (purple)
  static const returned = Color(0xFF9333EA);
  static const returnedText = Color(0xFF6B21A8);
  static const returnedSurface = Color(0xFFF3E8FF);
  static const returnedBorder = Color(0xFFE9D5FF);

  // Pickup by FSI (blue)
  static const pickup = Color(0xFF3B82F6); // dot
  static const pickupText = Color(0xFF1E40AF);
  static const pickupSurface = Color(0xFFDBEAFE);
  static const pickupBorder = Color(0xFFBFDBFE);

  // Default / Unknown (neutral gray)
  static const neutral = Color(0xFF9CA3AF); // dot
  static const neutralText = Color(0xFF374151);
  static const neutralSurface = Color(0xFFF3F4F6);
  static const neutralBorder = Color(0xFFE5E7EB);

  // ── Text & Content ────────────────────────────────────────────────────────
  static const labelPrimary = Color(0xFF111111);
  static const labelSecondary = Color(0xFF888888);
  static const labelTertiary = Color(0xFFAAAAAA);

  static const labelPrimaryDark = Color(0xFFF8FAFC);
  static const labelSecondaryDark = Color(0xFFCBD5E1);
  static const labelTertiaryDark = Color(0xFF64748B);

  // ── Surfaces & Backgrounds ────────────────────────────────────────────────
  static const scaffoldLight = Color(0xFFFFFFFF);
  static const scaffoldDark = Color(0xFF111111);

  static const cardLight = Color(0xFFFFFFFF);
  static const cardDark = Color(0xFF1A1A1A);
  static const cardElevatedDark = Color(0xFF252525);

  static const secondarySurfaceLight = Color(0xFFF7F7F7); // muted bg
  static const secondarySurfaceDark = Color(0xFF222222);

  static const separatorLight = Color(0xFFE8E8E8);
  static const separatorDark = Color(0xFF333333);

  // ── Social & Brand ────────────────────────────────────────────────────────
  static const socialSms = Color(0xFF34C759);
  static const socialCall = Color(0xFF007AFF);
  static const socialViber = Color(0xFF7360F2);
  static const socialWhatsApp = Color(0xFF25D366);
  static const socialTelegram = Color(0xFF229ED9);

  // ── Status Helpers ────────────────────────────────────────────────────────

  /// Returns the dot/icon color for a given status string.
  static Color statusColor(String status, {bool isDark = false}) {
    switch (status.toLowerCase()) {
      case 'delivered':
      case 'success':
        return isDark ? successDark : success;
      case 'out_for_delivery':
      case 'for_delivery':
        return isDark ? pendingDark : pending;
      case 'in_transit':
      case 'misrouted':
      case 'out_of_service_area':
        return isDark ? warningDark : warning;
      case 'failed_delivery':
      case 'failed':
        return isDark ? errorDark : error;
      case 'rts':
      case 'return_to_sender':
        return returned;
      case 'pickup_by_fsi':
      case 'pickup':
        return pickup;
      default:
        return isDark ? labelSecondaryDark : neutral;
    }
  }

  /// Returns the surface (background) color for a status badge.
  static Color statusSurface(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
      case 'success':
        return successSurface;
      case 'out_for_delivery':
      case 'for_delivery':
        return pendingSurface;
      case 'in_transit':
      case 'misrouted':
      case 'out_of_service_area':
        return warningSurface;
      case 'failed_delivery':
      case 'failed':
        return errorSurface;
      case 'rts':
      case 'return_to_sender':
        return returnedSurface;
      case 'pickup_by_fsi':
      case 'pickup':
        return pickupSurface;
      default:
        return neutralSurface;
    }
  }

  /// Returns the text color for a status badge.
  static Color statusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
      case 'success':
        return successText;
      case 'out_for_delivery':
      case 'for_delivery':
        return pendingText;
      case 'in_transit':
      case 'misrouted':
      case 'out_of_service_area':
        return warningText;
      case 'failed_delivery':
      case 'failed':
        return errorText;
      case 'rts':
      case 'return_to_sender':
        return returnedText;
      case 'pickup_by_fsi':
      case 'pickup':
        return pickupText;
      default:
        return neutralText;
    }
  }
}
