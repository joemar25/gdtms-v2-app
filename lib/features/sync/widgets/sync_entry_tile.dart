// DOCS: docs/features/sync-history.md
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/core/models/sync_operation.dart';
import 'package:fsi_courier_app/core/models/local_delivery.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_helper.dart';
import 'package:fsi_courier_app/core/models/delivery_status.dart';

class SyncEntryTile extends StatelessWidget {
  const SyncEntryTile({
    super.key,
    required this.entry,
    this.delivery,
    this.isSyncing = false,
    this.failedDeliveryAttemptsCount = 0,
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
    return entry.payload['delivery_status']?.toString() ?? '';
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
    final String txDate = isSameInstant ? '' : formatEpoch(entry.createdAt);

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
    final product = delivery?.product;
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

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: DSSpacing.md,
        vertical: DSSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(DSStyles.radiusMD),
        boxShadow: DSStyles.shadowXS(context),
      ),
      child: Material(
        color: DSColors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(DSStyles.radiusMD),
          onTap: isLocked
              ? () {
                  final s = currentStatus.toUpperCase();
                  final v = currentFailedDeliveryVerif;
                  String msg = 'sync.list.locked_general'.tr(
                    args: [currentStatus.toLowerCase()],
                  );
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
          child: IntrinsicHeight(
            child: Row(
              children: [
                // ── Status Indicator Bar ─────────────────────────────────
                _StatusBarIndicator(status: entry.status, isSyncing: isSyncing),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(DSSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.barcode,
                                style: DSTypography.heading(fontSize: 14)
                                    .copyWith(
                                      fontFamily: 'monospace',
                                      letterSpacing: 1.0,
                                    ),
                              ),
                            ),
                            _StatusChipCompact(status: entry.status),
                          ],
                        ),
                        if (recipientName != null &&
                            recipientName.isNotEmpty &&
                            !isLocked) ...[
                          DSSpacing.hXs,
                          Builder(
                            builder: (context) {
                              final dMap = delivery!.toDeliveryMap();
                              final authRep =
                                  (dMap['authorized_rep']?.toString() ??
                                          dMap['recipient']?.toString() ??
                                          '')
                                      .trim();
                              final isDifferent =
                                  authRep.isNotEmpty &&
                                  authRep.toLowerCase() !=
                                      recipientName.toLowerCase();
                              return Text(
                                isDifferent
                                    ? '$recipientName (Recipient)'
                                    : recipientName,
                                style: DSTypography.body(
                                  fontWeight: FontWeight.w600,
                                  fontSize: DSTypography.sizeSm,
                                ),
                              );
                            },
                          ),
                        ],
                        DSSpacing.hSm,
                        Wrap(
                          spacing: DSSpacing.sm,
                          runSpacing: DSSpacing.xs,
                          children: [
                            if (payloadStatus.isNotEmpty)
                              _StatusBadge(status: payloadStatus),
                            if (product != null && product.isNotEmpty)
                              _Chip(product.toUpperCase()),
                            if (mailType != null &&
                                mailType.isNotEmpty &&
                                (product == null ||
                                    !product.toUpperCase().contains(
                                      mailType.toUpperCase(),
                                    )))
                              _Chip(mailType.toUpperCase()),
                            if (dispatchCode != null && dispatchCode.isNotEmpty)
                              _Chip(dispatchCode),
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
                                  style: DSTypography.caption(
                                    color: DSColors.error,
                                    fontSize: DSTypography.sizeXs,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (entry.status != 'synced' &&
                            entry.mediaPathsJson != null) ...[
                          _MediaGallery(mediaPathsJson: entry.mediaPathsJson),
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
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: onRetry,
                                    child: Text(
                                      'sync.list.retry_button'.tr(),
                                      style: DSTypography.button(
                                        color: DSColors.primary,
                                        fontSize: DSTypography.sizeXs,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
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
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: onDismiss,
                                    child: Text(
                                      'sync.list.resolve_button'.tr(),
                                      style: DSTypography.button(
                                        color: DSColors.primary,
                                        fontSize: DSTypography.sizeXs,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBarIndicator extends StatelessWidget {
  const _StatusBarIndicator({required this.status, required this.isSyncing});
  final String status;
  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    final color = isSyncing || status == 'processing'
        ? DSColors.primary
        : switch (status) {
            'pending' => DSColors.warning,
            'synced' => DSColors.success,
            'error' || 'failed' => DSColors.error,
            'conflict' => DSColors.pending,
            _ => DSColors.labelTertiary,
          };

    return Container(
      width: 4,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(DSStyles.radiusMD),
          bottomLeft: Radius.circular(DSStyles.radiusMD),
        ),
      ),
    );
  }
}

class _StatusChipCompact extends StatelessWidget {
  const _StatusChipCompact({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      'pending' => (DSColors.warningSurface, DSColors.warningText, 'PENDING'),
      'synced' => (DSColors.successSurface, DSColors.successText, 'SYNCED'),
      'error' ||
      'failed' => (DSColors.errorSurface, DSColors.errorText, 'FAILED'),
      'conflict' => (DSColors.pendingSurface, DSColors.pendingText, 'CONFLICT'),
      'processing' => (
        DSColors.primary.withValues(alpha: 0.1),
        DSColors.primary,
        'SYNCING...',
      ),
      _ => (
        DSColors.secondarySurfaceLight,
        DSColors.labelSecondary,
        status.toUpperCase(),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: DSTypography.label(color: fg).copyWith(fontSize: 8),
      ),
    );
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
        style: DSTypography.label(color: fg, fontSize: DSTypography.sizeSm),
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
          fontSize: DSTypography.sizeSm,
          fontWeight: FontWeight.w600,
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
            style: DSTypography.caption(
              color: dimColor,
              fontWeight: FontWeight.w500,
              fontSize: DSTypography.sizeXs,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: DSTypography.caption(
                color: valueColor ?? dimColor,
                fontWeight: valueColor != null ? FontWeight.w600 : null,
                fontSize: DSTypography.sizeXs,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaGallery extends StatelessWidget {
  const _MediaGallery({required this.mediaPathsJson});
  final String? mediaPathsJson;

  static const _typeLabels = {
    'pod': 'POD',
    'selfie': 'Selfie',
    'recipient_signature': 'Signature',
    'photo': 'Photo',
  };

  Map<String, String> get _paths {
    if (mediaPathsJson == null) return {};
    try {
      final raw = jsonDecode(mediaPathsJson!) as Map<String, dynamic>;
      return raw.map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      return {};
    }
  }

  String _labelFor(String key) {
    if (_typeLabels.containsKey(key)) return _typeLabels[key]!;
    if (key.startsWith('photo')) {
      final idx = key.replaceAll(RegExp(r'[^0-9]'), '');
      return idx.isEmpty ? 'Photo' : 'Photo ${int.parse(idx) + 1}';
    }
    return key.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final paths = _paths;
    if (paths.isEmpty) return const SizedBox.shrink();
    final dimColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DSSpacing.hSm,
        Row(
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: DSIconSize.xs,
              color: dimColor,
            ),
            DSSpacing.wXs,
            Text(
              'Photos — Awaiting Sync',
              style: DSTypography.caption(
                color: dimColor,
                fontWeight: FontWeight.w600,
                fontSize: DSTypography.sizeXs,
              ),
            ),
          ],
        ),
        DSSpacing.hXs,
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: paths.entries.map((e) {
              return Padding(
                padding: EdgeInsets.only(right: DSSpacing.sm),
                child: _MediaThumb(path: e.value, label: _labelFor(e.key)),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _MediaThumb extends StatelessWidget {
  const _MediaThumb({required this.path, required this.label});
  final String path;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dimColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(DSStyles.radiusMD),
          child: SizedBox(
            width: 64,
            height: 64,
            child: Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: isDark
                    ? DSColors.cardDark
                    : DSColors.secondarySurfaceLight,
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 24,
                  color: dimColor.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: DSTypography.caption(
            color: dimColor,
            fontSize: DSTypography.sizeXs,
          ),
        ),
      ],
    );
  }
}
