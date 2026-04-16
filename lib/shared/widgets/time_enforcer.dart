// DOCS: docs/time-enforcement.md

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/connectivity_provider.dart';
import '../../core/services/platform_settings.dart';
import '../../core/services/time_validation_service.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

/// How often to re-validate while the app is in the foreground.
const _kPeriodicInterval = Duration(minutes: 5);

// EventChannel pushed by native code whenever ACTION_TIME_CHANGED,
// ACTION_TIMEZONE_CHANGED (Android) or NSSystemClockDidChangeNotification
// (iOS) fires — so the app reacts the moment the user tampers with the clock.
const _kTimeChangeChannel = EventChannel('fsi_courier/time_changes');

/// Widget that enforces Philippine Standard Time (UTC+8 / Asia/Manila).
///
/// Shows a full-screen loading indicator during the initial check, then
/// either renders [child] normally (valid) or overlays a blocking card
/// (invalid) that guides the user to correct their device time.
///
/// Re-validation is triggered automatically on:
/// - App startup (first frame)
/// - Device clock or timezone changed (via native EventChannel — immediate)
/// - App resume from background
/// - Connectivity restored (offline → online)
/// - Periodic timer (every [_kPeriodicInterval])
class TimeEnforcer extends ConsumerStatefulWidget {
  const TimeEnforcer({super.key, required this.child, this.allowedSkew});

  final Widget child;
  final Duration? allowedSkew;

  @override
  ConsumerState<TimeEnforcer> createState() => _TimeEnforcerState();
}

class _TimeEnforcerState extends ConsumerState<TimeEnforcer>
    with WidgetsBindingObserver {
  // null = still checking for the first time
  bool? _blocked;
  String _message = '';
  bool _checking = false;
  Timer? _periodicTimer;
  StreamSubscription<dynamic>? _timeChangeSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _validate();
      _startPeriodicTimer();
      _subscribeToTimeChanges();
    });
  }

  @override
  void dispose() {
    _timeChangeSub?.cancel();
    _periodicTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Listens for native clock/timezone change events and re-validates
  /// immediately — no waiting for the periodic timer or app resume.
  void _subscribeToTimeChanges() {
    _timeChangeSub = _kTimeChangeChannel.receiveBroadcastStream().listen(
      (_) {
        TimeValidationService.instance.invalidateCache();
        _validate();
      },
      onError: (e) {
        // Channel unavailable — native code not yet compiled (full rebuild
        // needed after adding Kotlin/Swift EventChannel), or unsupported
        // platform. Periodic timer + app-resume triggers remain active.
        debugPrint('[TIME] time_changes channel unavailable: $e');
      },
    );
  }

  // Re-validate when app comes back to foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _validate();
    } else if (state == AppLifecycleState.paused) {
      _periodicTimer?.cancel();
    }
  }

  void _startPeriodicTimer() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(_kPeriodicInterval, (_) => _validate());
  }

  Future<void> _validate() async {
    if (!mounted) return;
    if (_checking) return;
    setState(() => _checking = true);

    // Invalidate cache so a fresh NTP check always runs after the user has
    // corrected their device time and tapped Retry.
    if (_blocked == true) TimeValidationService.instance.invalidateCache();

    final isOnline = ref.read(isOnlineProvider);
    final res = await TimeValidationService.instance.validate(
      isOnline: isOnline,
      allowedSkew: widget.allowedSkew ?? const Duration(seconds: 30),
    );

    if (!mounted) return;
    setState(() {
      _checking = false;
      _blocked = !res.valid;
      _message = res.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Re-validate whenever connectivity is restored.
    ref.listen<bool>(isOnlineProvider, (previous, current) {
      if (previous == false && current == true) _validate();
    });

    // ── Still on initial check – show branded loading screen ─────────────────
    if (_blocked == null) {
      return _LoadingScreen(checking: _checking);
    }

    // ── Valid – show the app normally ────────────────────────────────────────
    if (_blocked == false) return widget.child;

    // ── Invalid – overlay a blocking card ────────────────────────────────────
    return Stack(
      children: [
        // Render child so the UI is ready once the user fixes the issue.
        widget.child,
        Positioned.fill(
          child: _BlockingOverlay(
            message: _message,
            checking: _checking,
            onRetry: _validate,
          ),
        ),
      ],
    );
  }
}

// ── Loading screen ────────────────────────────────────────────────────────────

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({required this.checking});
  final bool checking;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? DSColors.scaffoldDark : DSColors.scaffoldLight,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: DSColors.primary,
              strokeWidth: 2.5,
            ),
            const SizedBox(height: 16),
            Text(
              'Verifying device time…',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark
                    ? DSColors.labelSecondaryDark
                    : DSColors.labelSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Blocking overlay card ─────────────────────────────────────────────────────

class _BlockingOverlay extends StatelessWidget {
  const _BlockingOverlay({
    required this.message,
    required this.checking,
    required this.onRetry,
  });

  final String message;
  final bool checking;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: isDark ? DSColors.cardDark : DSColors.cardLight,
              borderRadius: DSStyles.cardRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon badge
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: DSColors.red.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.access_time_filled_rounded,
                    color: DSColors.red,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Incorrect Device Time',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'This app requires Philippine Standard Time (UTC+8).',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? DSColors.labelSecondaryDark
                        : DSColors.labelSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? DSColors.red.withValues(alpha: 0.08)
                        : DSColors.red.withValues(alpha: 0.06),
                    borderRadius: DSStyles.pillRadius,
                    border: Border.all(
                      color: DSColors.red.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: DSColors.red,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _openSettings,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: DSColors.primary.withValues(alpha: 0.6),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: DSStyles.cardRadius,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Open Settings'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: checking ? null : onRetry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DSColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: DSStyles.cardRadius,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: checking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Retry'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Enable "Automatic date & time" and set timezone to Asia/Manila.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? DSColors.labelSecondaryDark
                        : DSColors.labelSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openSettings() => PlatformSettings.openDateTimeSettings();
}
