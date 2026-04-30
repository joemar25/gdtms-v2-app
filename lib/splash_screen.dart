// DOCS: docs/development-standards.md
// DOCS: docs/entry-points.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/database/cleanup_service.dart';
import 'package:fsi_courier_app/core/services/version_check_service.dart';
import 'package:fsi_courier_app/core/settings/app_settings.dart';
import 'package:fsi_courier_app/core/settings/compact_mode_provider.dart';
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
      if (mounted) ref.read(compactModeProvider.notifier).setValue(compactMode);
      // ignore: discarded_futures
      CleanupService.instance.runIfNeeded(ref.read(appSettingsProvider));
      // Check for forced app updates (best-effort; failures are logged).
      if (mounted) {
        await VersionCheckService(ref.read(apiClientProvider)).check(context);
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background Gradient ────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [backgroundColor, backgroundEndColor],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // ── Center Brand ───────────────────────────────────────────────────
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo Container (Actual App Brand)
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
                  ).dsHeroEntry(),

                  DSSpacing.hXl,

                  // App Name
                  Text(
                    'splash.title'.tr(),
                    style: DSTypography.display(color: textColor).copyWith(
                      fontSize: DSTypography.sizeHero,
                      letterSpacing: DSTypography.lsExtraLoose * 5,
                    ),
                  ).dsFadeEntry(delay: DSAnimations.stagger(2)),

                  DSSpacing.hSm,

                  // Tagline
                  Text(
                    'splash.tagline'.tr(),
                    style: DSTypography.label(color: subtitleColor),
                  ).dsFadeEntry(delay: DSAnimations.stagger(4)),

                  DSSpacing.hXl,
                  DSSpacing.hLg,

                  // Feature chips (Refined to prevent overflow)
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
                        ).dsCardEntry(delay: DSAnimations.stagger(6)),
                        _SplashChip(
                          icon: LucideIcons.package,
                          label: 'splash.feature.deliver'.tr(),
                        ).dsCardEntry(delay: DSAnimations.stagger(8)),
                        _SplashChip(
                          icon: LucideIcons.wallet,
                          label: 'splash.feature.payout'.tr(),
                        ).dsCardEntry(delay: DSAnimations.stagger(10)),
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
                ).dsFadeEntry(delay: DSAnimations.stagger(12)),
                DSSpacing.hLg,
                Text(
                  'splash.footer_brand'.tr(),
                  style: DSTypography.caption(
                    color: subtitleColor,
                  ).copyWith(fontWeight: FontWeight.w600, letterSpacing: 1.2),
                ).dsFadeEntry(delay: DSAnimations.stagger(15)),
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
