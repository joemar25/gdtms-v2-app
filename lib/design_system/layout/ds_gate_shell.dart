// DOCS: docs/development-standards.md
// DOCS: docs/design-system.md

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/design_system/backdrop/backdrop.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_animations.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_colors.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_icon_sizes.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_spacing.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_styles.dart';

/// Full-screen shell for **pre-dashboard gates** (permissions, update, …).
///
/// Backdrop defaults to [DsBackdrop.gate].
/// Login uses [AuthShell] + [DsBackdrop.auth] instead.
class DSGateShell extends ConsumerWidget {
  const DSGateShell({
    super.key,
    required this.child,
    this.loading = false,
    this.showThemeToggle = false,
    this.backdrop = DsBackdrop.gate,
    this.backdropConfig,
    this.maxContentWidth = 420,
    this.padding,
  });

  final Widget child;
  final bool loading;
  final bool showThemeToggle;
  final DsBackdrop backdrop;
  final DsBrandBackdropConfig? backdropConfig;
  final double maxContentWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: DSColors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: isDark
            ? DSColors.scaffoldDark
            : const Color(0xFFEAF6EC),
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
    );

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (backdropConfig != null)
            DsBrandBackdrop(config: backdropConfig)
          else
            DsBrandBackdrop(variant: backdrop),

          if (showThemeToggle)
            Positioned(
              top: topInset + DSSpacing.sm,
              right: DSSpacing.sm,
              child: const _GateThemeToggle()
                  .animate()
                  .fadeIn(duration: DSAnimations.dNormal, delay: 300.ms)
                  .scale(
                    begin: const Offset(0.88, 0.88),
                    end: const Offset(1, 1),
                    duration: DSAnimations.dNormal,
                    delay: 300.ms,
                    curve: Curves.easeOutBack,
                  ),
            ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding:
                    padding ??
                    const EdgeInsets.fromLTRB(
                      DSSpacing.lg,
                      DSSpacing.md,
                      DSSpacing.lg,
                      DSSpacing.lg,
                    ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: child,
                ),
              ),
            ),
          ),

          if (loading)
            ColoredBox(
              color: DSColors.black.withValues(alpha: DSStyles.alphaMuted),
              child: const Center(child: CircularProgressIndicator()),
            ).animate().fadeIn(duration: DSAnimations.dFast),
        ],
      ),
    );
  }
}

class _GateThemeToggle extends ConsumerWidget {
  const _GateThemeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: DSColors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          ref
              .read(authProvider.notifier)
              .setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
        },
        borderRadius: BorderRadius.circular(100),
        child: AnimatedContainer(
          duration: DSAnimations.dFast,
          padding: const EdgeInsets.all(DSSpacing.sm),
          decoration: BoxDecoration(
            color: isDark
                ? DSColors.white.withValues(alpha: 0.12)
                : DSColors.white.withValues(alpha: 0.88),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark
                  ? DSColors.white.withValues(alpha: 0.10)
                  : DSColors.separatorLight,
            ),
          ),
          child: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            size: DSIconSize.md,
            color: isDark ? DSColors.white : DSColors.primary,
          ),
        ),
      ),
    );
  }
}
