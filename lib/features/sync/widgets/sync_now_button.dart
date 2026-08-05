// DOCS: docs/development-standards.md
// DOCS: docs/features/sync-history.md — update that file when you edit this one.

import 'dart:async' show unawaited;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fsi_courier_app/core/providers/sync_provider.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/features/initial_sync/widgets/sync_ai_visuals.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';

/// Visual variant for [SyncNowButton].
enum SyncNowButtonVariant {
  /// Transparent background, primary-coloured text — used in the sync
  /// history header.
  text,

  /// White filled pill, primary-coloured text — used inside the
  /// dashboard's green sync card.
  filled,
}

/// A dedicated "Sync Now" entry-point that can be placed anywhere in the app.
///
/// Tapping it:
/// 1. Kicks off [SyncManagerNotifier.requestFlush] immediately.
/// 2. Shows [SyncOverlay] — fullscreen loader matching [InitialSyncScreen]
///    (brand backdrop, orb, phase rail, status stream).
/// 3. Auto-dismisses after a short success countdown (or OK tap).
///
/// When [isOnline] is `false` the button is hidden entirely (returns
/// [SizedBox.shrink]).
///
/// Use [variant] to switch between the `text` style (sync history header)
/// and the `filled` style (dashboard green card).
class SyncNowButton extends ConsumerWidget {
  const SyncNowButton({
    super.key,
    required this.isOnline,
    this.variant = SyncNowButtonVariant.text,
  });

  final bool isOnline;

  /// Controls the visual style of the button. Defaults to [SyncNowButtonVariant.text].
  final SyncNowButtonVariant variant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isOnline) return const SizedBox.shrink();

    final syncState = ref.watch(syncManagerProvider);
    final isSyncing = syncState.isSyncing;

    final isFilled = variant == SyncNowButtonVariant.filled;
    final fgColor = isFilled
        ? (isSyncing
              ? DSColors.primary.withValues(alpha: 0.5)
              : DSColors.primary)
        : DSColors.primary;

    final icon = isSyncing
        ? const Icon(Icons.sync_rounded, size: 14)
              .animate(onPlay: (c) => c.repeat())
              .rotate(duration: const Duration(milliseconds: 1000))
        : const Icon(Icons.sync_rounded, size: 14);

    final label = Text(
      isSyncing
          ? 'sync.actions.syncing'.tr().toUpperCase()
          : 'sync.actions.sync_now'.tr().toUpperCase(),
      style: DSTypography.button(color: fgColor, fontSize: 12),
    );

    if (isFilled) {
      return TextButton.icon(
        onPressed: isSyncing ? null : () => _openSyncSheet(context, ref),
        style: TextButton.styleFrom(
          backgroundColor: DSColors.white,
          foregroundColor: fgColor,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: DSSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DSStyles.radiusMD),
          ),
        ),
        icon: icon,
        label: label,
      );
    }

    // Default: text variant
    return TextButton.icon(
      onPressed: isSyncing ? null : () => _openSyncSheet(context, ref),
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: DSSpacing.sm,
          vertical: DSSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DSStyles.radiusSM),
        ),
        foregroundColor: DSColors.primary,
      ),
      icon: icon,
      label: label,
    );
  }

  Future<void> _openSyncSheet(BuildContext context, WidgetRef ref) async {
    await showSyncOverlay(context, ref);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Public helper — call this directly when you need to trigger the sync sheet
// without going through the SyncNowButton widget (e.g., dashboard actions).
// ─────────────────────────────────────────────────────────────────────────────

/// Starts a coalesced [SyncManagerNotifier.requestFlush] and shows
/// [SyncOverlay] as a fullscreen non-dismissible dialog — same visual
/// language as [InitialSyncScreen] (orb, phase rail, status stream).
///
/// Use this directly in any [ConsumerWidget] instead of embedding
/// [SyncNowButton] when gesture-arena conflicts would be an issue
/// (e.g., when the button sits inside another tappable container).
Future<void> showSyncOverlay(BuildContext context, WidgetRef ref) async {
  // Kick off the queue before showing the overlay so progress is live.
  unawaited(
    ref
        .read(syncManagerProvider.notifier)
        .requestFlush(reason: 'sync_now_overlay', awaitIdle: false),
  );

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    // Backdrop paints the brand surface; keep barrier clear.
    barrierColor: DSColors.transparent,
    useSafeArea: false,
    builder: (_) => const SyncOverlay(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Fullscreen overlay (matches initial sync visual language)
// ─────────────────────────────────────────────────────────────────────────────

/// Fullscreen overlay that shows live sync progress and prevents
/// interaction. Same loader UI as post-login [InitialSyncScreen].
/// Auto-closes after a short success countdown (or OK tap).
///
/// Use [showSyncOverlay] to present this overlay from any [ConsumerWidget].
class SyncOverlay extends ConsumerStatefulWidget {
  const SyncOverlay({super.key});

  @override
  ConsumerState<SyncOverlay> createState() => _SyncOverlayState();
}

class _SyncOverlayState extends ConsumerState<SyncOverlay> {
  /// Keep the loader visible briefly even if the queue is already empty.
  bool _minVisualSyncing = true;
  int _countdown = 3;
  bool _isNavigating = false;
  bool _countdownStarted = false;
  bool _doneVisual = false;

  /// Same scenery language as [InitialSyncScreen].
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
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _minVisualSyncing = false);
    });
  }

  Future<void> _startCountdown() async {
    for (var i = 3; i > 0; i--) {
      if (!mounted || _isNavigating) break;
      setState(() => _countdown = i);
      await Future.delayed(const Duration(seconds: 1));
    }
    if (!mounted || _isNavigating) return;
    _dismiss();
  }

  void _dismiss() {
    if (_isNavigating) return;
    _isNavigating = true;
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  String _statusMessage({
    required bool isSyncing,
    required String? lastMessage,
    required DateTime? lastSyncTime,
    required int processed,
    required int total,
  }) {
    if (isSyncing) {
      if (lastMessage != null && lastMessage.trim().isNotEmpty) {
        return lastMessage;
      }
      if (total > 0) {
        return 'Uploading $processed of $total updates…';
      }
      return 'Sending your updates…';
    }
    if (lastSyncTime != null) {
      return 'sync.status.last_sync'.tr(
        args: [formatEpoch(lastSyncTime.millisecondsSinceEpoch)],
      );
    }
    return 'sync.status.up_to_date'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncManagerProvider);
    final lastSyncTime = ref.watch(lastSyncTimeProvider);
    final isSyncing = syncState.isSyncing || _minVisualSyncing;
    final done = !isSyncing;

    if (done && !_doneVisual) {
      // Next frame so SyncAiOrb gets a clean false→true transition.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _doneVisual = true);
      });
    }

    if (done && !_countdownStarted) {
      _countdownStarted = true;
      _startCountdown();
    }

    final message = _statusMessage(
      isSyncing: isSyncing,
      lastMessage: syncState.lastMessage,
      lastSyncTime: lastSyncTime,
      processed: syncState.processed,
      total: syncState.total,
    );
    final phase = syncPhaseFromQueueProgress(
      done: done,
      message: syncState.lastMessage ?? message,
      processed: syncState.processed,
      total: syncState.total,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark
        ? DSColors.labelPrimaryDark
        : DSColors.labelPrimary;
    final muted = isDark
        ? DSColors.labelSecondaryDark
        : DSColors.labelSecondary;

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

    return PopScope(
      canPop: done,
      child: Material(
        color: DSColors.transparent,
        child: Stack(
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
                        SyncAiOrb(done: _doneVisual || done, size: 176)
                            .animate()
                            .fadeIn(duration: DSAnimations.dSlow)
                            .scale(
                              begin: const Offset(0.85, 0.85),
                              end: const Offset(1, 1),
                              duration: DSAnimations.dHero,
                              curve: Curves.easeOutCubic,
                            ),

                        DSSpacing.hXl,

                        AnimatedSwitcher(
                          duration: DSAnimations.dNormal,
                          child: Text(
                            done
                                ? 'sync.status.up_to_date'.tr()
                                : 'sync.actions.syncing'.tr(),
                            key: ValueKey(done),
                            textAlign: TextAlign.center,
                            style: DSTypography.heading(color: titleColor)
                                .copyWith(
                                  fontSize: DSTypography.sizeXl,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: DSTypography.lsTight,
                                ),
                          ),
                        ),

                        DSSpacing.hXs,

                        Text(
                          done
                              ? 'Your updates are on the server'
                              : 'Please wait — uploading local changes',
                          textAlign: TextAlign.center,
                          style: DSTypography.body(
                            color: muted,
                          ).copyWith(fontSize: DSTypography.sizeMd),
                        ),

                        DSSpacing.hXl,

                        SyncAiPhaseRail(active: phase).animate().fadeIn(
                          delay: 120.ms,
                          duration: DSAnimations.dNormal,
                        ),

                        DSSpacing.hLg,

                        SyncAiStatusStream(
                          message: message,
                          done: done,
                        ).animate().fadeIn(
                          delay: 180.ms,
                          duration: DSAnimations.dNormal,
                        ),

                        if (isSyncing && syncState.total > 0) ...[
                          DSSpacing.hMd,
                          Text(
                            '${syncState.processed} / ${syncState.total}',
                            style: DSTypography.caption(color: muted).copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: DSTypography.lsWide,
                            ),
                          ),
                        ],

                        if (done) ...[
                          DSSpacing.hXl,
                          _SyncDoneButton(
                                countdown: _countdown,
                                onPressed: _dismiss,
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
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Primary CTA matching initial-sync continue button styling.
class _SyncDoneButton extends StatelessWidget {
  const _SyncDoneButton({required this.countdown, required this.onPressed});

  final int countdown;
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
          onTap: onPressed,
          borderRadius: BorderRadius.circular(DSStyles.radiusXL),
          child: Ink(
            height: 52,
            decoration: BoxDecoration(
              gradient: DSColors.primaryGradient,
              borderRadius: BorderRadius.circular(DSStyles.radiusXL),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_rounded,
                    color: DSColors.white,
                    size: DSIconSize.md,
                  ),
                  DSSpacing.wSm,
                  Text(
                    '${'common.ok'.tr()} ($countdown)',
                    style: DSTypography.button(color: DSColors.white).copyWith(
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
