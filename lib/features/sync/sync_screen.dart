// DOCS: docs/development-standards.md
// DOCS: docs/features/sync-history.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:fsi_courier_app/core/auth/auth_storage.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/models/local_delivery.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/sync_provider.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
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

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncManagerProvider);
    final connectionStatus = ref.watch(connectionStatusProvider);

    ref.listen<SyncState>(syncManagerProvider, (prev, next) {
      if (prev?.entries.length != next.entries.length) {
        _loadDeliveries();
      }
    });

    return Scaffold(
      appBar: AppHeaderBar(
        title: 'sync.title'.tr(),
        actions: const [SecureBadge(), DSSpacing.wSm],
      ),
      body: SecureView(
        child: Column(
          children: [
            SyncHeader(connectionStatus: connectionStatus),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  if (ref.read(connectionStatusProvider) ==
                      ConnectionStatus.online) {
                    await ref.read(syncManagerProvider.notifier).processQueue();
                  }
                  await ref.read(syncManagerProvider.notifier).loadEntries();
                },
                child: syncState.entries.isEmpty
                    ? SyncEmptyState(isSyncing: syncState.isSyncing)
                    : SyncEntryList(
                        syncState: syncState,
                        deliveries: _deliveries,
                      ),
              ).dsFadeEntry(duration: DSAnimations.dNormal),
            ),
          ],
        ),
      ),
    );
  }
}
