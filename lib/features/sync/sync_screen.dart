// DOCS: docs/development-standards.md
// DOCS: docs/features/sync-history.md — update that file when you edit this one.

// =============================================================================
// sync_screen.dart  (shown in the app as "History")
// =============================================================================
//
// Purpose:
//   Displays the full history of delivery status updates that the courier has
//   queued, along with their sync state. Acts as the courier's audit trail and
//   recovery surface for items that failed to sync.
//
// Queue entry states:
//   • pending   — created offline, not yet attempted.
//   • processing — actively being uploaded (during an active sync run).
//   • synced    — successfully confirmed by the server.
//   • failed    — max retries exceeded; courier can retry manually.
//   • conflict  — server rejected the update (e.g. already delivered by another
//                 device); shown with an error message; auto-resolved in some
//                 cases (same-status transition, delivered-immutable).
//
// Key behaviours:
//   • Each entry shows barcode, status badge, mail type, and three timestamps:
//     Delivered (local capture time), Queued (when action was saved), Synced.
//   • Pagination with left/right swipe + haptic feedback.
//   • Pull-to-refresh triggers a sync run (online only).
//   • "Reload" action re-bootstraps deliveries from server (online only).
//   • "Sync Now" manually triggers the queue processor (online only).
//   • Long-press an entry to delete it from the history (with confirmation).
//   • Locked entries (DELIVERED, verified Failed Delivery, OSA) are non-navigable and show
//     an informational message when tapped.
//
// Navigation:
//   Route: /sync
//   Pushed from: DashboardScreen HISTORY card, AppHeaderBar on some screens
// =============================================================================

// =============================================================================
// sync_screen.dart  (shown in the app as "History")
// =============================================================================
//
// Purpose:
//   Shows the courier's delivery update queue — every status change they have
//   submitted, whether pending, syncing, synced, or in conflict. Acts as both
//   a sync control panel and an audit trail of all actions taken.
//
// Key behaviours:
//   • Queue list — each entry shows the barcode, status badge (Delivered/Failed Delivery/
//     OSA), mail type, dispatch code, and three timestamps:
//       - Delivered  : when the courier physically tapped SUBMIT (device-local
//                      time via epoch ms — same timezone as Queued/Synced).
//       - Queued     : when the sync operation was created locally.
//       - Synced     : when the server confirmed the upload (green).
//   • Sync Now button — manually triggers [SyncManager.processQueue] for all
//     pending/failed entries (visible only when online and queue is non-empty).
//   • Reload button — pulls a fresh bootstrap from the server to reconcile any
//     out-of-band changes made via the web portal.
//   • Pagination — swipe left/right with haptic feedback.
//   • Long-press to delete a synced entry from the visual history.
//   • Conflict entries show a red badge; tapping displays the server error.
//   • Lock icon — terminal items (verified Failed Delivery, OSA, already-delivered) are
//     sealed and navigating to them is blocked.
//
// Data:
//   [SyncOperationsDao] for queue entries. [LocalDeliveryDao] for enriching
//   each entry with recipient name, mail type, and date fields.
//
// Navigation:
//   Route: /sync
//   Accessed via: DashboardScreen HISTORY card
// =============================================================================

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:lottie/lottie.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/core/auth/auth_storage.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/models/sync_operation.dart';
import 'package:fsi_courier_app/core/models/delivery_status.dart';
import 'package:fsi_courier_app/core/models/local_delivery.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/sync_provider.dart';
import 'package:fsi_courier_app/core/sync/delivery_bootstrap_service.dart';
import 'package:fsi_courier_app/core/settings/app_settings.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_helper.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/widgets/confirmation_dialog.dart';
import 'package:fsi_courier_app/shared/widgets/sync_progress_bar.dart';
import 'package:fsi_courier_app/shared/widgets/pagination_bar.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  bool _reloading = false;
  Map<String, LocalDelivery> _deliveries = {};
  int _currentPage = 1;
  static const int _pageSize = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(syncManagerProvider.notifier).loadEntries();
      await _loadDeliveries();
      final authStorage = ref.read(authStorageProvider);
      final lastSyncMs = await authStorage.getLastSyncTime();
      if (lastSyncMs != null) {
        ref
            .read(lastSyncTimeProvider.notifier)
            .setValue(DateTime.fromMillisecondsSinceEpoch(lastSyncMs));
      }
    });
  }

  Future<void> _loadDeliveries() async {
    final entries = ref.read(syncManagerProvider).entries;
    if (entries.isEmpty) return;
    final map = <String, LocalDelivery>{};
    for (final entry in entries) {
      final d = await LocalDeliveryDao.instance.getByBarcode(entry.barcode);
      if (d != null) map[entry.barcode] = d;
    }
    if (mounted) setState(() => _deliveries = map);
  }

  Future<void> _reloadFromServer() async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Reload from Server?',
      subtitle:
          'This will clear your local delivery list and re-download it from the server. Pending sync updates will not be affected.',
      confirmLabel: 'Reload',
      cancelLabel: 'Cancel',
      isDestructive: false,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _reloading = true);
    try {
      final client = ref.read(apiClientProvider);
      await DeliveryBootstrapService.instance.clearAndSyncFromApi(client);
      await _loadDeliveries();
      if (mounted) {
        showSuccessNotification(context, 'Deliveries reloaded from server.');
      }
    } catch (_) {
      if (mounted) {
        showAppSnackbar(
          context,
          'Reload failed. Please try again.',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _reloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncManagerProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final canReload = isOnline && !syncState.isSyncing && !_reloading;

    // Refresh delivery metadata when entries change (e.g. after a sync).
    ref.listen<SyncState>(syncManagerProvider, (prev, next) {
      if (prev?.entries.length != next.entries.length) {
        _loadDeliveries();
      }
    });

    return Scaffold(
      appBar: AppHeaderBar(
        title: 'Sync',
        actions: [
          // ── Sync Now (online only) ────────────────────────────────────
          if (isOnline &&
              syncState.entries.any(
                (e) =>
                    e.status == 'pending' ||
                    e.status == 'error' ||
                    e.status == 'failed' ||
                    e.status == 'processing',
              ))
            TextButton.icon(
              onPressed: syncState.isSyncing
                  ? null
                  : () => ref.read(syncManagerProvider.notifier).processQueue(),
              icon: syncState.isSyncing
                  ? const SizedBox(
                      width: DSIconSize.sm,
                      height: DSIconSize.sm,
                      child: CircularProgressIndicator(
                        strokeWidth: DSStyles.strokeWidth,
                      ),
                    )
                  : const Icon(Icons.sync_rounded, size: DSIconSize.md),
              label: Text(
                syncState.isSyncing ? 'Syncing…' : 'Sync Now',
                style: DSTypography.caption(),
              ),
            ),
          // ── Reload from server (online only) ─────────────────────────
          if (isOnline)
            TextButton.icon(
              onPressed: canReload ? _reloadFromServer : null,
              icon: _reloading
                  ? const SizedBox(
                      width: DSIconSize.sm,
                      height: DSIconSize.sm,
                      child: CircularProgressIndicator(
                        strokeWidth: DSStyles.strokeWidth,
                      ),
                    )
                  : const Icon(
                      Icons.cloud_download_outlined,
                      size: DSIconSize.sm,
                    ),
              label: Text('Reload', style: DSTypography.caption()),
            ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          final totalPages = (syncState.entries.length / _pageSize).ceil();
          // Swipe Left (velocity < 0) -> Next Page
          if (velocity < -200 && _currentPage < totalPages) {
            HapticFeedback.mediumImpact();
            setState(() => _currentPage++);
          }
          // Swipe Right (velocity > 0) -> Previous Page
          else if (velocity > 200 && _currentPage > 1) {
            HapticFeedback.mediumImpact();
            setState(() => _currentPage--);
          }
        },
        child: Column(
          children: [
            _SyncHeader(isOnline: isOnline),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  if (ref.read(isOnlineProvider)) {
                    await ref.read(syncManagerProvider.notifier).processQueue();
                  }
                  await ref.read(syncManagerProvider.notifier).loadEntries();
                },
                child: syncState.entries.isEmpty
                    ? _EmptyState(isSyncing: syncState.isSyncing)
                    : Column(
                        children: [
                          Expanded(
                            child: _EntryList(
                              syncState: syncState,
                              deliveries: _deliveries,
                              page: _currentPage,
                              pageSize: _pageSize,
                            ),
                          ),
                          if (syncState.entries.length > _pageSize)
                            PaginationBar(
                              currentPage: _currentPage - 1,
                              totalPages: (syncState.entries.length / _pageSize)
                                  .ceil(),
                              firstItem: ((_currentPage - 1) * _pageSize) + 1,
                              lastItem: math.min(
                                _currentPage * _pageSize,
                                syncState.entries.length,
                              ),
                              totalCount: syncState.entries.length,
                              onPageChanged: (p) =>
                                  setState(() => _currentPage = p + 1),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _SyncHeader extends ConsumerStatefulWidget {
  const _SyncHeader({required this.isOnline});

  final bool isOnline;

  @override
  ConsumerState<_SyncHeader> createState() => _SyncHeaderState();
}

class _SyncHeaderState extends ConsumerState<_SyncHeader> {
  // Prevents the auto-cleanup reload from firing on every StreamBuilder tick
  // once the countdown reaches zero.
  bool _eligibleCleanupTriggered = false;

  Widget _build(BuildContext context) {
    final lastSyncTime = ref.watch(lastSyncTimeProvider);
    final syncState = ref.watch(syncManagerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Online / offline indicator
        Container(
          width: double.infinity,
          color: Theme.of(context).brightness == Brightness.dark
              ? DSColors.scaffoldDark
              : DSColors.scaffoldLight,
          padding: EdgeInsets.fromLTRB(
            DSSpacing.md,
            DSSpacing.md,
            DSSpacing.md,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    widget.isOnline
                        ? Icons.wifi_rounded
                        : Icons.wifi_off_rounded,
                    size: DSIconSize.sm,
                    color: widget.isOnline
                        ? DSColors.success
                        : DSColors.warning,
                  ),
                  DSSpacing.wXs,
                  Text(
                    widget.isOnline ? 'Online' : 'Offline',
                    style: DSTypography.label(
                      color: widget.isOnline
                          ? DSColors.success
                          : DSColors.warning,
                    ).copyWith(fontSize: DSTypography.sizeSm),
                  ),
                ],
              ),
              if (lastSyncTime != null) ...[
                DSSpacing.hXs,
                Text(
                  'Last sync: ${DateFormat('MMM d, yyyy · h:mm a').format(lastSyncTime.toUtc().add(const Duration(hours: 8)))}',
                  style: DSTypography.caption(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? DSColors.labelSecondaryDark
                        : DSColors.labelSecondary,
                  ).copyWith(fontSize: DSTypography.sizeXs),
                ),
              ],

              // Retention countdown: show time remaining until the oldest
              // synced operation becomes eligible for auto-deletion based on
              // the user's configured sync retention days.
              Builder(
                builder: (ctx) {
                  // Find the earliest synced operation (createdAt ms)
                  final synced = syncState.entries
                      .where((e) => e.status == 'synced')
                      .map((e) => e.createdAt)
                      .toList();
                  final int? earliestSynced = synced.isEmpty
                      ? null
                      : synced.reduce((a, b) => a < b ? a : b);

                  return FutureBuilder<int>(
                    future: ref
                        .read(appSettingsProvider)
                        .getSyncRetentionDays(),
                    builder: (context, snap) {
                      final int? days = snap.data;
                      if (days == null) {
                        return const SizedBox.shrink();
                      }

                      // Human-readable label for the retention setting.
                      final retentionLabel = days <= 0
                          ? '1 min (debug)'
                          : '$days day${days == 1 ? '' : 's'}';

                      if (earliestSynced == null) {
                        return Padding(
                          padding: EdgeInsets.only(top: DSSpacing.sm),
                          child: Text(
                            'Sync history retention: $retentionLabel',
                            style: DSTypography.caption(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? DSColors.labelSecondaryDark
                                  : DSColors.labelSecondary,
                            ).copyWith(fontSize: DSTypography.sizeXs),
                          ),
                        );
                      }

                      // Compute midnight-aligned expiry for normal mode, or
                      // rolling 1-minute expiry for debug mode (days == 0).
                      final int expiryMs;
                      if (days <= 0) {
                        // Debug 1-min: expires 1 minute after creation.
                        expiryMs =
                            earliestSynced +
                            const Duration(minutes: 1).inMilliseconds;
                      } else {
                        // Midnight-aligned: expiry = midnight of
                        // (creation calendar-day + retentionDays).
                        final created = DateTime.fromMillisecondsSinceEpoch(
                          earliestSynced,
                        );
                        final creationDay = DateTime(
                          created.year,
                          created.month,
                          created.day,
                        );
                        expiryMs = creationDay
                            .add(Duration(days: days))
                            .millisecondsSinceEpoch;
                      }

                      return StreamBuilder<int>(
                        stream: Stream.periodic(
                          const Duration(seconds: 1),
                          (_) => DateTime.now().millisecondsSinceEpoch,
                        ),
                        builder: (context, nowSnap) {
                          final nowMs =
                              nowSnap.data ??
                              DateTime.now().millisecondsSinceEpoch;
                          final remaining = expiryMs - nowMs;

                          // When the countdown reaches zero while the screen is
                          // open, fire a one-shot reload so the auto-cleanup in
                          // loadEntries() runs and the list refreshes live.
                          if (remaining <= 0 && !_eligibleCleanupTriggered) {
                            _eligibleCleanupTriggered = true;
                            WidgetsBinding.instance.addPostFrameCallback((
                              _,
                            ) async {
                              if (!mounted) return;
                              await ref
                                  .read(syncManagerProvider.notifier)
                                  .loadEntries();
                              if (mounted) {
                                setState(
                                  () => _eligibleCleanupTriggered = false,
                                );
                              }
                            });
                          }

                          String label;
                          if (remaining <= 0) {
                            label = 'History eligible for deletion';
                          } else {
                            final d = Duration(milliseconds: remaining);
                            final dd = d.inDays;
                            final hh = d.inHours % 24;
                            final mm = d.inMinutes % 60;
                            final ss = d.inSeconds % 60;
                            if (dd > 0) {
                              label = '${dd}d ${hh}h ${mm}m';
                            } else if (hh > 0) {
                              label = '${hh}h ${mm}m ${ss}s';
                            } else if (mm > 0) {
                              label = '${mm}m ${ss}s';
                            } else {
                              label = '${ss}s';
                            }
                            label =
                                'History will be automatically cleared after $label';
                          }

                          return Padding(
                            padding: EdgeInsets.only(top: DSSpacing.sm),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.timer,
                                  size: DSIconSize.xs,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? DSColors.labelSecondaryDark
                                      : DSColors.labelSecondary,
                                ),
                                DSSpacing.wSm,
                                Text(
                                  label,
                                  style: DSTypography.caption(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? DSColors.labelSecondaryDark
                                        : DSColors.labelSecondary,
                                  ).copyWith(fontSize: DSTypography.sizeXs),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
              DSSpacing.hMd,
            ],
          ),
        ),
        // Shared sync progress bar (spinner + progress or pending/failed count)
        const SyncProgressBar(
          padding: EdgeInsets.symmetric(
            horizontal: DSSpacing.md,
            vertical: DSSpacing.sm,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => _build(context);
}

// ── Entry List ────────────────────────────────────────────────────────────────

class _EntryList extends ConsumerWidget {
  const _EntryList({
    required this.syncState,
    required this.deliveries,
    required this.page,
    required this.pageSize,
  });

  final SyncState syncState;
  final Map<String, LocalDelivery> deliveries;
  final int page;
  final int pageSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allEntries = syncState.entries;
    final startIndex = (page - 1) * pageSize;
    final endIndex = math.min(startIndex + pageSize, allEntries.length);
    final entries = allEntries.sublist(startIndex, endIndex);

    // Count failed delivery attempts per barcode from ALL sync entries (not just current page).
    // This is the most reliable source because rawJson may not contain failed_delivery_count.
    final failedDeliveryCountByBarcode = <String, int>{};
    for (final e in allEntries) {
      if (e.operationType != 'UPDATE_STATUS') continue;
      try {
        final map = jsonDecode(e.payloadJson) as Map<String, dynamic>;
        final status = (map['delivery_status']?.toString() ?? '').toUpperCase();
        if (status == 'FAILED_DELIVERY') {
          failedDeliveryCountByBarcode[e.barcode] =
              (failedDeliveryCountByBarcode[e.barcode] ?? 0) + 1;
        }
      } catch (_) {}
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(top: DSSpacing.sm, bottom: 100),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _EntryTile(
          entry: entry,
          delivery: deliveries[entry.barcode],
          failedDeliveryAttemptsCount:
              failedDeliveryCountByBarcode[entry.barcode] ?? 0,
          isSyncing:
              syncState.isSyncing && syncState.currentBarcode == entry.barcode,
          onRetry: (entry.status == 'error' || entry.status == 'failed')
              ? () async {
                  final confirmed = await ConfirmationDialog.show(
                    context,
                    title: 'Retry sync?',
                    subtitle:
                        'This will attempt to upload this update to the server again.',
                    confirmLabel: 'Retry',
                  );
                  if (confirmed == true) {
                    ref
                        .read(syncManagerProvider.notifier)
                        .retrySingle(entry.id);
                  }
                }
              : null,
          onDismiss: (entry.status == 'conflict')
              ? () async {
                  final confirmed = await ConfirmationDialog.show(
                    context,
                    title: 'Resolve conflict?',
                    subtitle:
                        'This will mark the update as "Resolved" locally without sending it to the server. Use this if you have manually confirmed the state on the server.',
                    confirmLabel: 'Resolve',
                  );
                  if (confirmed == true) {
                    ref
                        .read(syncManagerProvider.notifier)
                        .dismissConflict(entry.id);
                  }
                }
              : null,
          onDelete: () async {
            final confirmed = await ConfirmationDialog.show(
              context,
              title: 'Delete operation?',
              subtitle:
                  'This will permanently remove this update from your sync queue. The local delivery status will NOT be reverted.',
              confirmLabel: 'Delete',
              isDestructive: true,
            );
            if (confirmed == true) {
              ref.read(syncManagerProvider.notifier).deleteSingle(entry.id);
            }
          },
        );
      },
    );
  }
}

// ── Entry Tile ────────────────────────────────────────────────────────────────

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.isSyncing,
    required this.failedDeliveryAttemptsCount,
    this.delivery,
    this.onRetry,
    this.onDismiss,
    this.onDelete,
  });

  final SyncOperation entry;
  final LocalDelivery? delivery;
  final bool isSyncing;
  final int failedDeliveryAttemptsCount;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final VoidCallback? onDelete;

  /// Decodes delivery_status from the queue payload.
  String get _payloadStatus {
    try {
      final map = jsonDecode(entry.payloadJson) as Map<String, dynamic>;
      return map['delivery_status']?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Extracts date fields from the local delivery's rawJson.
  ({String deliveryDate, String transactionDate, String dispatchDate})
  get _dates {
    if (delivery == null) {
      return (deliveryDate: '', transactionDate: '', dispatchDate: '');
    }
    final raw = delivery!.toDeliveryMap();
    final transactionAt = raw['transaction_at']?.toString() ?? '';
    final deliveredDate = raw['delivered_date']?.toString() ?? '';
    final dispatchedAt = raw['dispatched_at']?.toString() ?? '';
    // Use deliveredAt epoch ms for local-timezone display (same approach as
    // Queued/Synced rows). Falls back to the server ISO string only when the
    // local column is absent (e.g. records seeded purely from server bootstrap).
    final deliveredAtMs = delivery!.deliveredAt;
    final String dlDateResolved;
    if (deliveredAtMs != null) {
      dlDateResolved = DateFormat('MMM d, yyyy · h:mm a').format(
        DateTime.fromMillisecondsSinceEpoch(
          deliveredAtMs,
        ).toUtc().add(const Duration(hours: 8)),
      );
    } else if (deliveredDate.isNotEmpty) {
      dlDateResolved = formatDate(deliveredDate, includeTime: true);
    } else {
      dlDateResolved = '';
    }

    // Parse transaction and delivered strings to datetimes when possible so
    // we can compare instants rather than raw strings (server may emit the
    // same instant in different timezone formats).
    final DateTime? txDt = transactionAt.isNotEmpty
        ? parseServerDate(transactionAt)
        : null;
    final DateTime? dlDtFromServer = deliveredDate.isNotEmpty
        ? parseServerDate(deliveredDate)
        : null;

    // Determine if the transaction instant matches the resolved delivered
    // instant. Prefer the local epoch ms if available because it's authoritative
    // for local-day filtering. We now treat the sync operation creation time
    // (`entry.createdAt`) as the authoritative "transaction" time so the
    // user always sees the actual time they performed the action.
    bool isSameInstant = false;
    if (deliveredAtMs != null) {
      isSameInstant = entry.createdAt == deliveredAtMs;
    } else if (txDt != null && dlDtFromServer != null) {
      isSameInstant =
          txDt.millisecondsSinceEpoch == dlDtFromServer.millisecondsSinceEpoch;
    }

    final String dlDate = dlDateResolved;
    final String txDate = isSameInstant
        ? ''
        : DateFormat('MMM d, yyyy · h:mm a').format(
            DateTime.fromMillisecondsSinceEpoch(
              entry.createdAt,
            ).toUtc().add(const Duration(hours: 8)),
          );

    return (
      deliveryDate: dlDate,
      transactionDate: txDate,
      dispatchDate: dispatchedAt.isNotEmpty
          ? formatDate(dispatchedAt, includeTime: true)
          : '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final queuedStr = DateFormat('MMM d, yyyy · h:mm a').format(
      DateTime.fromMillisecondsSinceEpoch(
        entry.createdAt,
      ).toUtc().add(const Duration(hours: 8)),
    );
    final syncedStr = (entry.status == 'synced' && entry.lastAttemptAt != null)
        ? DateFormat('MMM d, yyyy · h:mm a').format(
            DateTime.fromMillisecondsSinceEpoch(
              entry.lastAttemptAt!,
            ).toUtc().add(const Duration(hours: 8)),
          )
        : null;

    final recipientName = delivery?.recipientName;
    final mailType = delivery?.mailType;
    final dispatchCode = delivery?.dispatchCode;
    final payloadStatus = _payloadStatus;
    final dates = _dates;
    // Prefer the current delivery status from LocalDelivery (if available)
    // when deciding whether this entry should be locked / non-navigable.
    final String? delStatus = delivery?.deliveryStatus;
    final currentStatus = (delStatus != null && delStatus.isNotEmpty)
        ? delStatus
        : payloadStatus;
    // Use the higher of: queue-derived attempt count OR raw_json attempt count.
    // The queue count is authoritative for in-progress items; raw_json is needed
    // for deliveries whose older sync entries have already been auto-purged.
    final rawJsonAttempts = delivery != null
        ? getAttemptsCountFromMap(delivery!.toDeliveryMap())
        : 0;
    final attemptsCount = failedDeliveryAttemptsCount > rawJsonAttempts
        ? failedDeliveryAttemptsCount
        : rawJsonAttempts;

    final currentFailedDeliveryVerif =
        (delivery?.rtsVerificationStatus ?? 'unvalidated')
            .toString()
            .toLowerCase();

    final isLocked = checkIsLocked(
      status: currentStatus,
      rtsVerificationStatus: currentFailedDeliveryVerif,
      attempts: attemptsCount,
    );

    return InkWell(
      onTap: isLocked
          ? () {
              final s = currentStatus.toUpperCase();
              final v = currentFailedDeliveryVerif;
              String msg =
                  'This delivery is ${s.toLowerCase()} and cannot be opened.';
              if (s == 'OSA') {
                msg = 'This item is marked OSA and cannot be opened.';
              } else if (s == 'DELIVERED') {
                msg = 'This item has already been delivered and is sealed.';
              } else if (s == 'FAILED_DELIVERY' && attemptsCount >= 3) {
                msg =
                    'This failed delivery has reached the maximum number of attempts and is locked.';
              } else if (s == 'FAILED_DELIVERY' &&
                  (v == 'verified_with_pay' || v == 'verified_no_pay')) {
                msg =
                    'This failed delivery has already been verified and is no longer actionable.';
              }
              showInfoNotification(context, msg);
            }
          : (entry.operationType == 'UPDATE_PROFILE')
          ? () => showInfoNotification(
              context,
              'This entry is a profile update and has no delivery details.',
            )
          : () => context.push('/deliveries/${entry.barcode}/update'),
      onLongPress: onDelete,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: DSSpacing.md,
          vertical: DSSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status icon ──────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.only(top: DSSpacing.xs),
              child: _StatusChip(status: entry.status, isSyncing: isSyncing),
            ),
            DSSpacing.wMd,

            // ── Content ──────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Barcode + chevron (hidden for OSA — detail is not accessible)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.barcode,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            letterSpacing: DSTypography.lsLoose,
                          ),
                        ),
                      ),
                      if (!isLocked && entry.operationType != 'UPDATE_PROFILE')
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: DSIconSize.md,
                          color: DSColors.labelTertiary,
                        ),
                    ],
                  ),

                  // Recipient name
                  if (recipientName != null &&
                      recipientName.isNotEmpty &&
                      !isLocked) ...[
                    DSSpacing.hXs,
                    Text(
                      recipientName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],

                  DSSpacing.hSm,

                  // Status badge + mail type + dispatch code
                  Wrap(
                    spacing: DSSpacing.sm,
                    runSpacing: 4,
                    children: [
                      if (payloadStatus.isNotEmpty)
                        _StatusBadge(status: payloadStatus),
                      if (mailType != null && mailType.isNotEmpty)
                        _Chip(mailType.toUpperCase()),
                      if (dispatchCode != null && dispatchCode.isNotEmpty)
                        _Chip(dispatchCode),
                      if (delivery?.paidAt != null) const _ArchivedChip(),
                    ],
                  ),

                  DSSpacing.hSm,

                  // Delivery date
                  if (dates.deliveryDate.isNotEmpty)
                    _MetaRow(
                      icon: Icons.local_shipping_outlined,
                      label: 'Delivered',
                      value: dates.deliveryDate,
                    ),

                  // Transaction date (only if different from delivery date)
                  if (dates.transactionDate.isNotEmpty)
                    _MetaRow(
                      icon: Icons.receipt_outlined,
                      label: 'Transaction',
                      value: dates.transactionDate,
                    ),

                  // Dispatch date (shown for pending items with no delivery date)
                  if (dates.deliveryDate.isEmpty &&
                      dates.dispatchDate.isNotEmpty)
                    _MetaRow(
                      icon: Icons.call_made_rounded,
                      label: 'Dispatched',
                      value: dates.dispatchDate,
                    ),

                  // Queued time
                  _MetaRow(
                    icon: Icons.cloud_upload_outlined,
                    label: 'Queued',
                    value: queuedStr,
                  ),

                  // Synced time
                  if (syncedStr != null)
                    _MetaRow(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Synced',
                      value: syncedStr,
                      valueColor: DSColors.success,
                    ),

                  // Error message
                  if (entry.lastError != null) ...[
                    DSSpacing.hXs,
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: DSIconSize.xs,
                          color: theme.colorScheme.error,
                        ),
                        DSSpacing.wXs,
                        Expanded(
                          child: Text(
                            entry.lastError!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Retry, Dismiss, or Delete buttons
                  if (onRetry != null ||
                      onDismiss != null ||
                      onDelete != null) ...[
                    DSSpacing.hXs,
                    Row(
                      children: [
                        if (onRetry != null)
                          SizedBox(
                            height: 28,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: onRetry,
                              child: const Text('RETRY'),
                            ),
                          ),
                        if (onRetry != null &&
                            (onDismiss != null || onDelete != null))
                          DSSpacing.wMd,
                        if (onDismiss != null)
                          SizedBox(
                            height: 28,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: onDismiss,
                              child: const Text('RESOLVE'),
                            ),
                          ),
                        if (onDismiss != null && onDelete != null)
                          DSSpacing.wMd,
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Status Chip ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.isSyncing});

  final String status;
  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    if (isSyncing || status == 'processing') {
      return const SizedBox(
        width: DSIconSize.xl,
        height: DSIconSize.xl,
        child: CircularProgressIndicator(strokeWidth: DSStyles.strokeWidth),
      );
    }

    final (color, icon) = switch (status) {
      'pending' => (DSColors.warning, Icons.schedule_rounded),
      'synced' => (DSColors.success, Icons.check_circle_rounded),
      'error' => (DSColors.error, Icons.error_rounded),
      'failed' => (DSColors.error, Icons.error_rounded),
      'conflict' => (DSColors.pending, Icons.warning_rounded),
      _ => (DSColors.labelSecondary, Icons.help_outline_rounded),
    };

    return Icon(icon, color: color, size: DSIconSize.lg);
  }
}

// ── Delivery Status Badge ─────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final ds = DeliveryStatus.fromString(status);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (bg, fg, label) = switch (ds) {
      DeliveryStatus.delivered => (
        DSColors.successSurface,
        DSColors.successText,
        DeliveryStatus.delivered.displayName,
      ),
      DeliveryStatus.pending => (
        DSColors.pendingSurface,
        DSColors.pendingText,
        DeliveryStatus.pending.displayName,
      ),
      DeliveryStatus.failedDelivery => (
        DSColors.errorSurface,
        DSColors.errorText,
        DeliveryStatus.failedDelivery.displayName,
      ),
      DeliveryStatus.osa => (
        DSColors.warningSurface,
        DSColors.warningText,
        DeliveryStatus.osa.displayName,
      ),
      _ => (
        isDark ? DSColors.secondarySurfaceDark : DSColors.secondarySurfaceLight,
        isDark ? DSColors.labelSecondaryDark : DSColors.labelSecondary,
        status.toUpperCase(),
      ),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: DSSpacing.sm, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: DSStyles.pillRadius),
      child: Text(
        label,
        style: DSTypography.label(color: fg).copyWith(
          fontSize: DSTypography.sizeSm,
          letterSpacing: DSTypography.lsLoose,
        ),
      ),
    );
  }
}

// ── Generic Chip ──────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: DSSpacing.sm,
        vertical: DSSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? DSColors.cardDark
            : DSColors.secondarySurfaceLight,
        borderRadius: DSStyles.pillRadius,
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? DSColors.separatorDark
              : DSColors.separatorLight,
        ),
      ),
      child: Text(
        label,
        style: DSTypography.caption(
          color: DSColors.labelSecondary,
        ).copyWith(fontSize: DSTypography.sizeSm, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Archived Chip ───────────────────────────────────────────────────────────────────────────────
class _ArchivedChip extends StatelessWidget {
  const _ArchivedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: DSSpacing.sm,
        vertical: DSSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: DSColors.accentSurface,
        borderRadius: DSStyles.pillRadius,
        border: Border.all(
          color: DSColors.accent.withValues(alpha: DSStyles.alphaMuted),
        ),
      ),
      child: Text(
        'ARCHIVED',
        style: DSTypography.label(color: DSColors.accent).copyWith(
          fontSize: DSTypography.sizeSm,
          letterSpacing: DSTypography.lsLoose,
        ),
      ),
    );
  }
}

// ── Meta Row ──────────────────────────────────────────────────────────────────

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dimColor = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: EdgeInsets.only(top: DSSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: DSIconSize.xs, color: dimColor),
          DSSpacing.wSm,
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: dimColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: valueColor ?? dimColor,
                fontWeight: valueColor != null ? FontWeight.w600 : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatefulWidget {
  const _EmptyState({required this.isSyncing});

  final bool isSyncing;

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onLoaded(LottieComposition composition) {
    if (_loaded) return;
    _loaded = true;
    _controller.duration = composition.duration;
    _controller.forward().whenComplete(() {
      if (mounted) {
        _controller.value = 1.0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Must be scrollable for RefreshIndicator to work.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: DSSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.isSyncing) ...[
                  const SpinKitDoubleBounce(
                    color: DSColors.primary,
                    size: DSIconSize.heroMd,
                  ),
                  DSSpacing.hMd,
                  Text('Syncing…', style: theme.textTheme.titleMedium),
                ] else ...[
                  Lottie.asset(
                    AppAssets.animSuccess,
                    width: DSIconSize.lg,
                    height: DSIconSize.heroMd * 2.0,
                    controller: _controller,
                    onLoaded: _onLoaded,
                  ),
                  DSSpacing.hMd,
                  Text(
                    'All caught up!',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  DSSpacing.hSm,
                  Text(
                    'No pending deliveries to sync.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: DSColors.labelTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── FAB ───────────────────────────────────────────────────────────────────────
