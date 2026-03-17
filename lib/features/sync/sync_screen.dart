import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/auth/auth_storage.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/models/sync_operation.dart';
import 'package:fsi_courier_app/core/models/local_delivery.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/sync_provider.dart';
import 'package:fsi_courier_app/core/sync/delivery_bootstrap_service.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart'
    show showSuccessNotification, showAppSnackbar, SnackbarType;
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/widgets/confirmation_dialog.dart';
import 'package:fsi_courier_app/shared/widgets/sync_progress_bar.dart';

class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  bool _reloading = false;
  Map<String, LocalDelivery> _deliveries = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(syncManagerProvider.notifier).loadEntries();
      await _loadDeliveries();
      final authStorage = ref.read(authStorageProvider);
      final lastSyncMs = await authStorage.getLastSyncTime();
      if (lastSyncMs != null) {
        ref.read(lastSyncTimeProvider.notifier).state = DateTime.fromMillisecondsSinceEpoch(lastSyncMs);
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
        pageIcon: Icons.sync_rounded,
        actions: [
          if (isOnline)
            TextButton.icon(
              onPressed: canReload ? _reloadFromServer : null,
              icon: _reloading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_download_outlined, size: 18),
              label: const Text('Reload', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
      body: Column(
        children: [
          _SyncHeader(isOnline: isOnline),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                // When online: push pending queue entries to server first,
                // then reload the list so statuses reflect the latest state.
                // When offline: just reload from local SQLite.
                if (ref.read(isOnlineProvider)) {
                  await ref.read(syncManagerProvider.notifier).processQueue();
                }
                await ref.read(syncManagerProvider.notifier).loadEntries();
              },
              child: syncState.entries.isEmpty
                  ? _EmptyState(isSyncing: syncState.isSyncing)
                  : _EntryList(syncState: syncState, deliveries: _deliveries),
            ),
          ),
        ],
      ),
      floatingActionButton: _SyncFab(syncState: syncState, isOnline: isOnline),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _SyncHeader extends ConsumerWidget {
  const _SyncHeader({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lastSyncTime = ref.watch(lastSyncTimeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Online / offline indicator
        Container(
          width: double.infinity,
          color: theme.colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                    size: 16,
                    color: isOnline ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOnline ? 'Online' : 'Offline',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isOnline ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (lastSyncTime != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Last sync: ${DateFormat('MMM d, yyyy · h:mm a').format(lastSyncTime)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
        // Shared sync progress bar (spinner + progress or pending/failed count)
        const SyncProgressBar(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ],
    );
  }
}

// ── Entry List ────────────────────────────────────────────────────────────────

class _EntryList extends ConsumerWidget {
  const _EntryList({required this.syncState, required this.deliveries});

  final SyncState syncState;
  final Map<String, LocalDelivery> deliveries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = syncState.entries;
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _EntryTile(
          entry: entry,
          delivery: deliveries[entry.barcode],
          isSyncing:
              syncState.isSyncing && syncState.currentBarcode == entry.barcode,
          onRetry: (entry.status == 'error' || entry.status == 'failed')
              ? () async {
                  final confirmed = await ConfirmationDialog.show(
                    context,
                    title: 'Retry sync?',
                    subtitle: 'This will attempt to upload this update to the server again.',
                    confirmLabel: 'Retry',
                  );
                  if (confirmed == true) {
                    ref.read(syncManagerProvider.notifier).retrySingle(entry.id);
                  }
                }
              : null,
          onDismiss: (entry.status == 'conflict')
              ? () async {
                  final confirmed = await ConfirmationDialog.show(
                    context,
                    title: 'Resolve conflict?',
                    subtitle: 'This will mark the update as "Resolved" locally without sending it to the server. Use this if you have manually confirmed the state on the server.',
                    confirmLabel: 'Resolve',
                  );
                  if (confirmed == true) {
                    ref.read(syncManagerProvider.notifier).dismissConflict(entry.id);
                  }
                }
              : null,
          onDelete: (entry.status != 'synced' || entry.lastError != null)
              ? () async {
                  final confirmed = await ConfirmationDialog.show(
                    context,
                    title: 'Delete operation?',
                    subtitle: 'This will permanently remove this update from your sync queue. The local delivery status will NOT be reverted.',
                    confirmLabel: 'Delete',
                    isDestructive: true,
                  );
                  if (confirmed == true) {
                    ref.read(syncManagerProvider.notifier).deleteSingle(entry.id);
                  }
                }
              : null,
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
    this.delivery,
    this.onRetry,
    this.onDismiss,
    this.onDelete,
  });

  final SyncOperation entry;
  final LocalDelivery? delivery;
  final bool isSyncing;
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

    // If both dates exist and are the same, show only delivery date.
    final String txDate;
    final String dlDate;
    if (transactionAt.isNotEmpty &&
        deliveredDate.isNotEmpty &&
        transactionAt == deliveredDate) {
      dlDate = formatDate(deliveredDate, includeTime: true);
      txDate = '';
    } else {
      dlDate = deliveredDate.isNotEmpty
          ? formatDate(deliveredDate, includeTime: true)
          : '';
      txDate = transactionAt.isNotEmpty
          ? formatDate(transactionAt, includeTime: true)
          : '';
    }

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
    final queuedStr = DateFormat(
      'MMM d, yyyy · h:mm a',
    ).format(DateTime.fromMillisecondsSinceEpoch(entry.createdAt));
    final syncedStr = (entry.status == 'synced' && entry.lastAttemptAt != null)
        ? DateFormat(
            'MMM d, yyyy · h:mm a',
          ).format(DateTime.fromMillisecondsSinceEpoch(entry.lastAttemptAt!))
        : null;

    final recipientName = delivery?.recipientName;
    final mailType = delivery?.mailType;
    final dispatchCode = delivery?.dispatchCode;
    final payloadStatus = _payloadStatus;
    final dates = _dates;
    final isOsa = payloadStatus.toLowerCase() == 'osa';

    return InkWell(
      onTap: isOsa ? null : () => context.push('/deliveries/${entry.barcode}'),
      onLongPress: onDelete,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status icon ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _StatusChip(
                status: entry.status,
                isSyncing: isSyncing,
              ),
            ),
            const SizedBox(width: 12),

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
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (!isOsa)
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: Colors.grey,
                        ),
                    ],
                  ),

                  // Recipient name
                  if (recipientName != null && recipientName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      recipientName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],

                  const SizedBox(height: 6),

                  // Status badge + mail type + dispatch code
                  Wrap(
                    spacing: 6,
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

                  const SizedBox(height: 8),

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
                      valueColor: Colors.green.shade700,
                    ),

                  // Error message
                  if (entry.lastError != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 13,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 4),
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
                  if (onRetry != null || onDismiss != null || onDelete != null) ...[
                    const SizedBox(height: 4),
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
                        if (onRetry != null && (onDismiss != null || onDelete != null))
                          const SizedBox(width: 16),
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
                          const SizedBox(width: 16),
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
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final (color, icon) = switch (status) {
      'pending' => (Colors.amber.shade700, Icons.schedule_rounded),
      'synced' => (Colors.green, Icons.check_circle_rounded),
      'error' => (Colors.red, Icons.error_rounded),
      'failed' => (Colors.red, Icons.error_rounded),
      'conflict' => (Colors.orange, Icons.warning_rounded),
      _ => (Colors.grey, Icons.help_outline_rounded),
    };

    return Icon(icon, color: color, size: 22);
  }
}

// ── Delivery Status Badge ─────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status.toLowerCase()) {
      'delivered' => (Colors.green.shade50, Colors.green.shade700, 'Delivered'),
      'pending' => (Colors.amber.shade50, Colors.amber.shade800, 'Pending'),
      'rts' => (Colors.orange.shade50, Colors.orange.shade800, 'RTS'),
      'osa' => (Colors.purple.shade50, Colors.purple.shade700, 'OSA'),
      _ => (Colors.grey.shade100, Colors.grey.shade700, status.toUpperCase()),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.3,
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700,
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Text(
        'ARCHIVED',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.purple.shade700,
          letterSpacing: 0.3,
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
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(icon, size: 13, color: dimColor),
          const SizedBox(width: 5),
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
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.isSyncing) ...[
                  Lottie.asset(
                    'assets/anim/hour-glass.json',
                    width: 160,
                    height: 160,
                    repeat: true,
                  ),
                  const SizedBox(height: 16),
                  Text('Syncing…', style: theme.textTheme.titleMedium),
                ] else ...[
                  Lottie.asset(
                    'assets/anim/successfully-done.json',
                    width: 180,
                    height: 180,
                    controller: _controller,
                    onLoaded: _onLoaded,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'All caught up!',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No pending deliveries to sync.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade500,
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

class _SyncFab extends ConsumerWidget {
  const _SyncFab({required this.syncState, required this.isOnline});

  final SyncState syncState;
  final bool isOnline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPending = syncState.entries.any(
      (e) =>
          e.status == 'pending' ||
          e.status == 'error' ||
          e.status == 'failed' ||
          e.status == 'processing',
    );
    final canSync = isOnline && !syncState.isSyncing && hasPending;

    return FloatingActionButton.extended(
      onPressed: canSync
          ? () => ref.read(syncManagerProvider.notifier).processQueue()
          : null,
      icon: syncState.isSyncing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.sync_rounded),
      label: Text(
        syncState.isSyncing
            ? 'Syncing…'
            : (isOnline ? 'Sync Now' : 'Connect to sync'),
      ),
      backgroundColor: canSync ? null : Colors.grey.shade400,
    );
  }
}
