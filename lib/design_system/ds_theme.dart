import 'package:flutter/material.dart';
import 'tokens/ds_colors.dart';
import 'tokens/ds_typography.dart';
import 'tokens/ds_spacing.dart';
import 'tokens/ds_styles.dart';

/// DSTheme - Centralized theme configuration for the FSI Design System.
/// This separates the theme building logic (Component Configs) from the raw tokens (DSColors).
class DSTheme {
  static ThemeData build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scaffoldColor = isDark ? DSColors.scaffoldDark : DSColors.scaffoldLight;
    final cardColor = isDark ? DSColors.cardDark : DSColors.cardLight;
    final appBarColor = isDark ? DSColors.cardDark : DSColors.cardLight;
    final primaryLabel = isDark ? DSColors.labelPrimaryDark : DSColors.labelPrimary;
    final secondaryLabel = isDark ? DSColors.labelSecondaryDark : DSColors.labelSecondary;
    final activePrimary = isDark ? DSColors.primaryDark : DSColors.primary;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: activePrimary,
      scaffoldBackgroundColor: scaffoldColor,
      dividerColor: isDark ? DSColors.separatorDark : DSColors.separatorLight,
      fontFamily: 'Montserrat',

      colorScheme: ColorScheme.fromSeed(
        seedColor: DSColors.primary,
        brightness: brightness,
        primary: activePrimary,
        onPrimary: DSColors.white,
        secondary: DSColors.accent,
        onSecondary: DSColors.white,
        error: DSColors.error,
        onError: DSColors.white,
        surface: cardColor,
        onSurface: primaryLabel,
        outline: isDark ? DSColors.separatorDark : DSColors.separatorLight,
      ),

      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: appBarColor,
        surfaceTintColor: DSColors.transparent,
        elevation: DSStyles.elevationNone,
        scrolledUnderElevation: DSStyles.elevationNone,
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
        elevation: DSStyles.elevationNone,
        margin: EdgeInsets.symmetric(
          horizontal: DSSpacing.md,
          vertical: DSSpacing.sm,
        ),
        shape: RoundedRectangleBorder(borderRadius: DSStyles.cardRadius),
      ),

      // Elevated Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: activePrimary,
          foregroundColor: DSColors.white,
          elevation: DSStyles.elevationNone,
          padding: EdgeInsets.symmetric(
            vertical: DSSpacing.md,
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
        fillColor: isDark ? DSColors.secondarySurfaceDark : DSColors.secondarySurfaceLight,
        contentPadding: EdgeInsets.symmetric(
          horizontal: DSSpacing.lg,
          vertical: DSSpacing.md,
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
          borderSide: BorderSide(color: activePrimary, width: DSStyles.borderWidth * 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: DSStyles.cardRadius,
          borderSide: const BorderSide(color: DSColors.error, width: 1),
        ),
        labelStyle: DSTypography.caption(color: secondaryLabel),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        elevation: DSStyles.elevationNone,
        shape: RoundedRectangleBorder(borderRadius: DSStyles.cardRadius),
        titleTextStyle: DSTypography.heading(
          color: primaryLabel,
        ).copyWith(fontSize: DSTypography.sizeMd),
        contentTextStyle: DSTypography.body(color: secondaryLabel),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: DSColors.transparent,
        elevation: DSStyles.elevationNone,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(DSStyles.radiusSheet),
          ),
        ),
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(
        color: isDark ? DSColors.separatorDark : DSColors.separatorLight,
        thickness: 1,
        space: 1,
      ),

      // List Tile Theme
      listTileTheme: ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: DSSpacing.md),
        titleTextStyle: DSTypography.body(
          color: primaryLabel,
        ).copyWith(fontWeight: FontWeight.w600),
        subtitleTextStyle: DSTypography.caption(color: secondaryLabel),
        iconColor: secondaryLabel,
      ),

      // SnackBar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? DSColors.cardElevatedDark : DSColors.white,
        contentTextStyle: DSTypography.body(
          color: isDark ? DSColors.labelPrimaryDark : DSColors.labelPrimary,
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
          borderSide: BorderSide(color: activePrimary, width: DSStyles.strokeWidth),
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
          if (states.contains(WidgetState.selected)) return DSColors.white;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return activePrimary;
          return isDark ? DSColors.separatorDark : DSColors.separatorLight;
        }),
      ),
    );
  }
}
