// DOCS: docs/development-standards.md
// DOCS: docs/entry-points.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/database/cleanup_service.dart';
import 'package:fsi_courier_app/core/services/version_check_service.dart';
import 'package:fsi_courier_app/core/settings/app_settings.dart';
import 'package:fsi_courier_app/core/settings/compact_mode_provider.dart';
import 'package:fsi_courier_app/core/settings/dashboard_feel_provider.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initAndNavigate();
    // Remove the native splash once the first frame is rendered.
    // This creates a seamless handoff from native to Flutter.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
  }

  Future<void> _initAndNavigate() async {
    await Future.wait([
      _initialize(),
      // Ensure the splash is visible long enough for the "premium" feel.
      Future.delayed(const Duration(milliseconds: 5000)),
    ]);
    if (!mounted) return;
    final auth = ref.read(authProvider);
    context.go(auth.isAuthenticated ? '/dashboard' : '/login');
  }

  Future<void> _initialize() async {
    try {
      await ref.read(authProvider.notifier).initialize();
      final compactMode = await ref.read(appSettingsProvider).getCompactMode();
      final dashboardFeel = await ref
          .read(appSettingsProvider)
          .getDashboardFeel();
      if (mounted) {
        ref.read(compactModeProvider.notifier).setValue(compactMode);
        ref.read(dashboardFeelProvider.notifier).setValue(dashboardFeel);
      }
      // ignore: discarded_futures
      CleanupService.instance.runIfNeeded(ref.read(appSettingsProvider));
      // Check for forced app updates (best-effort; failures are logged).
      if (mounted) {
        // Use a timeout to prevent the splash screen from hanging if the server is slow.
        await VersionCheckService(ref.read(apiClientProvider))
            .check(context)
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () => debugPrint('[SPLASH] Version check timed out'),
            );
      }
    } catch (_) {
      // Keep defaults on error — app proceeds to login.
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    final backgroundColor = isDark ? DSColors.scaffoldDark : DSColors.white;
    final backgroundEndColor = isDark ? DSColors.cardDark : DSColors.white;
    final textColor = isDark ? DSColors.white : DSColors.labelPrimary;
    final subtitleColor = (isDark ? DSColors.white : DSColors.labelPrimary)
        .withValues(alpha: DSStyles.alphaMuted);

    // Apply system UI overlay style to match the splash theme immediately.
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: DSColors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: backgroundEndColor,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background Gradient (Fades in) ──────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [backgroundColor, backgroundEndColor],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ).animate().fadeIn(duration: DSAnimations.dSlow),

          // ── Center Brand ───────────────────────────────────────────────────
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo Container (Netflix-style zoom entry)
                  Container(
                        width: DSIconSize.heroLg,
                        height: DSIconSize.heroLg,
                        padding: const EdgeInsets.all(DSSpacing.md),
                        decoration: BoxDecoration(
                          color: isDark
                              ? DSColors.cardElevatedDark
                              : DSColors.white,
                          borderRadius: DSStyles.sheetRadius,
                          boxShadow: DSStyles.shadowXL(context),
                        ),
                        child: Image.asset(
                          'assets/android-chrome-512x512.png',
                          fit: BoxFit.contain,
                        ),
                      )
                      .animate()
                      .scale(
                        begin: const Offset(0.8, 0.8),
                        end: const Offset(1.0, 1.0),
                        duration: DSAnimations.dSlow,
                        curve: Curves.easeOutBack,
                      )
                      .fadeIn(duration: DSAnimations.dNormal),

                  DSSpacing.hXl,

                  // App Name (Staggered entrance)
                  Text(
                        'splash.title'.tr(),
                        style: DSTypography.display(color: textColor).copyWith(
                          fontSize: DSTypography.sizeHero,
                          letterSpacing: DSTypography.lsExtraLoose * 5,
                        ),
                      )
                      .animate()
                      .fadeIn(delay: 400.ms, duration: 600.ms)
                      .slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuad),

                  DSSpacing.hSm,

                  // Tagline
                  Text(
                    'splash.tagline'.tr(),
                    style: DSTypography.label(color: subtitleColor),
                  ).animate().fadeIn(delay: 600.ms, duration: 600.ms),

                  DSSpacing.hXl,
                  DSSpacing.hLg,

                  // Feature chips
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DSSpacing.md,
                    ),
                    child: Wrap(
                      spacing: DSSpacing.md,
                      runSpacing: DSSpacing.md,
                      alignment: WrapAlignment.center,
                      children: [
                        _SplashChip(
                              icon: LucideIcons.truck,
                              label: 'splash.feature.accept'.tr(),
                            )
                            .animate()
                            .fadeIn(delay: 800.ms)
                            .scale(begin: const Offset(0.9, 0.9)),
                        _SplashChip(
                              icon: LucideIcons.package,
                              label: 'splash.feature.deliver'.tr(),
                            )
                            .animate()
                            .fadeIn(delay: 950.ms)
                            .scale(begin: const Offset(0.9, 0.9)),
                        _SplashChip(
                              icon: LucideIcons.wallet,
                              label: 'splash.feature.payout'.tr(),
                            )
                            .animate()
                            .fadeIn(delay: 1100.ms)
                            .scale(begin: const Offset(0.9, 0.9)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Footer ─────────────────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: DSSpacing.xl,
            child: Column(
              children: [
                const SpinKitThreeBounce(
                  color: DSColors.primary,
                  size: DSIconSize.md,
                ).animate().fadeIn(delay: 1300.ms),
                DSSpacing.hLg,
                Text(
                  'splash.footer_brand'.tr(),
                  style: DSTypography.caption(
                    color: subtitleColor,
                  ).copyWith(fontWeight: FontWeight.w600, letterSpacing: 1.2),
                ).animate().fadeIn(delay: 1500.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashChip extends StatelessWidget {
  const _SplashChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 100, // Fixed width for consistent grid look
      padding: const EdgeInsets.symmetric(
        vertical: DSSpacing.md,
        horizontal: DSSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: (isDark ? DSColors.white : DSColors.primary).withValues(
          alpha: DSStyles.alphaSoft,
        ),
        borderRadius: DSStyles.cardRadius,
        border: Border.all(
          color: (isDark ? DSColors.white : DSColors.primary).withValues(
            alpha: DSStyles.alphaSubtle,
          ),
          width: DSStyles.borderWidth,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: DSColors.primary, size: DSIconSize.md),
          DSSpacing.hXs,
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DSTypography.label(
              color: isDark ? DSColors.white : DSColors.labelPrimary,
            ).copyWith(fontSize: 10, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}
