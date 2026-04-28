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
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Brand Card (Text-only, no logo) ──────────────────────────
            Container(
              width: 240,
              padding: const EdgeInsets.all(DSSpacing.xl),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    DSColors.primary.withValues(alpha: 0.9),
                    DSColors.primary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: DSStyles.circularRadius,
                boxShadow: [
                  BoxShadow(
                    color: DSColors.primary.withValues(
                      alpha: DSStyles.alphaBorder,
                    ),
                    blurRadius: 40,
                    offset: const Offset(0, 12),
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
                          color: Colors.white,
                        ).copyWith(fontSize: 28, fontWeight: FontWeight.w800),
                      )
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 6),

                  // Subtitle
                  Text(
                    'Delivery Management',
                    textAlign: TextAlign.center,
                    style: DSTypography.body(color: Colors.white).copyWith(
                      fontSize: DSTypography.sizeMd,
                      fontWeight: FontWeight.w600,
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 20),

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
                                  .fadeIn(delay: 400.ms)
                                  .scaleXY(begin: 0.8, end: 1),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child:
                              _SplashChip(
                                    icon: Icons.inventory_2_rounded,
                                    label: 'Delivery',
                                  )
                                  .animate()
                                  .fadeIn(delay: 500.ms)
                                  .scaleXY(begin: 0.8, end: 1),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child:
                              _SplashChip(
                                    icon: Icons.account_balance_wallet_rounded,
                                    label: 'Wallet',
                                  )
                                  .animate()
                                  .fadeIn(delay: 600.ms)
                                  .scaleXY(begin: 0.8, end: 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.05, end: 0),

            const SizedBox(height: 52),

            // ── Loading indicator ────────────────────────────────────────
            SizedBox(
              width: 56,
              height: 56,
              child: const SpinKitFadingCircle(color: Colors.white, size: 56),
            ).animate().fadeIn(delay: 800.ms),

            const SizedBox(height: 20),

            Text(
              'Fastrak Services Inc.',
              style: DSTypography.caption(
                color: Colors.white.withValues(alpha: DSStyles.alphaDarkShadow),
              ).copyWith(fontSize: DSTypography.sizeSm),
            ).animate().fadeIn(delay: 1000.ms),
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
      padding: const EdgeInsets.symmetric(
        vertical: DSSpacing.md,
        horizontal: DSSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: DSStyles.alphaActiveAccent),
        borderRadius: DSStyles.cardRadius,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DSTypography.label(color: Colors.white).copyWith(
              fontSize: DSTypography.sizeXs,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
