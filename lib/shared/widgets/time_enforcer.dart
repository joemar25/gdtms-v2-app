// DOCS: docs/development-standards.md
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

    if (!mounted) return;
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
              strokeWidth: DSStyles.strokeWidth,
            ),
            DSSpacing.hMd,
            Text(
              'Verifying device time…',
              style: DSTypography.caption(
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
      color: DSColors.black.withValues(alpha: DSStyles.alphaDisabled),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: DSSpacing.lg),
            decoration: BoxDecoration(
              color: isDark ? DSColors.cardDark : DSColors.cardLight,
              borderRadius: DSStyles.cardRadius,
              boxShadow: [
                BoxShadow(
                  color: DSColors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                  blurRadius: DSStyles.radiusXL,
                  offset: const Offset(0, DSSpacing.sm),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(
              horizontal: DSSpacing.xl,
              vertical: 28,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon badge
                Container(
                  width: DSIconSize.heroMd,
                  height: DSIconSize.heroMd,
                  decoration: BoxDecoration(
                    color: DSColors.error.withValues(
                      alpha: DSStyles.alphaSubtle,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.access_time_filled_rounded,
                    color: DSColors.error,
                    size: DSIconSize.xl,
                  ),
                ),
                DSSpacing.hMd,
                Text(
                  'Incorrect Device Time',
                  style: DSTypography.heading().copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                DSSpacing.hSm,
                Text(
                  'This app requires Philippine Standard Time (UTC+8).',
                  style: DSTypography.body(
                    color: isDark
                        ? DSColors.labelSecondaryDark
                        : DSColors.labelSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                DSSpacing.hMd,
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(DSSpacing.md),
                  decoration: BoxDecoration(
                    color: isDark
                        ? DSColors.error.withValues(alpha: DSStyles.alphaSubtle)
                        : DSColors.error.withValues(alpha: DSStyles.alphaSoft),
                    borderRadius: DSStyles.pillRadius,
                    border: Border.all(
                      color: DSColors.error.withValues(
                        alpha: DSStyles.alphaMuted,
                      ),
                    ),
                  ),
                  child: Text(
                    message,
                    style: DSTypography.caption(
                      color: DSColors.error,
                    ).copyWith(fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),
                DSSpacing.hLg,
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _openSettings,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: DSColors.primary.withValues(
                              alpha: DSStyles.alphaDisabled,
                            ),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: DSStyles.cardRadius,
                          ),
                          padding: EdgeInsets.symmetric(vertical: DSSpacing.md),
                        ),
                        child: const Text('Open Settings'),
                      ),
                    ),
                    DSSpacing.wMd,
                    Expanded(
                      child: ElevatedButton(
                        onPressed: checking ? null : onRetry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DSColors.primary,
                          foregroundColor: DSColors.white,
                          elevation: DSStyles.elevationNone,
                          shape: RoundedRectangleBorder(
                            borderRadius: DSStyles.cardRadius,
                          ),
                          padding: EdgeInsets.symmetric(vertical: DSSpacing.md),
                        ),
                        child: checking
                            ? const SizedBox(
                                width: DSIconSize.lg,
                                height: DSIconSize.lg,
                                child: CircularProgressIndicator(
                                  strokeWidth: DSStyles.strokeWidth,
                                  color: DSColors.white,
                                ),
                              )
                            : const Text('Retry'),
                      ),
                    ),
                  ],
                ),
                DSSpacing.hSm,
                Text(
                  'Enable "Automatic date & time" and set timezone to Asia/Manila.',
                  style: DSTypography.caption(
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
