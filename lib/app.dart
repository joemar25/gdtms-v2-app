// DOCS: docs/development-standards.md
// DOCS: docs/entry-points.md — update that file when you edit this one.
// DOCS: docs/architecture/system-map.md

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_provider.dart';
import 'core/providers/connectivity_provider.dart';
import 'core/providers/sync_provider.dart';
import 'core/sync/auto_sync_coordinator.dart';
import 'package:go_router/go_router.dart';
import 'shared/router/app_router.dart';
import 'core/providers/update_provider.dart';
import 'models/update_info.dart';
import 'shared/widgets/update_banner_widget.dart';
import 'shared/widgets/debug_ui_toggle.dart';
import 'shared/router/router_keys.dart';
import 'shared/widgets/time_enforcer.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

// ─── MARK: App Initialization ───────────────────────────────────────────────

class FsiCourierApp extends ConsumerWidget {
  const FsiCourierApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    // Watch theme only — avoids rebuilding MaterialApp on courier/session
    // field updates (production-safe A9; same theme semantics).
    final themeMode = ref.watch(authProvider.select((s) => s.themeMode));

    return Builder(
      builder: (context) => MaterialApp.router(
        title: 'ITMS',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: appScaffoldMessengerKey,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        themeMode: themeMode,
        theme: DSTheme.build(Brightness.light),
        darkTheme: DSTheme.build(Brightness.dark),
        routerConfig: router,
        builder: (context, child) => TimeEnforcer(
          child: _AutoSyncListener(
            // Stack keeps global chrome above routes without OverlayEntry races.
            child: Stack(
              fit: StackFit.expand,
              children: [
                child ?? const SizedBox.shrink(),
                const DebugUiToggle(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin widget shell wiring app-lifecycle and provider events into
/// [AutoSyncCoordinator], which keeps data accurate by syncing in multiple
/// scenarios:
///
/// 1. **App startup** — runs immediately if the device is already online.
/// 2. **Login** — runs after a fresh login while online.
/// 3. **Offline → Online** — runs as soon as the device regains connectivity.
/// 4. **App resume** — runs when the courier switches back to this app from
///    another app (e.g., they checked messages and came back). This is the
///    most common trigger for delivery couriers during their working day.
/// 5. **Periodic** — runs every few minutes while the app is in the
///    foreground and online, so data never goes stale mid-shift.
///
/// All syncs are fire-and-forget and use debouncing to prevent overlapping
/// calls (A1: trigger policy + debounce lives in [AutoSyncCoordinator], not
/// here — this widget only owns `WidgetsBindingObserver` registration and
/// root overlay insertion).
class _AutoSyncListener extends ConsumerStatefulWidget {
  const _AutoSyncListener({required this.child});
  final Widget child;

  @override
  ConsumerState<_AutoSyncListener> createState() => _AutoSyncListenerState();
}

class _AutoSyncListenerState extends ConsumerState<_AutoSyncListener>
    with WidgetsBindingObserver {
  OverlayEntry? _syncPillEntry;
  OverlayEntry? _updateBannerEntry;
  OverlayEntry? _mandatoryUpdateEntry;

  AutoSyncCoordinator get _coordinator => ref.read(autoSyncCoordinatorProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Trigger 1: App startup — run after first frame so providers are ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _coordinator.onStartup();
      _insertSyncPill();
      _insertUpdateBanner();
      _insertMandatoryUpdateOverlay();
    });
  }

  void _insertUpdateBanner() {
    if (_updateBannerEntry != null) return;
    _updateBannerEntry = OverlayEntry(
      builder: (_) => const RepaintBoundary(child: UpdateBannerOverlay()),
    );
    rootNavigatorKey.currentState?.overlay?.insert(_updateBannerEntry!);
  }

  void _insertMandatoryUpdateOverlay() {
    if (_mandatoryUpdateEntry != null) return;
    _mandatoryUpdateEntry = OverlayEntry(
      builder: (_) => const RepaintBoundary(child: _MandatoryUpdateOverlay()),
    );
    rootNavigatorKey.currentState?.overlay?.insert(_mandatoryUpdateEntry!);
  }

  void _insertSyncPill() {
    if (_syncPillEntry != null) return;
    _syncPillEntry = OverlayEntry(
      builder: (_) => const RepaintBoundary(child: _SyncFloatingPill()),
    );
    rootNavigatorKey.currentState?.overlay?.insert(_syncPillEntry!);
  }

  @override
  void dispose() {
    if (_syncPillEntry != null) {
      try {
        _syncPillEntry?.remove();
      } catch (e) {
        debugPrint('[APP] Sync pill removal error: $e');
      }
      _syncPillEntry = null;
    }
    if (_updateBannerEntry != null) {
      try {
        _updateBannerEntry?.remove();
      } catch (e) {
        debugPrint('[APP] Update banner removal error: $e');
      }
      _updateBannerEntry = null;
    }
    if (_mandatoryUpdateEntry != null) {
      try {
        _mandatoryUpdateEntry?.remove();
      } catch (e) {
        debugPrint('[APP] Mandatory update overlay removal error: $e');
      }
      _mandatoryUpdateEntry = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Trigger 4: App returns to foreground (e.g., courier switches back to app).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _coordinator.onResume();
      case AppLifecycleState.paused:
        _coordinator.onPause();
      case AppLifecycleState.detached:
        _coordinator.onDetached();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Trigger 3: Offline → Online transition.
    ref.listen<bool>(isOnlineProvider, (previous, current) {
      if (previous == false && current == true) {
        _coordinator.onReconnect();
      } else if (current == false) {
        _coordinator.onOffline();
      }
    });

    // Trigger 2: Fresh login.
    ref.listen<AuthState>(authProvider, (previous, current) {
      if (previous?.isAuthenticated == false &&
          current.isAuthenticated == true) {
        _coordinator.onLogin();
      } else if (current.isAuthenticated == false) {
        _coordinator.onLogout();
      }
    });

    return widget.child;
  }
}

// ── Global Sync Floating Pill ─────────────────────────────────────────────────
//
// Inserted as a root OverlayEntry so it floats above all screens without
// affecting any layout. Returns an invisible widget when nothing is pending.

// Routes on which the pill should never appear.
const _kPillHiddenRoutes = {
  '/sync',
  '/splash',
  '/login',
  '/reset-password',
  '/location-required', // also covers camera + notification permission screens
};

// ─── MARK: UI Components ─────────────────────────────────────────────────────

class _SyncFloatingPill extends ConsumerWidget {
  const _SyncFloatingPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(
      authProvider.select((s) => s.isAuthenticated),
    );
    if (!isAuthenticated) {
      return const SizedBox.shrink();
    }

    final router = ref.watch(appRouterProvider);
    return ListenableBuilder(
      listenable: router.routeInformationProvider,
      builder: (context, _) {
        final path = router.routeInformationProvider.value.uri.path;
        if (_kPillHiddenRoutes.contains(path)) {
          return const SizedBox.shrink();
        }
        return const _SyncPillContent();
      },
    );
  }
}

class _SyncPillContent extends ConsumerWidget {
  const _SyncPillContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // select() extracts only the display values — prevents rebuilds when
    // unrelated SyncState fields change (e.g. a different entry's retry count).
    final (
      :isSyncing,
      :pending,
      :failed,
      :lastMessage,
      :total,
      :processed,
    ) = ref.watch(
      syncManagerProvider.select((s) {
        final p = s.entries
            .where((e) => e.status == 'pending' || e.status == 'processing')
            .length;
        final f = s.entries
            .where(
              (e) =>
                  e.status == 'error' ||
                  e.status == 'failed' ||
                  e.status == 'conflict',
            )
            .length;
        return (
          isSyncing: s.isSyncing,
          pending: p,
          failed: f,
          lastMessage: s.lastMessage,
          total: s.total,
          processed: s.processed,
        );
      }),
    );
    final connStatus = ref.watch(connectionStatusProvider);

    final hasActivity = isSyncing || pending > 0 || failed > 0;
    final top = MediaQuery.of(context).padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedOpacity(
      opacity: hasActivity ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 280),
      child: IgnorePointer(
        ignoring: !hasActivity,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              DSSpacing.md,
              top + DSSpacing.sm,
              DSSpacing.md,
              0,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85,
              ),
              child: Material(
                color: DSColors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? DSColors.cardElevatedDark.withValues(
                            alpha: DSStyles.alphaOpaque,
                          )
                        : DSColors.white.withValues(
                            alpha: DSStyles.alphaOpaque,
                          ),
                    borderRadius: DSStyles.circularRadius,
                    boxShadow: DSStyles.shadowXS(context),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSyncing) ...[
                        const DSLoading(size: DSIconSize.xs),
                        DSSpacing.wSm,
                        Flexible(
                          child: Text(
                            _trimMessage(
                              lastMessage ?? 'sync.actions.syncing'.tr(),
                            ),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (total > 0) ...[
                          DSSpacing.wSm,
                          Text(
                            '$processed/$total',
                            style: DSTypography.label(
                              color: isDark
                                  ? DSColors.labelSecondaryDark
                                  : DSColors.labelSecondary,
                            ).copyWith(fontSize: DSTypography.sizeXs),
                          ),
                        ],
                      ] else ...[
                        Icon(
                          connStatus == ConnectionStatus.online
                              ? Icons.cloud_sync_outlined
                              : connStatus == ConnectionStatus.networkOffline
                              ? Icons.wifi_off_rounded
                              : Icons.cloud_off_outlined,
                          size: DSIconSize.xs,
                          color: failed > 0
                              ? DSColors.error
                              : (isDark
                                    ? DSColors.labelSecondaryDark
                                    : DSColors.labelSecondary),
                        ),
                        DSSpacing.wSm,
                        Text(
                          [
                            if (pending > 0) '$pending pending',
                            if (failed > 0) '$failed failed',
                          ].join(' · '),
                          style: DSTypography.caption(
                            color: failed > 0 ? DSColors.error : null,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Strips the barcode from long sync messages so the pill stays compact.
  /// e.g. "Updating delivery B132256VI150 to server…" → "Updating delivery…"
  static String _trimMessage(String msg) {
    // Remove anything that looks like a barcode (all-caps alphanumeric 8+ chars)
    return msg
        .replaceAll(RegExp(r'\b[A-Z0-9]{8,}\b'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }
}

// ── Mandatory Update Full-Screen Overlay ──────────────────────────────────────
//
// Inserted as a root OverlayEntry so it sits above every screen.
// Visible whenever isMandatory && hasUpdate, except on /update itself
// (where the download UI lives) and /splash (let bootstrap finish first).

// Routes where this overlay must not appear so the user can act on the update.
const _kMandatoryOverlayPassthroughRoutes = {'/update', '/splash'};

class _MandatoryUpdateOverlay extends ConsumerWidget {
  const _MandatoryUpdateOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(updateProvider);

    if (!updateState.hasUpdate || !updateState.updateInfo!.isMandatory) {
      return const SizedBox.shrink();
    }

    final router = ref.watch(appRouterProvider);
    return ListenableBuilder(
      listenable: router.routeInformationProvider,
      builder: (context, _) {
        final path = router.routeInformationProvider.value.uri.path;
        if (_kMandatoryOverlayPassthroughRoutes.contains(path)) {
          return const SizedBox.shrink();
        }
        return _MandatoryUpdateScreen(info: updateState.updateInfo!);
      },
    );
  }
}

class _MandatoryUpdateScreen extends StatelessWidget {
  const _MandatoryUpdateScreen({required this.info});

  final UpdateInfo info;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      child: Material(
        color: DSColors.black.withValues(alpha: 0.88),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DSSpacing.xl,
                vertical: DSSpacing.lg,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? DSColors.cardElevatedDark : DSColors.white,
                    borderRadius: DSStyles.sheetRadius,
                    boxShadow: DSStyles.shadowXL(context),
                  ),
                  padding: const EdgeInsets.all(DSSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Icon ──────────────────────────────────────────
                      Container(
                        width: DSIconSize.heroSm,
                        height: DSIconSize.heroSm,
                        decoration: BoxDecoration(
                          color: DSColors.error.withValues(alpha: 0.12),
                          borderRadius: DSStyles.cardRadius,
                        ),
                        child: const Icon(
                          Icons.system_update_rounded,
                          size: DSIconSize.xl,
                          color: DSColors.error,
                        ),
                      ),
                      DSSpacing.hXl,

                      // ── Title ─────────────────────────────────────────
                      Text(
                        'Update Required',
                        style: DSTypography.heading(
                          color: isDark
                              ? DSColors.white
                              : DSColors.labelPrimary,
                        ).copyWith(fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                      DSSpacing.hSm,

                      // ── Body ──────────────────────────────────────────
                      Text(
                        'Version ${info.latestVersion} is required to '
                        'continue using the app. Please update now.',
                        style: DSTypography.body(
                          color: isDark
                              ? DSColors.labelSecondaryDark
                              : DSColors.labelSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      if (info.releaseNotes.isNotEmpty) ...[
                        DSSpacing.hMd,
                        Text(
                          info.releaseNotes,
                          style: DSTypography.caption(
                            color: isDark
                                ? DSColors.labelTertiaryDark
                                : DSColors.labelTertiary,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      DSSpacing.hXl,

                      // ── CTA ───────────────────────────────────────────
                      FilledButton.icon(
                        onPressed: () => context.go('/update'),
                        icon: const Icon(
                          Icons.system_update_alt_rounded,
                          size: DSIconSize.sm,
                        ),
                        label: const Text('Update Now'),
                        style: FilledButton.styleFrom(
                          backgroundColor: DSColors.error,
                          foregroundColor: DSColors.white,
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: DSStyles.cardRadius,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
