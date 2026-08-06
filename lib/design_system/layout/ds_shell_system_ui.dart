// DOCS: docs/development-standards.md
// DOCS: docs/design-system.md

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_colors.dart';

/// System status / navigation bar chrome.
///
/// **Adapts to what is on screen**, not only light/dark app theme:
/// - Post-login shell uses **green glass** headers/nav → light (white) status
///   icons and a brand-green system nav strip so chrome feels continuous.
/// - Auth/gate without green glass → theme surfaces (light or dark).
///
/// Prefer [wrap] / [AnnotatedRegion] over sticky [SystemChrome] so chrome
/// does not leak after modals dismiss.
class DsShellSystemUi {
  DsShellSystemUi._();

  // ── Green glass shell (tabs + DsAppScaffold + glass AppHeaderBar) ─────────

  /// Status / nav over **brand chrome** — light glyphs on green.
  ///
  /// **Always solid brand statusBarColor** — never transparent. Transparent
  /// status bars show the Android window black (continuous header regression).
  /// Locked by `test/design_system/ds_continuous_chrome_test.dart`.
  static SystemUiOverlayStyle shell(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Exact brand tokens — not ColorScheme seed greens.
    final chromeGreen = isDark ? DSColors.primaryDark : DSColors.primary;

    return SystemUiOverlayStyle(
      statusBarColor: chromeGreen,
      // White icons on green chrome — required for readability.
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark, // iOS: light icons on dark-ish bar
      systemNavigationBarColor: chromeGreen,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: DSColors.transparent,
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    );
  }

  // ── Non-glass screens (auth scenery, gates without green app bar) ────────

  /// Light theme, light surface (login cards / pale gates) → dark icons.
  static const SystemUiOverlayStyle lightSurface = SystemUiOverlayStyle(
    statusBarColor: DSColors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: DSColors.scaffoldLight,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: DSColors.transparent,
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced: false,
  );

  /// Dark theme surface → light icons.
  static const SystemUiOverlayStyle darkSurface = SystemUiOverlayStyle(
    statusBarColor: DSColors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: DSColors.scaffoldDark,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: DSColors.transparent,
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced: false,
  );

  /// Alias used at cold start before first frame (assume light shell glass).
  static final SystemUiOverlayStyle light = shellStyleLightFallback;

  /// Fallback when no [BuildContext] (e.g. [main] before runApp).
  static const SystemUiOverlayStyle shellStyleLightFallback =
      SystemUiOverlayStyle(
        statusBarColor: DSColors.primary,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: DSColors.primary,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: DSColors.transparent,
        systemNavigationBarContrastEnforced: false,
        systemStatusBarContrastEnforced: false,
      );

  /// Theme surface style (not green glass).
  static SystemUiOverlayStyle surfaceFor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkSurface : lightSurface;
  }

  /// Default for post-login shell roots = green glass adaptation.
  static SystemUiOverlayStyle styleFor(BuildContext context) => shell(context);

  /// Wrap post-login shell so status/nav match **green glass chrome**.
  static Widget wrap(BuildContext context, {required Widget child}) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: shell(context),
      child: child,
    );
  }

  /// Wrap screens without green glass (rare; prefer [wrap] for shell).
  static Widget wrapSurface(BuildContext context, {required Widget child}) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: surfaceFor(context),
      child: child,
    );
  }
}
