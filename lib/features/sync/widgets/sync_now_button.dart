// DOCS: docs/development-standards.md
// DOCS: docs/features/sync-history.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:fsi_courier_app/core/providers/sync_provider.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
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
/// 1. Kicks off [SyncManagerNotifier.processQueue] immediately.
/// 2. Shows [_SyncNowSheet] — a modal bottom-sheet with live progress,
///    stat chips (Pending / Synced / Failed), and a progress bar.
/// 3. Auto-dismisses the sheet once syncing completes.
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

/// Starts [SyncManagerNotifier.processQueue] and shows [SyncOverlay] as a
/// fullscreen non-dismissible dialog with live sync progress.
///
/// Use this directly in any [ConsumerWidget] instead of embedding
/// [SyncNowButton] when gesture-arena conflicts would be an issue
/// (e.g., when the button sits inside another tappable container).
Future<void> showSyncOverlay(BuildContext context, WidgetRef ref) async {
  // Kick off the queue before showing the sheet so progress is live.
  ref.read(syncManagerProvider.notifier).processQueue();

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.85),
    builder: (_) => const SyncOverlay(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom-sheet
// ─────────────────────────────────────────────────────────────────────────────

/// Fullscreen overlay that shows live sync progress and prevents
/// interaction. Auto-closes when syncing completes.
///
/// Use [showSyncOverlay] to present this overlay from any [ConsumerWidget].
class SyncOverlay extends ConsumerStatefulWidget {
  const SyncOverlay({super.key});

  @override
  ConsumerState<SyncOverlay> createState() => _SyncOverlayState();
}

class _SyncOverlayState extends ConsumerState<SyncOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotateController;

  bool _minVisualSyncing = true;

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Ensure we show the "Syncing" animation for at least 1.5 seconds
    // so it doesn't just flash instantly if the queue is empty.
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _minVisualSyncing = false);
      }
    });
  }

  @override
  void dispose() {
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncManagerProvider);
    final lastSyncTime = ref.watch(lastSyncTimeProvider);
    final isSyncing = syncState.isSyncing || _minVisualSyncing;

    final double? progress = syncState.total > 0
        ? (syncState.processed / syncState.total).clamp(0.0, 1.0)
        : null;

    return PopScope(
          canPop: !isSyncing,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SyncIcon(
                    isSyncing: isSyncing,
                    rotateController: _rotateController,
                  ),
                  DSSpacing.hLg,
                  Text(
                    isSyncing
                        ? 'sync.actions.syncing'.tr()
                        : 'sync.status.up_to_date'.tr(),
                    style: DSTypography.heading(
                      fontSize: DSTypography.sizeLg,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  DSSpacing.hSm,
                  if (isSyncing) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: Text(
                        syncState.lastMessage ??
                            (lastSyncTime != null
                                ? 'sync.status.last_sync'.tr(
                                    args: [
                                      formatEpoch(
                                        lastSyncTime.millisecondsSinceEpoch,
                                      ),
                                    ],
                                  )
                                : '—'),
                        style: DSTypography.caption(color: Colors.white70),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DSSpacing.hLg,
                    SizedBox(
                      width: 200,
                      child: ClipRRect(
                        borderRadius: DSStyles.pillRadius,
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            DSColors.success,
                          ),
                        ),
                      ),
                    ),
                    if (syncState.total > 0) ...[
                      DSSpacing.hSm,
                      Text(
                        '${syncState.processed} / ${syncState.total}',
                        style: DSTypography.caption(color: Colors.white70),
                      ),
                    ],
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: Text(
                        lastSyncTime != null
                            ? 'sync.status.last_sync'.tr(
                                args: [
                                  formatEpoch(
                                    lastSyncTime.millisecondsSinceEpoch,
                                  ),
                                ],
                              )
                            : '—',
                        style: DSTypography.caption(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  if (!isSyncing) ...[
                    DSSpacing.hLg,
                    FilledButton.icon(
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white24,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: DSSpacing.xl,
                          vertical: DSSpacing.sm,
                        ),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text('common.ok'.tr()),
                    ),
                  ],
                ],
              ),
            ),
          ),
        )
        .animate()
        .slideY(
          begin: 0.12,
          end: 0,
          duration: DSAnimations.dNormal,
          curve: Curves.easeOutCubic,
        )
        .fadeIn(duration: DSAnimations.dFast);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated gradient sync icon circle
// ─────────────────────────────────────────────────────────────────────────────

class _SyncIcon extends StatelessWidget {
  const _SyncIcon({required this.isSyncing, required this.rotateController});

  final bool isSyncing;
  final AnimationController rotateController;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSyncing
              ? [DSColors.primary, DSColors.primary.withValues(alpha: 0.65)]
              : [DSColors.success, DSColors.success.withValues(alpha: 0.65)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (isSyncing ? DSColors.primary : DSColors.success).withValues(
              alpha: 0.30,
            ),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isSyncing
          ? Center(
              child: RotationTransition(
                turns: rotateController,
                child: const Icon(
                  Icons.sync_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            )
          : Center(
              child:
                  const Icon(Icons.check_rounded, color: Colors.white, size: 32)
                      .animate()
                      .scale(duration: 500.ms, curve: Curves.easeOutBack)
                      .fadeIn(),
            ),
    );
  }
}
