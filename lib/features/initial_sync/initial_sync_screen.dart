// DOCS: docs/development-standards.md
// DOCS: docs/features/initial-sync.md — update that file when you edit this one.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/auth/auth_storage.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/core/sync/delivery_bootstrap_service.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/features/initial_sync/widgets/sync_ai_visuals.dart';

/// Post-login setup gate — loads deliveries onto the phone before dashboard.
///
/// Visual language is a modern loader (orb + steps), not splash marketing.
/// All courier-facing copy stays plain delivery English.
class InitialSyncScreen extends ConsumerStatefulWidget {
  const InitialSyncScreen({super.key});

  @override
  ConsumerState<InitialSyncScreen> createState() => _InitialSyncScreenState();
}

class _InitialSyncScreenState extends ConsumerState<InitialSyncScreen> {
  String _progressText = 'Getting ready...';
  bool _done = false;
  bool _canContinue = false;
  bool _isNavigating = false;
  int _countdown = 3;
  Completer<void>? _animationCompleter;

  /// Tech-tinted scenery: particles + orbs, no marketing waves.
  static final _backdropConfig = DsBrandBackdropConfig.auth.copyWith(
    showWaves: false,
    showParticles: true,
    particleCount: 14,
    opacity: 0.92,
    orbAlphaScale: 0.85,
    driftScale: 0.7,
    loopDuration: const Duration(seconds: 14),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runSync());
  }

  Future<void> _runSync() async {
    debugPrint('[InitialSync] _runSync start');
    final container = ProviderScope.containerOf(context, listen: false);
    final client = ref.read(apiClientProvider);
    final authStorage = ref.read(authStorageProvider);
    void onProgress(String msg) {
      debugPrint('[InitialSync] progress: $msg');
      if (mounted) setState(() => _progressText = msg);
    }

    final forDeliveryReady = Completer<void>();
    void onForDeliveryReady() {
      debugPrint('[InitialSync] FOR_DELIVERY ready — offering early continue');
      if (!forDeliveryReady.isCompleted) forDeliveryReady.complete();
    }

    final needsFullResync = await authStorage.needsFullResync();

    final syncFuture =
        (needsFullResync
                ? DeliveryBootstrapService.instance
                      .clearAndSyncFromApiWithProgress(
                        client,
                        onProgress: onProgress,
                        onForDeliveryReady: onForDeliveryReady,
                      )
                : DeliveryBootstrapService.instance.syncFromApiWithProgress(
                    client,
                    onProgress: onProgress,
                    onForDeliveryReady: onForDeliveryReady,
                  ))
            .then((_) {
              container.read(deliveryRefreshProvider.notifier).increment();
            })
            .catchError((e) {
              debugPrint('[InitialSync] sync error: $e');
            });

    await Future.any([forDeliveryReady.future, syncFuture]);

    if (!mounted) return;
    _animationCompleter = Completer<void>();
    setState(() {
      _progressText = 'Your deliveries are ready!';
      _done = true;
    });

    // Never hang if the success animation callback is skipped (rebuilds, etc.).
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        _completeSuccessAnimation();
      }),
    );
    await _animationCompleter!.future;
    if (!mounted || _isNavigating) return;

    setState(() {
      _canContinue = true;
      _countdown = 3;
    });

    // 3 → 2 → 1, then leave. Break out cleanly if user taps early.
    for (var i = 3; i >= 1; i--) {
      if (!mounted || _isNavigating) return;
      setState(() => _countdown = i);
      await Future.delayed(const Duration(seconds: 1));
    }

    if (!mounted || _isNavigating) return;
    await _onContinue();
  }

  Future<void> _onContinue() async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);
    debugPrint('[InitialSync] complete — marking initial sync done');
    try {
      await ref.read(authProvider.notifier).markInitialSyncCompleted();
      // Explicit navigation — do not rely only on router redirect refresh.
      if (mounted) context.go('/dashboard');
    } catch (e, st) {
      debugPrint('[InitialSync] markInitialSyncCompleted failed: $e\n$st');
      if (mounted) {
        setState(() => _isNavigating = false);
      }
    }
  }

  void _completeSuccessAnimation() {
    if (_animationCompleter != null && !_animationCompleter!.isCompleted) {
      _animationCompleter!.complete();
    }
  }

  void _onOrbSuccessComplete() {
    if (mounted) _completeSuccessAnimation();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark
        ? DSColors.labelPrimaryDark
        : DSColors.labelPrimary;
    final muted = isDark
        ? DSColors.labelSecondaryDark
        : DSColors.labelSecondary;
    final phase = syncPhaseFromProgress(_progressText, done: _done);

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
          DsBrandBackdrop(config: _backdropConfig),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  DSSpacing.lg,
                  DSSpacing.xl,
                  DSSpacing.lg,
                  DSSpacing.xl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Loading orb — visual only, no tech jargon in UI
                      SyncAiOrb(
                            done: _done,
                            size: 176,
                            onSuccessComplete: _onOrbSuccessComplete,
                          )
                          .animate()
                          .fadeIn(duration: DSAnimations.dSlow)
                          .scale(
                            begin: const Offset(0.85, 0.85),
                            end: const Offset(1, 1),
                            duration: DSAnimations.dHero,
                            curve: Curves.easeOutCubic,
                          ),

                      DSSpacing.hXl,

                      // Plain courier language
                      AnimatedSwitcher(
                            duration: DSAnimations.dNormal,
                            child: Text(
                              _done
                                  ? 'You\'re ready to go!'
                                  : 'Getting your deliveries ready',
                              key: ValueKey(_done),
                              textAlign: TextAlign.center,
                              style: DSTypography.heading(color: titleColor)
                                  .copyWith(
                                    fontSize: DSTypography.sizeXl,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: DSTypography.lsTight,
                                  ),
                            ),
                          )
                          .animate()
                          .fadeIn(delay: 100.ms, duration: DSAnimations.dNormal)
                          .slideY(
                            begin: 0.12,
                            end: 0,
                            delay: 100.ms,
                            duration: DSAnimations.dNormal,
                          ),

                      DSSpacing.hXs,

                      Text(
                        _done
                            ? 'You can start your deliveries on this phone'
                            : 'Please wait a moment — this only happens once',
                        textAlign: TextAlign.center,
                        style: DSTypography.body(
                          color: muted,
                        ).copyWith(fontSize: DSTypography.sizeMd),
                      ).animate().fadeIn(
                        delay: 180.ms,
                        duration: DSAnimations.dNormal,
                      ),

                      DSSpacing.hXl,

                      // ── Phase rail ─────────────────────────────────────
                      SyncAiPhaseRail(active: phase)
                          .animate()
                          .fadeIn(delay: 220.ms, duration: DSAnimations.dNormal)
                          .slideY(
                            begin: 0.1,
                            end: 0,
                            delay: 220.ms,
                            duration: DSAnimations.dNormal,
                          ),

                      DSSpacing.hLg,

                      // ── Live stream status ─────────────────────────────
                      SyncAiStatusStream(
                        message: _progressText,
                        done: _done,
                      ).animate().fadeIn(
                        delay: 280.ms,
                        duration: DSAnimations.dNormal,
                      ),

                      DSSpacing.hXl,

                      // ── CTA ────────────────────────────────────────────
                      if (_done && _canContinue)
                        _SyncContinueButton(
                              countdown: _countdown,
                              loading: _isNavigating,
                              onPressed: _onContinue,
                            )
                            .animate()
                            .fadeIn(duration: DSAnimations.dNormal)
                            .slideY(
                              begin: 0.15,
                              end: 0,
                              duration: DSAnimations.dNormal,
                              curve: Curves.easeOutCubic,
                            )
                            .scale(
                              begin: const Offset(0.96, 0.96),
                              end: const Offset(1, 1),
                              duration: DSAnimations.dNormal,
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncContinueButton extends StatelessWidget {
  const _SyncContinueButton({
    required this.countdown,
    required this.loading,
    required this.onPressed,
  });

  final int countdown;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DSStyles.radiusXL),
        boxShadow: [
          BoxShadow(
            color: DSColors.primary.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: DSColors.transparent,
        child: InkWell(
          onTap: loading ? null : onPressed,
          borderRadius: BorderRadius.circular(DSStyles.radiusXL),
          child: Ink(
            height: 52,
            decoration: BoxDecoration(
              gradient: DSColors.primaryGradient,
              borderRadius: BorderRadius.circular(DSStyles.radiusXL),
            ),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: DSColors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: DSColors.white,
                          size: DSIconSize.md,
                        ),
                        DSSpacing.wSm,
                        Text(
                          'Start delivering ($countdown)',
                          style: DSTypography.button(color: DSColors.white)
                              .copyWith(
                                fontSize: DSTypography.sizeMd,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
