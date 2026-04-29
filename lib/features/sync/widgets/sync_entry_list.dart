import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/core/models/sync_operation.dart';
import 'package:fsi_courier_app/core/models/delivery_status.dart';
import 'package:fsi_courier_app/core/models/local_delivery.dart';
import 'package:fsi_courier_app/core/providers/sync_provider.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_helper.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/widgets/confirmation_dialog.dart';
import 'package:fsi_courier_app/shared/widgets/pagination_bar.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

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

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
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
                          subtitle:
                              'sync.dialogs.resolve_confirm_subtitle'.tr(),
                          confirmLabel: 'sync.list.resolve_button'.tr(),
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
                },
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

  String get _payloadStatus {
    try {
      final map = jsonDecode(entry.payloadJson) as Map<String, dynamic>;
      return map['delivery_status']?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  ({String deliveryDate, String transactionDate, String dispatchDate})
  get _dates {
    if (delivery == null) {
      return (deliveryDate: '', transactionDate: '', dispatchDate: '');
    }
    final raw = delivery!.toDeliveryMap();
    final transactionAt = raw['transaction_at']?.toString() ?? '';
    final deliveredDate = raw['delivered_date']?.toString() ?? '';
    final dispatchedAt = raw['dispatched_at']?.toString() ?? '';
    final deliveredAtMs = delivery!.deliveredAt;
    final String dlDateResolved;
    if (deliveredAtMs != null) {
      dlDateResolved = formatEpoch(deliveredAtMs);
    } else if (deliveredDate.isNotEmpty) {
      dlDateResolved = formatDate(deliveredDate, includeTime: true);
    } else {
      dlDateResolved = '';
    }

    final DateTime? txDt = transactionAt.isNotEmpty
        ? parseServerDate(transactionAt)
        : null;
    final DateTime? dlDtFromServer = deliveredDate.isNotEmpty
        ? parseServerDate(deliveredDate)
        : null;

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
        : formatEpoch(entry.createdAt);

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
    final queuedStr = formatEpoch(entry.createdAt);
    final syncedStr = (entry.status == 'synced' && entry.lastAttemptAt != null)
        ? formatEpoch(entry.lastAttemptAt!)
        : null;

    final recipientName = delivery?.recipientName;
    final mailType = delivery?.mailType;
    final dispatchCode = delivery?.dispatchCode;
    final payloadStatus = _payloadStatus;
    final dates = _dates;
    final String? delStatus = delivery?.deliveryStatus;
    final currentStatus = (delStatus != null && delStatus.isNotEmpty)
        ? delStatus
        : payloadStatus;
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
              String msg = 'sync.list.locked_general'
                  .tr(args: [currentStatus.toLowerCase()]);
              if (s == 'OSA') {
                msg = 'sync.list.locked_osa'.tr();
              } else if (s == 'DELIVERED') {
                msg = 'sync.list.locked_delivered'.tr();
              } else if (s == 'FAILED_DELIVERY' && attemptsCount >= 3) {
                msg = 'sync.list.locked_failed_max'.tr();
              } else if (s == 'FAILED_DELIVERY' &&
                  (v == 'verified_with_pay' || v == 'verified_no_pay')) {
                msg = 'sync.list.locked_failed_verified'.tr();
              }
              showInfoNotification(context, msg);
            }
          : (entry.operationType == 'UPDATE_PROFILE')
          ? () => showInfoNotification(
                context,
                'sync.list.profile_update_info'.tr(),
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
            Padding(
              padding: EdgeInsets.only(top: DSSpacing.xs),
              child: _StatusChip(status: entry.status, isSyncing: isSyncing),
            ),
            DSSpacing.wMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  if (dates.deliveryDate.isNotEmpty)
                    _MetaRow(
                      icon: Icons.local_shipping_outlined,
                      label: 'sync.list.delivered_label'.tr(),
                      value: dates.deliveryDate,
                    ),
                  if (dates.transactionDate.isNotEmpty)
                    _MetaRow(
                      icon: Icons.receipt_outlined,
                      label: 'sync.list.transaction_label'.tr(),
                      value: dates.transactionDate,
                    ),
                  if (dates.deliveryDate.isEmpty &&
                      dates.dispatchDate.isNotEmpty)
                    _MetaRow(
                      icon: Icons.call_made_rounded,
                      label: 'sync.list.dispatched_label'.tr(),
                      value: dates.dispatchDate,
                    ),
                  _MetaRow(
                    icon: Icons.cloud_upload_outlined,
                    label: 'sync.list.queued_label'.tr(),
                    value: queuedStr,
                  ),
                  if (syncedStr != null)
                    _MetaRow(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'sync.list.synced_label'.tr(),
                      value: syncedStr,
                      valueColor: DSColors.success,
                    ),
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
                              child: Text('sync.list.retry_button'.tr()),
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
                              child: Text('sync.list.resolve_button'.tr()),
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
      _ => (
        Theme.of(context).brightness == Brightness.dark
            ? DSColors.labelSecondaryDark
            : DSColors.labelSecondary,
        Icons.help_outline_rounded,
      ),
    };

    return Icon(icon, color: color, size: DSIconSize.lg);
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final ds = DeliveryStatus.fromString(status);
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
        Theme.of(context).brightness == Brightness.dark
            ? DSColors.secondarySurfaceDark
            : DSColors.secondarySurfaceLight,
        Theme.of(context).brightness == Brightness.dark
            ? DSColors.labelSecondaryDark
            : DSColors.labelSecondary,
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
          color: Theme.of(context).brightness == Brightness.dark
              ? DSColors.labelSecondaryDark
              : DSColors.labelSecondary,
        ).copyWith(fontSize: DSTypography.sizeSm, fontWeight: FontWeight.w600),
      ),
    );
  }
}

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
        'sync.list.archived_label'.tr(),
        style: DSTypography.label(color: DSColors.accent).copyWith(
          fontSize: DSTypography.sizeSm,
          letterSpacing: DSTypography.lsLoose,
        ),
      ),
    );
  }
}

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
