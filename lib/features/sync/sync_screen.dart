// DOCS: docs/development-standards.md
// DOCS: docs/features/sync-history.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:fsi_courier_app/core/auth/auth_storage.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/models/local_delivery.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/sync_provider.dart';
import 'package:fsi_courier_app/core/sync/delivery_bootstrap_service.dart';
import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/widgets/confirmation_dialog.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

import 'widgets/sync_header.dart';
import 'widgets/sync_empty_state.dart';
import 'widgets/sync_entry_list.dart';

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
      title: 'sync.dialogs.reload_confirm_title'.tr(),
      subtitle: 'sync.dialogs.reload_confirm_subtitle'.tr(),
      confirmLabel: 'sync.actions.reload'.tr(),
      cancelLabel: 'common.cancel'.tr(),
      isDestructive: false,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _reloading = true);
    try {
      final client = ref.read(apiClientProvider);
      await DeliveryBootstrapService.instance.clearAndSyncFromApi(client);
      await _loadDeliveries();
      if (mounted) {
        showSuccessNotification(context, 'sync.dialogs.reload_success'.tr());
      }
    } catch (_) {
      if (mounted) {
        showErrorNotification(context, 'sync.dialogs.reload_failed'.tr());
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

    ref.listen<SyncState>(syncManagerProvider, (prev, next) {
      if (prev?.entries.length != next.entries.length) {
        _loadDeliveries();
      }
    });

    final totalPages = (syncState.entries.length / _pageSize).ceil();

    return Scaffold(
      appBar: AppHeaderBar(
        title: 'sync.title'.tr(),
        pageIcon: Icons.sync_rounded,
        actions: [
          const SecureBadge(),
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
                  : const Icon(Icons.sync_rounded, size: DSIconSize.sm),
              label: Text(
                syncState.isSyncing
                    ? 'sync.actions.syncing'.tr()
                    : 'sync.actions.sync_now'.tr(),
                style: DSTypography.button(
                  fontSize: DSTypography.sizeXs,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: DSColors.primary,
                padding: EdgeInsets.symmetric(horizontal: DSSpacing.sm),
              ),
            ),
          if (isOnline)
            IconButton(
              onPressed: canReload ? _reloadFromServer : null,
              tooltip: 'sync.actions.reload'.tr(),
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
                      size: DSIconSize.md,
                    ),
            ),
        ],
      ),
      body: SecureView(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity < -200 && _currentPage < totalPages) {
              HapticFeedback.mediumImpact();
              setState(() => _currentPage++);
            } else if (velocity > 200 && _currentPage > 1) {
              HapticFeedback.mediumImpact();
              setState(() => _currentPage--);
            }
          },
          child: Column(
            children: [
              SyncHeader(isOnline: isOnline),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    if (ref.read(isOnlineProvider)) {
                      await ref
                          .read(syncManagerProvider.notifier)
                          .processQueue();
                    }
                    await ref.read(syncManagerProvider.notifier).loadEntries();
                  },
                  child: syncState.entries.isEmpty
                      ? SyncEmptyState(isSyncing: syncState.isSyncing)
                      : SyncEntryList(
                          syncState: syncState,
                          deliveries: _deliveries,
                          page: _currentPage,
                          pageSize: _pageSize,
                          onPageChanged: (p) =>
                              setState(() => _currentPage = p + 1),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
