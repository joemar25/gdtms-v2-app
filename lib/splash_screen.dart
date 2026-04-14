// DOCS: docs/entry-points.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/styles/ui_styles.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/database/cleanup_service.dart';
import 'package:fsi_courier_app/core/services/version_check_service.dart';
import 'package:fsi_courier_app/core/settings/app_settings.dart';
import 'package:fsi_courier_app/core/settings/compact_mode_provider.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';

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
      backgroundColor: ColorStyles.grabSurfaceDark,
      body: SafeArea(child: _buildContent(context)),
    );
  }

  Widget _buildContent(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardHorizontalPadding = screenWidth < 360 ? 20.0 : 28.0;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Brand Card ───────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(cardHorizontalPadding),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00B14F), Color(0xFF007A36)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: UIStyles.circularRadius,
                boxShadow: [
                  BoxShadow(
                    color: ColorStyles.grabGreen.withValues(
                      alpha: UIStyles.alphaBorder,
                    ),
                    blurRadius: 40,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon + name row
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: UIStyles.alphaActiveAccent,
                          ),
                          borderRadius: UIStyles.cardRadius,
                        ),
                        child: ClipRRect(
                          borderRadius: UIStyles.cardRadius,
                          child: Image.asset(
                            'assets/icon.png',
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ).animate().scale(
                        duration: 600.ms,
                        curve: Curves.easeOutBack,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                  'FSI COURIER',
                                  style: TextStyle(
                                    color: Colors.white.withValues(
                                      alpha: UIStyles.alphaGlass,
                                    ),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5,
                                  ),
                                )
                                .animate()
                                .fadeIn(delay: 200.ms)
                                .slideX(begin: 0.2, end: 0),
                            const Text(
                                  'Delivery Management',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                                .animate()
                                .fadeIn(delay: 300.ms)
                                .slideX(begin: 0.2, end: 0),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Feature chips — vertical layout avoids overflow on any screen
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
                        const SizedBox(width: 8),
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
                        const SizedBox(width: 8),
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
            const SizedBox(height: 44),

            // ── Loading indicator ────────────────────────────────────────
            SizedBox(
              width: 80,
              height: 80,
              child: Lottie.asset(
                'assets/anim/hour-glass.json',
                fit: BoxFit.contain,
              ),
            ).animate().fadeIn(delay: 800.ms),
            const SizedBox(height: 18),
            Text(
              'Fastrak Services Inc.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: UIStyles.alphaDarkShadow),
                fontSize: 12,
                letterSpacing: 0.5,
              ),
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
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: UIStyles.alphaActiveAccent),
        borderRadius: UIStyles.cardRadius,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
