// DOCS: docs/features/initial-sync.md — update that file when you edit this one.

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:lottie/lottie.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/constants.dart';
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
    setState(() {
      _progressText = 'All set!';
      _done = true;
    });

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

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
                  width: DSIconSize.xl,
                  height: DSIconSize.xl,
                  child: _done
                      ? Lottie.asset(AppAssets.animSuccess, repeat: false)
                      : const SpinKitDoubleBounce(
                          color: DSColors.primary,
                          size: DSIconSize.heroLg,
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
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
