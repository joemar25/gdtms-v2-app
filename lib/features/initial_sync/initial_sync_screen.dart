// DOCS: docs/development-standards.md
// DOCS: docs/features/initial-sync.md — update that file when you edit this one.

import 'package:flutter/material.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/auth/auth_storage.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/core/sync/delivery_bootstrap_service.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

class InitialSyncScreen extends ConsumerStatefulWidget {
  const InitialSyncScreen({super.key});

  @override
  ConsumerState<InitialSyncScreen> createState() => _InitialSyncScreenState();
}

class _InitialSyncScreenState extends ConsumerState<InitialSyncScreen> {
  String _progressText = 'Preparing your data...';
  bool _done = false;
  bool _canContinue = false;
  bool _isNavigating = false;
  int _countdown = 3;
  Completer<void>? _animationCompleter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runSync());
  }

  Future<void> _runSync() async {
    debugPrint('[InitialSync] _runSync start');
    // Captured up front (not via `ref` later) so the background continuation
    // below can still signal a refresh after this screen navigates away and
    // disposes — `ref` itself becomes unusable post-dispose, but a container
    // reference grabbed before that point stays valid for the app's lifetime.
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

    // P4: only wipe + full-resweep on first install or courier/server
    // identity change (set by login_screen.dart). A same-courier re-login
    // runs the normal delta path against the still-valid local data instead
    // of throwing it all away.
    final needsFullResync = await authStorage.needsFullResync();

    // Errors are swallowed on the future itself (not a try/catch around the
    // await below) so the same handling covers both the FOR_DELIVERY-ready
    // race and the remainder finishing in the background afterward.
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
              // The dashboard/status-list screens may already be mounted by
              // the time the background remainder (FAILED_DELIVERY/
              // MISROUTED/DELIVERED/bagsakan/cleanup) finishes if FOR_DELIVERY
              // won the race below — nudge them to reload the newly-synced
              // data instead of leaving those tabs stale until some later,
              // unrelated auto-sync trigger.
              container.read(deliveryRefreshProvider.notifier).increment();
            })
            .catchError((e) {
              debugPrint('[InitialSync] sync error: $e');
              // Best-effort — allow user to proceed even if sync partially
              // or fully fails; local data (if any) is still usable offline.
            });

    // P6: let the courier continue as soon as FOR_DELIVERY — the data they
    // act on immediately — is ready, instead of blocking on
    // FAILED_DELIVERY/MISROUTED/DELIVERED/bagsakan/cleanup too. If
    // FOR_DELIVERY wins the race, `syncFuture` keeps running unawaited in
    // the background (safe: `DeliveryBootstrapService` doesn't touch this
    // screen's `ref`/`context`, its own `onProgress` calls already no-op
    // once `mounted` is false, and the refresh signal above uses the
    // container captured before disposal, not `ref`).
    await Future.any([forDeliveryReady.future, syncFuture]);

    if (!mounted) return;
    _animationCompleter = Completer<void>();
    setState(() {
      _progressText = 'All set!';
      _done = true;
    });

    // Wait exactly until the checkmark animation finishes
    await _animationCompleter!.future;

    if (!mounted) return;

    // Show the continue button so user can skip the wait
    setState(() {
      _canContinue = true;
    });

    // Auto continue about 3 seconds after it was complete
    for (int i = 3; i > 0; i--) {
      if (!mounted || _isNavigating) break;
      setState(() => _countdown = i);
      await Future.delayed(const Duration(seconds: 1));
    }

    if (!mounted) return;

    // If the user hasn't already clicked continue, do it for them.
    await _onContinue();
  }

  Future<void> _onContinue() async {
    if (_isNavigating) return;
    _isNavigating = true;

    debugPrint('[InitialSync] _runSync complete — marking initial sync done');
    // Persist the flag — the router guard will redirect to dashboard.
    await ref.read(authProvider.notifier).markInitialSyncCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: DSSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: DSIconSize.heroMd,
                  height: DSIconSize.heroMd,
                  child: _done
                      ? Icon(
                              Icons.check_circle_rounded,
                              color: DSColors.success,
                              size: DSIconSize.heroMd,
                            )
                            .animate(
                              onComplete: (controller) {
                                if (mounted &&
                                    _animationCompleter != null &&
                                    !_animationCompleter!.isCompleted) {
                                  _animationCompleter!.complete();
                                }
                              },
                            )
                            .scale(duration: 600.ms, curve: Curves.easeOutBack)
                      : const SpinKitDoubleBounce(
                          color: DSColors.primary,
                          size: DSIconSize.heroMd,
                        ),
                ),
                DSSpacing.hLg,
                Text(
                  'Setting Up Your App',
                  style: DSTypography.title(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? DSColors.labelPrimaryDark
                        : DSColors.labelPrimary,
                  ).copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                DSSpacing.hMd,
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _progressText,
                    key: ValueKey(_progressText),
                    style: DSTypography.body(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? DSColors.labelSecondaryDark
                          : DSColors.labelSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                DSSpacing.hXl,
                if (!_done)
                  LinearProgressIndicator(
                    borderRadius: DSStyles.pillRadius,
                    color: colorScheme.primary,
                    backgroundColor: colorScheme.primary.withValues(
                      alpha: DSStyles.alphaSubtle,
                    ),
                  )
                else if (_canContinue)
                  FilledButton.icon(
                    onPressed: _onContinue,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: DSSpacing.xl,
                        vertical: DSSpacing.sm,
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text('Continue ($_countdown)'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
