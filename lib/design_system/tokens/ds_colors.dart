import 'package:flutter/material.dart';
import 'ds_typography.dart';
import 'ds_spacing.dart';
import 'ds_styles.dart';

/// DSColors - The centralized color palette and theme definition for the FSI Design System.
class DSColors {
  // ── Base ──────────────────────────────────────────────────────────────────
  static const transparent = Colors.transparent;
  static const black = Color(0xFF020617); // Slate 950
  static const white = Color(0xFFFFFFFF);

  // ── Brand ─────────────────────────────────────────────────────────────────
  // Primary: light green — main CTA buttons, links, focus rings, active states.
  // Accent:  violet — tags, badges, secondary highlights.
  static const primary = Color(0xFF22C55E); // Green 500
  static const primaryPressed = Color(
    0xFF16A34A,
  ); // Green 600 (tap/hover state)
  static const primarySurface = Color(
    0xFFDCFCE7,
  ); // Green 100 (chip bg, tinted cards)
  static const primaryDark = Color(
    0xFF4ADE80,
  ); // Green 400 — brighter on dark bg
  static const primaryDarkPressed = Color(0xFF22C55E); // Green 500

  static const accent = Color(0xFF2563EB); // Blue 600
  static const accentSurface = Color(0xFFE0F2FE); // Light blue surface

  // ── Semantic Status ───────────────────────────────────────────────────────
  // Each status has three tones:
  //   fill    → icon color, filled button bg
  //   text    → text on light bg, text inside a surface chip
  //   surface → chip/badge background

  static const success = Color(0xFF10B981); // Emerald 500
  static const successText = Color(0xFF047857); // Emerald 700
  static const successSurface = Color(0xFFD1FAE5); // Emerald 100

  static const error = Color(0xFFF43F5E); // Rose 500
  static const errorText = Color(0xFFBE123C); // Rose 700
  static const errorSurface = Color(0xFFFFE4E6); // Rose 100

  static const warning = Color(0xFFF59E0B); // Amber 500
  static const warningText = Color(0xFF92400E); // Amber 800
  static const warningSurface = Color(0xFFFEF3C7); // Amber 100

  static const pending = Color(0xFFF97316); // Orange 500
  static const pendingText = Color(0xFF7C2D12); // Orange 900
  static const pendingSurface = Color(0xFFFFEDD5); // Orange 100

  // ── Text & Content (Slate Neutrals) ───────────────────────────────────────
  static const labelPrimary = Color(0xFF0F172A); // Slate 900
  static const labelSecondary = Color(
    0xFF475569,
  ); // Slate 600 — passes AA on white
  static const labelTertiary = Color(
    0xFF94A3B8,
  ); // Slate 400 — placeholder/hint only

  static const labelPrimaryDark = Color(0xFFF8FAFC); // Slate 50
  static const labelSecondaryDark = Color(0xFFCBD5E1); // Slate 300
  static const labelTertiaryDark = Color(0xFF64748B); // Slate 500

  // ── Surfaces & Backgrounds ────────────────────────────────────────────────
  static const scaffoldLight = Color(0xFFF8FAFC); // Slate 50
  static const scaffoldDark = Color(0xFF020617); // Slate 950

  // appBar uses cardLight/cardDark — no separate token needed
  static const cardLight = Color(0xFFFFFFFF);
  static const cardDark = Color(0xFF0F172A); // Slate 900
  static const cardElevatedDark = Color(
    0xFF1E293B,
  ); // Slate 800 — modals, bottom sheets

  static const secondarySurfaceLight = Color(0xFFF1F5F9); // Slate 100
  static const secondarySurfaceDark = Color(0xFF1E293B); // Slate 800

  static const separatorLight = Color(0xFFE2E8F0); // Slate 200
  static const separatorDark = Color(0xFF334155); // Slate 700

  // ── Theme Definitions ─────────────────────────────────────────────────────

  static ThemeData buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scaffoldColor = isDark ? scaffoldDark : scaffoldLight;
    final cardColor = isDark ? cardDark : cardLight;
    final appBarColor = isDark ? cardDark : cardLight;
    final primaryLabel = isDark ? labelPrimaryDark : labelPrimary;
    final secondaryLabel = isDark ? labelSecondaryDark : labelSecondary;
    final activePrimary = isDark ? primaryDark : primary;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: activePrimary,
      scaffoldBackgroundColor: scaffoldColor,
      dividerColor: isDark ? separatorDark : separatorLight,
      fontFamily: 'Montserrat',

      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        primary: activePrimary,
        onPrimary: white,
        secondary: accent,
        onSecondary: white,
        error: error,
        onError: white,
        surface: cardColor,
        onSurface: primaryLabel,
        outline: isDark ? separatorDark : separatorLight,
      ),

      // App Bar
      appBarTheme: AppBarTheme(
        backgroundColor: appBarColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: primaryLabel),
        titleTextStyle: DSTypography.subTitle(
          color: primaryLabel,
        ).copyWith(fontSize: DSTypography.sizeMd),
      ),

      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (BuildContext context) =>
            const Icon(Icons.arrow_back_ios_new_rounded),
      ),

      // Text Theme
      textTheme: TextTheme(
        bodyLarge: DSTypography.body(color: primaryLabel),
        bodyMedium: DSTypography.body(color: primaryLabel),
        bodySmall: DSTypography.caption(color: secondaryLabel),
        titleLarge: DSTypography.heading(color: primaryLabel),
        titleMedium: DSTypography.subTitle(color: primaryLabel),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: const EdgeInsets.symmetric(
          horizontal: DSSpacing.base,
          vertical: DSSpacing.sm,
        ),
        shape: RoundedRectangleBorder(borderRadius: DSStyles.cardRadius),
      ),

      // Elevated Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: activePrimary,
          foregroundColor: white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            vertical: DSSpacing.base,
            horizontal: DSSpacing.xl,
          ),
          textStyle: DSTypography.button(),
          shape: RoundedRectangleBorder(borderRadius: DSStyles.cardRadius),
        ),
      ),

      // Text Buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: activePrimary,
          textStyle: DSTypography.button(
            color: activePrimary,
          ).copyWith(fontSize: DSTypography.sizeMd),
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? secondarySurfaceDark : secondarySurfaceLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DSSpacing.lg,
          vertical: DSSpacing.base,
        ),
        border: OutlineInputBorder(
          borderRadius: DSStyles.cardRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: DSStyles.cardRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: DSStyles.cardRadius,
          borderSide: BorderSide(color: activePrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: DSStyles.cardRadius,
          borderSide: const BorderSide(color: error, width: 1),
        ),
        labelStyle: DSTypography.caption(color: secondaryLabel),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: DSStyles.cardRadius),
        titleTextStyle: DSTypography.heading(
          color: primaryLabel,
        ).copyWith(fontSize: DSTypography.sizeMd),
        contentTextStyle: DSTypography.body(color: secondaryLabel),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(DSStyles.radiusSheet),
          ),
        ),
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(
        color: isDark ? separatorDark : separatorLight,
        thickness: 1,
        space: 1,
      ),

      // List Tile Theme
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: DSSpacing.base),
        titleTextStyle: DSTypography.body(
          color: primaryLabel,
        ).copyWith(fontWeight: FontWeight.w600),
        subtitleTextStyle: DSTypography.caption(color: secondaryLabel),
        iconColor: secondaryLabel,
      ),

      // SnackBar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? cardElevatedDark : white,
        contentTextStyle: DSTypography.body(
          color: isDark ? labelPrimaryDark : labelPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: DSStyles.pillRadius),
        elevation: 4,
      ),

      // TabBar Theme
      tabBarTheme: TabBarThemeData(
        labelColor: activePrimary,
        unselectedLabelColor: secondaryLabel,
        labelStyle: DSTypography.button(),
        unselectedLabelStyle: DSTypography.button(),
        indicatorSize: TabBarIndicatorSize.label,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: activePrimary, width: 2),
        ),
      ),

      // Checkbox / Radio / Switch
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return activePrimary;
          return null;
        }),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DSStyles.radiusXS),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return activePrimary;
          return null;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return white;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return activePrimary;
          return isDark ? separatorDark : separatorLight;
        }),
      ),
    );
  }

  // ── Status Helper ─────────────────────────────────────────────────────────
  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
      case 'success':
        return success;
      case 'failed_delivery':
      case 'failed':
        return error;
      case 'rts':
      case 'return_to_sender':
        return accent;
      case 'osa':
      case 'out_of_service_area':
        return warning;
      case 'for_delivery':
        return pending;
      default:
        return labelSecondary;
    }
  }
}
