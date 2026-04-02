import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/sync/delivery_bootstrap_service.dart';

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
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: _done
                      ? Lottie.asset(
                          'assets/anim/successfully-done.json',
                          repeat: false,
                        )
                      : Lottie.asset(
                          'assets/anim/hour-glass.json',
                          repeat: true,
                        ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Setting Up Your App',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _progressText,
                    key: ValueKey(_progressText),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),
                if (!_done)
                  LinearProgressIndicator(
                    borderRadius: BorderRadius.circular(4),
                    color: colorScheme.primary,
                    backgroundColor: colorScheme.primary.withValues(
                      alpha: 0.15,
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
