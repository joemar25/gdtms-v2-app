import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:fsi_courier_app/core/models/local_delivery.dart';
import 'package:fsi_courier_app/core/providers/sync_provider.dart';
import 'package:fsi_courier_app/shared/widgets/confirmation_dialog.dart';
import 'package:fsi_courier_app/shared/widgets/pagination_bar.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/features/sync/widgets/sync_entry_tile.dart';

class SyncEntryList extends ConsumerWidget {
  const SyncEntryList({
    super.key,
    required this.syncState,
    required this.deliveries,
    required this.page,
    required this.pageSize,
    required this.onPageChanged,
  });

  final SyncState syncState;
  final Map<String, LocalDelivery> deliveries;
  final int page;
  final int pageSize;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allEntries = syncState.entries;
    final totalPages = (allEntries.length / pageSize).ceil();
    final startIndex = (page - 1) * pageSize;
    final endIndex = math.min(startIndex + pageSize, allEntries.length);
    final entries = allEntries.sublist(startIndex, endIndex);

    final failedDeliveryCountByBarcode = ref.watch(
      failedDeliveryCountsProvider,
    );

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              top: DSSpacing.sm,
              bottom: DSSpacing.massive,
            ),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
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
        if (allEntries.length > pageSize)
          PaginationBar(
            currentPage: page - 1,
            totalPages: totalPages,
            firstItem: startIndex + 1,
            lastItem: endIndex,
            totalCount: allEntries.length,
            onPageChanged: onPageChanged,
          ),
      ],
    );
  }
}
