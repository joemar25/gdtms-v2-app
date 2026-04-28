// DOCS: docs/entry-points.md — update that file when you edit this one.

import 'package:flutter/material.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
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
      Future.delayed(const Duration(milliseconds: 2500)),
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
    return Scaffold(
      backgroundColor: DSColors.scaffoldDark,
      body: SafeArea(child: _buildContent(context)),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: DSSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Brand Card (Text-only, no logo) ──────────────────────────
            Container(
              width: DSIconSize.heroLg,
              padding: EdgeInsets.all(DSSpacing.xl),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    DSColors.primary.withValues(alpha: DSStyles.alphaOpaque),
                    DSColors.primary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: DSStyles.circularRadius,
                boxShadow: [
                  BoxShadow(
                    color: DSColors.primary.withValues(
                      alpha: DSStyles.alphaMuted,
                    ),
                    blurRadius: DSStyles.shadowBlurHero,
                    offset: const Offset(0, DSSpacing.md),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Title
                  Text(
                        'FSI COURIER',
                        textAlign: TextAlign.center,
                        style: DSTypography.heading(
                          color: DSColors.white,
                        ).copyWith(fontSize: DSTypography.sizeHero, fontWeight: FontWeight.w800),
                      )
                      .animate()
                      .fadeIn(duration: DSAnimations.dSlow)
                      .slideY(begin: DSAnimations.slideXOffset.dx, end: 0),

                  DSSpacing.hSm,

                  // Subtitle
                  Text(
                    'Delivery Management',
                    textAlign: TextAlign.center,
                    style: DSTypography.body(color: DSColors.white).copyWith(
                      fontSize: DSTypography.sizeMd,
                      fontWeight: FontWeight.w600,
                    ),
                  ).animate().fadeIn(delay: DSAnimations.staggerWide).slideY(begin: DSAnimations.slideXOffset.dx, end: 0),

                  DSSpacing.hLg,

                  // Feature chips
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child:
                              _SplashChip(
                                    icon: Icons.local_shipping_rounded,
                                    label: 'Dispatch',
                                  )
                                  .animate()
                                  .fadeIn(delay: DSAnimations.dNormal)
                                  .scaleXY(begin: DSAnimations.scaleActive, end: DSAnimations.scaleNormal),
                        ),
                        DSSpacing.wSm,
                        Expanded(
                          child:
                              _SplashChip(
                                    icon: Icons.inventory_2_rounded,
                                    label: 'Delivery',
                                  )
                                  .animate()
                                  .fadeIn(delay: DSAnimations.stagger(5))
                                  .scaleXY(begin: DSAnimations.scaleActive, end: DSAnimations.scaleNormal),
                        ),
                        DSSpacing.wSm,
                        Expanded(
                          child:
                              _SplashChip(
                                    icon: Icons.account_balance_wallet_rounded,
                                    label: 'Wallet',
                                  )
                                  .animate()
                                  .fadeIn(delay: DSAnimations.dSlow)
                                  .scaleXY(begin: DSAnimations.scaleActive, end: DSAnimations.scaleNormal),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: DSAnimations.dHero).slideY(begin: DSAnimations.slideYOffset.dy, end: 0),

            DSSpacing.hXl,
            DSSpacing.hXl,

            // ── Loading indicator ────────────────────────────────────────
            SizedBox(
              width: DSIconSize.heroSm,
              height: DSIconSize.heroSm,
              child: const SpinKitFadingCircle(color: DSColors.white, size: DSIconSize.heroSm),
            ).animate().fadeIn(delay: DSAnimations.dHero),

            DSSpacing.hLg,

            Text(
              'Fastrak Services Inc.',
              style: DSTypography.caption(
                color: DSColors.white.withValues(alpha: DSStyles.alphaMuted),
              ).copyWith(fontSize: DSTypography.sizeSm),
            ).animate().fadeIn(delay: DSAnimations.staggerLong),
          ],
        ),
      ),
    );
  }
}

// ── Chip widget ───────────────────────────────────────────────────────────────

class _SplashChip extends StatelessWidget {
  const _SplashChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: DSSpacing.md,
        horizontal: DSSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: DSColors.white.withValues(alpha: DSStyles.alphaSubtle),
        borderRadius: DSStyles.cardRadius,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: DSColors.white, size: DSIconSize.sm),
          DSSpacing.hXs,
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DSTypography.label(color: DSColors.white).copyWith(
              fontSize: DSTypography.sizeXs,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
