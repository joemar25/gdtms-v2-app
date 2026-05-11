import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:fsi_courier_app/core/models/local_delivery.dart';
import 'package:fsi_courier_app/core/models/sync_operation.dart';
import 'package:fsi_courier_app/core/providers/sync_provider.dart';
import 'package:fsi_courier_app/shared/widgets/confirmation_dialog.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/features/sync/widgets/sync_entry_tile.dart';

class SyncEntryList extends ConsumerWidget {
  const SyncEntryList({
    super.key,
    required this.syncState,
    required this.deliveries,
  });

  final SyncState syncState;
  final Map<String, LocalDelivery> deliveries;

  // Priority order: conflict > pending/failed > synced.
  static int _statusPriority(String status) {
    switch (status) {
      case 'conflict':
        return 0;
      case 'pending':
      case 'failed':
      case 'processing':
        return 1;
      default:
        return 2; // synced / other
    }
  }

  /// Collapses multiple sync entries for the same Bagsakan group into one,
  /// keeping the entry with the highest-priority status (or latest if equal).
  List<SyncOperation> _collapseBagsakanEntries(List<SyncOperation> all) {
    final result = <SyncOperation>[];
    final seen = <String, int>{}; // barcode -> index in result

    for (final entry in all) {
      if (!entry.barcode.startsWith('BAGSAKAN_')) {
        result.add(entry);
        continue;
      }
      final key = entry.barcode;
      if (!seen.containsKey(key)) {
        seen[key] = result.length;
        result.add(entry);
      } else {
        final idx = seen[key]!;
        final existing = result[idx];
        if (_statusPriority(entry.status) < _statusPriority(existing.status)) {
          result[idx] = entry; // replace with higher priority
        }
        // same priority: keep existing (already latest due to DESC ordering)
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failedDeliveryCountByBarcode = ref.watch(
      failedDeliveryCountsProvider,
    );

    final entries = _collapseBagsakanEntries(syncState.entries);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(
              top: DSSpacing.sm,
              bottom: DSSpacing.massive,
            ),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return SyncEntryTile(
                key: ValueKey(entry.id),
                entry: entry,
                delivery: deliveries[entry.barcode],
                failedDeliveryAttemptsCount:
                    failedDeliveryCountByBarcode[entry.barcode] ?? 0,
                isSyncing:
                    syncState.isSyncing &&
                    syncState.currentBarcode == entry.barcode,
                onRetry: (entry.status == 'error' || entry.status == 'failed')
                    ? () async {
                        final confirmed = await ConfirmationDialog.show(
                          context,
                          title: 'sync.dialogs.retry_confirm_title'.tr(),
                          subtitle: 'sync.dialogs.retry_confirm_subtitle'.tr(),
                          confirmLabel: 'sync.list.retry_button'.tr(),
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
                          title: 'sync.dialogs.resolve_confirm_title'.tr(),
                          subtitle: 'sync.dialogs.resolve_confirm_subtitle'
                              .tr(),
                          confirmLabel: 'sync.list.resolve_button'.tr(),
                        );
                        if (confirmed == true) {
                          ref
                              .read(syncManagerProvider.notifier)
                              .dismissConflict(entry.id);
                        }
                      }
                    : null,
                onDelete: (entry.status == 'synced')
                    ? () async {
                        final confirmed = await ConfirmationDialog.show(
                          context,
                          title: 'sync.dialogs.delete_confirm_title'.tr(),
                          subtitle: 'sync.dialogs.delete_confirm_subtitle'.tr(),
                          confirmLabel: 'common.delete'.tr(),
                          isDestructive: true,
                        );
                        if (confirmed == true) {
                          ref
                              .read(syncManagerProvider.notifier)
                              .deleteSingle(entry.id);
                        }
                      }
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }
}
