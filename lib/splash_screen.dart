// DOCS: docs/development-standards.md
// DOCS: docs/entry-points.md — update that file when you edit this one.

import 'package:flutter/material.dart';

import 'package:flutter_animate/flutter_animate.dart';
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
      Future.delayed(const Duration(milliseconds: 10000)),
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

    final backgroundColor =
        isDark ? DSColors.scaffoldDark : const Color(0xFFF1F5F9);
    final backgroundEndColor = isDark ? const Color(0xFF0F172A) : DSColors.white;
    final textColor = isDark ? DSColors.white : DSColors.labelPrimary;
    final subtitleColor =
        (isDark ? DSColors.white : DSColors.labelPrimary).withValues(
          alpha: DSStyles.alphaMuted,
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
                      color:
                          isDark ? DSColors.cardElevatedDark : DSColors.white,
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
                    'FSI COURIER',
                    style: DSTypography.display(color: textColor).copyWith(
                      fontSize: 32,
                      letterSpacing: 4.0,
                    ),
                  ).dsFadeEntry(delay: DSAnimations.stagger(2)),

                  DSSpacing.hSm,

                  // Tagline
                  Text(
                    'SMART LOGISTICS • REAL-TIME DELIVERY',
                    style: DSTypography.label(color: subtitleColor),
                  ).dsFadeEntry(delay: DSAnimations.stagger(4)),

                  DSSpacing.hXl,
                  DSSpacing.hLg,

                  // Feature chips (Reused but refined)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SplashChip(
                        icon: LucideIcons.truck,
                        label: 'Accept',
                      ).dsCardEntry(delay: DSAnimations.stagger(6)),
                      DSSpacing.wMd,
                      _SplashChip(
                        icon: LucideIcons.package,
                        label: 'Deliver',
                      ).dsCardEntry(delay: DSAnimations.stagger(8)),
                      DSSpacing.wMd,
                      _SplashChip(
                        icon: LucideIcons.wallet,
                        label: 'Request Payout',
                      ).dsCardEntry(delay: DSAnimations.stagger(10)),
                    ],
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
                  'Fastrak Services Inc.',
                  style: DSTypography.caption(color: subtitleColor).copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
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
      padding: EdgeInsets.symmetric(
        vertical: DSSpacing.md,
        horizontal: DSSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: (isDark ? DSColors.white : DSColors.primary).withValues(
          alpha: 0.05,
        ),
        borderRadius: DSStyles.cardRadius,
        border: Border.all(
          color: (isDark ? DSColors.white : DSColors.primary).withValues(
            alpha: 0.1,
          ),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: DSColors.primary, size: DSIconSize.md),
          DSSpacing.hXs,
          Text(
            label,
            style: DSTypography.label(
              color: isDark ? DSColors.white : DSColors.labelPrimary,
            ).copyWith(fontSize: 10, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}


