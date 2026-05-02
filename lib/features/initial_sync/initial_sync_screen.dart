// DOCS: docs/development-standards.md
// DOCS: docs/features/initial-sync.md — update that file when you edit this one.

import 'package:flutter/material.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
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
  Completer<void>? _animationCompleter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runSync());
  }

  Future<void> _runSync() async {
    debugPrint('[InitialSync] _runSync start');
    final client = ref.read(apiClientProvider);
    try {
      await DeliveryBootstrapService.instance.clearAndSyncFromApiWithProgress(
        client,
        onProgress: (msg) {
          debugPrint('[InitialSync] progress: $msg');
          if (mounted) setState(() => _progressText = msg);
        },
      );
    } catch (e) {
      debugPrint('[InitialSync] sync error: $e');
      // Best-effort — allow user to proceed even if sync partially fails.
    }

    if (!mounted) return;
    _animationCompleter = Completer<void>();
    setState(() {
      _progressText = 'All set!';
      _done = true;
    });

    // Wait exactly until the Lottie animation finishes
    await _animationCompleter!.future;
    // Add a tiny extra pause for UX
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    // Show the continue button instead of auto-navigating
    setState(() {
      _canContinue = true;
    });
  }

  Future<void> _onContinue() async {
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
                    label: const Text('Continue'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
