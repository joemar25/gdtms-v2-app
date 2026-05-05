// DOCS: docs/development-standards.md
// DOCS: docs/shared/widgets.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fsi_courier_app/core/models/delivery_status.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_helper.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_identifier.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_form_helpers.dart';
import 'package:fsi_courier_app/shared/widgets/delivery_card_components.dart';
import 'package:fsi_courier_app/shared/widgets/delivery_other_info.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

/// A card representing a single delivery assignment with its status,
/// barcode, recipient details, and action shortcuts.
class DeliveryCard extends StatelessWidget {
  const DeliveryCard({
    super.key,
    required this.delivery,
    required this.onTap,
    this.compact = false,
    this.showChevron = true,
    this.enableHoldToReveal = true,
    this.footerText,
    this.footerIcon,
    this.isChecking = false,
    this.showLockIcon = true,
    this.isPrivacyMode = false,
    this.onUpdateTap,
  });

  final Map<String, dynamic> delivery;
  final VoidCallback? onTap;
  final bool compact;
  final bool showChevron;
  final bool enableHoldToReveal;
  final String? footerText;
  final IconData? footerIcon;
  final bool isChecking;
  final bool showLockIcon;
  final bool isPrivacyMode;

  /// When non-null an "Update" action is rendered inside the card.
  /// Pass null to hide it (locked / non-updatable items).
  final VoidCallback? onUpdateTap;

  // ─── MARK: Status Helpers ──────────────────────────────────────────────────

  static Color statusColor(String status) {
    return DSColors.statusColor(status);
  }

  static IconData statusIcon(String status) {
    return switch (DeliveryStatus.fromString(status)) {
      DeliveryStatus.pending => Icons.schedule_rounded,
      DeliveryStatus.delivered => Icons.check_circle_rounded,
      DeliveryStatus.failedDelivery => Icons.assignment_return_rounded,
      DeliveryStatus.osa => Icons.inventory_2_rounded,
      _ => Icons.help_outline_rounded,
    };
  }

  // ─── MARK: Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isExpanded = !compact;
    final delivery = this.delivery;
    final barcode = resolveDeliveryIdentifier(delivery);
    final rawStatus = delivery['delivery_status']?.toString() ?? '';
    final status = rawStatus.toUpperCase().trim();
    final ds = DeliveryStatus.fromString(status);
    final mailType = (delivery['mail_type'] ?? '').toString();
    final product = (delivery['product'] ?? '').toString();

    final address = (delivery['recipient_address'] ?? '').toString();
    final name = (delivery['recipient_name'] ?? '').toString();

    final attemptsCount = getAttemptsCountFromMap(delivery);

    final syncStatus = delivery['_sync_status']?.toString() ?? 'clean';
    final isDirty = syncStatus == 'dirty';
    final inSyncQueue = delivery['_in_sync_queue'] == true;

    final colorForStatus = isDirty ? DSColors.warning : statusColor(status);
    final iconForStatus = statusIcon(status);

    final failedDeliveryVerifStatus =
        (delivery['_rts_verification_status']?.toString() ??
                delivery['rts_verification_status']?.toString() ??
                delivery['_failed_delivery_verification_status']?.toString() ??
                delivery['failed_delivery_verification_status']?.toString() ??
                'unvalidated')
            .toLowerCase();
    final rv = FailedDeliveryVerificationStatus.fromString(
      failedDeliveryVerifStatus,
    );
    final isFailedWithPay = ds == DeliveryStatus.failedDelivery && rv.isWithPay;
    final isFailedNoPay =
        ds == DeliveryStatus.failedDelivery &&
        rv == FailedDeliveryVerificationStatus.verifiedNoPay;
    final isLocked = checkIsLockedFromMap(delivery);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Visibility check
    final isArchived = delivery['_is_archived'] == true;
    final now = DateTime.now();
    final todayStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;
    final tomorrowStart = DateTime(
      now.year,
      now.month,
      now.day + 1,
    ).millisecondsSinceEpoch;

    bool isVisible = false;
    if (!isArchived) {
      if (ds == DeliveryStatus.pending || status == '') {
        isVisible = true;
      } else if (ds == DeliveryStatus.delivered) {
        final deliveredAt = delivery['_delivered_at'] as int? ?? 0;
        isVisible = deliveredAt >= todayStart && deliveredAt < tomorrowStart;
      } else if (ds == DeliveryStatus.failedDelivery) {
        final completedAt = delivery['_completed_at'] as int? ?? 0;
        isVisible =
            completedAt >= todayStart &&
            completedAt < tomorrowStart &&
            !isFailedWithPay &&
            !isFailedNoPay;
      } else if (ds == DeliveryStatus.osa) {
        final completedAt = delivery['_completed_at'] as int? ?? 0;
        isVisible = completedAt >= todayStart && completedAt < tomorrowStart;
      }
    }

    // STRICT RULE: If the card is locked (finalized/verified), hide the info button
    // for privacy and to prevent further modifications. This is mandatory.
    final canViewInfo =
        !isPrivacyMode &&
        !isChecking &&
        !isLocked &&
        ds != DeliveryStatus.unknown;

    if (compact) {
      return _buildCompactCard(
        context: context,
        isDark: isDark,
        statusColor: colorForStatus,
        status: status,
        barcode: barcode,
        name: name,
        isDirty: isDirty,
        isFailedWithPay: isFailedWithPay,
        isFailedNoPay: isFailedNoPay,
        isLocked: isLocked,
        isVisible: isVisible,
        inSyncQueue: inSyncQueue,
        product: product,
        mailType: mailType,
        address: address,
        attemptsCount: attemptsCount,
      );
    }

    // ── Colors ──────────────────────────────────────────────────────────────
    final cardBg = isDark ? DSColors.cardDark : DSColors.cardLight;
    final cardBorder = isDark
        ? DSColors.separatorDark
        : DSColors.separatorLight;
    final subtextColor = isDark
        ? DSColors.labelSecondaryDark
        : DSColors.labelSecondary;

    // ── Card widget — radius is controlled externally by _SlidableRadiusMorph ─
    Widget buildCard({BorderRadius? borderRadius}) {
      final effectiveRadius = borderRadius ?? DSStyles.cardRadius;
      return BouncingCardWrapper(
        onTap: isChecking ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.fastOutSlowIn,
          width: double.infinity,
          margin: EdgeInsets.zero,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: effectiveRadius,
            border: Border.all(color: cardBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? DSColors.black.withValues(alpha: DSStyles.alphaMuted)
                    : DSColors.black.withValues(alpha: DSStyles.alphaSoft),
                blurRadius: DSStyles.elevationNone,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: DSColors.transparent,
            child: InkWell(
              borderRadius: effectiveRadius,
              onTap: isChecking ? null : onTap,
              onLongPress: (isChecking || isLocked)
                  ? null
                  : () => _showHoldOptions(context, isDark),
              splashColor: colorForStatus.withValues(alpha: DSStyles.alphaSoft),
              highlightColor: colorForStatus.withValues(
                alpha: DSStyles.alphaSoft,
              ),
              child: AnimatedOpacity(
                opacity: isChecking ? 0.55 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Status accent bar ─────────────────────────────────────
                    Container(
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorForStatus,
                            colorForStatus.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),

                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: DSSpacing.md,
                        vertical: DSSpacing.md,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Row 1: Status pill + Job Order + Chevron ─────────
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (!isPrivacyMode &&
                                  (status.isNotEmpty || isDirty))
                                DeliveryStatusBadge(
                                  label: isDirty
                                      ? 'UNSYNCED'
                                      : status.replaceAll('_', ' '),
                                  color: colorForStatus,
                                  icon: isDirty
                                      ? Icons.sync_problem_rounded
                                      : iconForStatus,
                                ),
                              if (!isPrivacyMode &&
                                  (status.isNotEmpty || isDirty))
                                DSSpacing.wSm,
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (attemptsCount > 0)
                                      Flexible(
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                            left: DSSpacing.xs,
                                          ),
                                          child: DeliveryMiniPill(
                                            label:
                                                ds == DeliveryStatus.delivered
                                                ? 'FAILED ATTEMPTS: $attemptsCount'
                                                : 'ATTEMPTS: $attemptsCount',
                                            icon: Icons.autorenew_rounded,
                                            bg:
                                                (attemptsCount >= 3
                                                        ? DSColors.error
                                                        : DSColors.warning)
                                                    .withValues(
                                                      alpha:
                                                          DSStyles.alphaSubtle,
                                                    ),
                                            border:
                                                (attemptsCount >= 3
                                                        ? DSColors.error
                                                        : DSColors.warning)
                                                    .withValues(
                                                      alpha:
                                                          DSStyles.alphaMuted,
                                                    ),
                                            fg: attemptsCount >= 3
                                                ? DSColors.error
                                                : DSColors.warning,
                                          ),
                                        ),
                                      ),
                                    if (canViewInfo)
                                      Padding(
                                        padding: EdgeInsets.only(
                                          left: DSSpacing.xs,
                                        ),
                                        child: InkWell(
                                          onTap: () {
                                            HapticFeedback.lightImpact();
                                            showDeliveryAccountDetails(
                                              context,
                                              delivery,
                                              barcode,
                                            );
                                          },
                                          borderRadius: DSStyles.pillRadius,
                                          child: Container(
                                            padding: const EdgeInsets.all(
                                              DSSpacing.xs,
                                            ),
                                            child: Icon(
                                              Icons.info_outline_rounded,
                                              size: DSIconSize.md,
                                              color: DSColors.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (showLockIcon &&
                                        (isLocked || !isVisible))
                                      Padding(
                                        padding: EdgeInsets.only(
                                          left: DSSpacing.xs,
                                        ),
                                        child: Icon(
                                          Icons.lock_outline_rounded,
                                          color: isLocked
                                              ? subtextColor
                                              : DSColors.error,
                                          size: DSIconSize.xs,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          DSSpacing.hMd,

                          // ── Row 2: Barcode (large) ────────────────────────────
                          Row(
                            children: [
                              Icon(
                                Icons.qr_code_scanner_rounded,
                                size: DSIconSize.xs,
                                color: subtextColor,
                              ),
                              DSSpacing.wXs,
                              Flexible(
                                child: Text(
                                  barcode.isEmpty ? 'UNKNOWN' : barcode,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      DSTypography.title(
                                        color: isDark
                                            ? DSColors.white
                                            : DSColors.labelPrimary,
                                      ).copyWith(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w800,
                                        fontSize: DSTypography.sizeMd,
                                        letterSpacing:
                                            DSTypography.lsExtraLoose,
                                      ),
                                ),
                              ),
                            ],
                          ),

                          // ── Row 3: Recipient name ────────────────────────────
                          if (!isPrivacyMode &&
                              name.isNotEmpty &&
                              !isLocked) ...[
                            DSSpacing.hXs,
                            Row(
                              children: [
                                Icon(
                                  Icons.person_outline_rounded,
                                  size: DSIconSize.xs,
                                  color: subtextColor,
                                ),
                                DSSpacing.wXs,
                                Flexible(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        DSTypography.body(
                                          color: isDark
                                              ? DSColors.labelPrimaryDark
                                              : DSColors.labelPrimary,
                                        ).copyWith(
                                          fontSize: DSTypography.sizeSm,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // ── Row 4: Address ───────────────────────────────────
                          if (!isPrivacyMode &&
                              address.isNotEmpty &&
                              !isLocked) ...[
                            DSSpacing.hXs,
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(top: DSSpacing.xs),
                                  child: Icon(
                                    Icons.location_on_outlined,
                                    size: DSIconSize.xs,
                                    color: subtextColor,
                                  ),
                                ),
                                DSSpacing.wXs,
                                Expanded(
                                  child: Text(
                                    address,
                                    maxLines: isExpanded ? null : 1,
                                    overflow: isExpanded
                                        ? null
                                        : TextOverflow.ellipsis,
                                    style: DSTypography.caption(
                                      color: subtextColor,
                                    ).copyWith(height: DSStyles.heightNormal),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // ── Metadata chips ───────────────────────────────────
                          if (!isPrivacyMode &&
                              delivery['metadata'] is List) ...[
                            DSSpacing.hMd,
                            Wrap(
                              spacing: DSSpacing.sm,
                              runSpacing: DSSpacing.sm,
                              children: (delivery['metadata'] as List).map((m) {
                                final map = m as Map<String, dynamic>;
                                return InfoChip(
                                  icon: map['icon'] as IconData,
                                  label: map['label'] as String,
                                  isDark: isDark,
                                );
                              }).toList(),
                            ),
                          ],

                          // ── Sync / Paid pills row ────────────────────────────
                          if (!isPrivacyMode && (isDirty || inSyncQueue)) ...[
                            DSSpacing.hMd,
                            Wrap(
                              spacing: DSSpacing.sm,
                              runSpacing: DSSpacing.sm,
                              children: [
                                if (isDirty)
                                  DeliveryMiniPill(
                                    label: 'UNSYNCED',
                                    icon: Icons.sync_problem_rounded,
                                    bg: DSColors.warning.withValues(
                                      alpha: DSStyles.alphaSubtle,
                                    ),
                                    border: DSColors.warning.withValues(
                                      alpha: DSStyles.alphaMuted,
                                    ),
                                    fg: DSColors.warning,
                                  ),
                                if (inSyncQueue)
                                  DeliveryMiniPill(
                                    label: 'PENDING SYNC',
                                    icon: Icons.sync_lock_rounded,
                                    bg: DSColors.primary.withValues(
                                      alpha: DSStyles.alphaSubtle,
                                    ),
                                    border: DSColors.primary.withValues(
                                      alpha: DSStyles.alphaMuted,
                                    ),
                                    fg: DSColors.primary,
                                  ),
                              ],
                            ),
                          ],

                          // ── Footer ───────────────────────────────────────────
                          if (footerText != null || isChecking) ...[
                            DSSpacing.hMd,
                            Row(
                              children: [
                                if (isChecking) ...[
                                  const DSLoading(size: DSIconSize.xs),
                                  DSSpacing.wXs,
                                  Text(
                                    'Checking eligibility…',
                                    style: DSTypography.caption(
                                      color: subtextColor,
                                    ).copyWith(fontSize: DSTypography.sizeSm),
                                  ),
                                ] else if (footerText != null) ...[
                                  Icon(
                                    footerIcon ?? Icons.info_outline,
                                    size: DSIconSize.xs,
                                    color: subtextColor,
                                  ),
                                  DSSpacing.wXs,
                                  Text(
                                    footerText!,
                                    style: DSTypography.caption(
                                      color: subtextColor,
                                    ).copyWith(fontSize: DSTypography.sizeSm),
                                  ),
                                ],
                              ],
                            ),
                          ],

                          // ── Detail section (Auto-visible if not compact) ───────
                          if (isExpanded && !isPrivacyMode)
                            _buildDetailSection(
                              delivery,
                              isDark,
                              subtextColor,
                              ds: ds,
                              rv: rv,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: DSSpacing.md),
      child: buildCard(),
    );
  }

  // ─── MARK: Handlers ────────────────────────────────────────────────────────

  void _showHoldOptions(BuildContext context, bool isDark) {
    HapticFeedback.mediumImpact();
    final barcode = delivery['barcode']?.toString() ?? '';
    showDeliveryAccountDetails(context, delivery, barcode);
  }

  // ─── MARK: Components ──────────────────────────────────────────────────────

  // ── Detail section ──────────────────────────────────────────────
  Widget _buildDetailSection(
    Map<String, dynamic> delivery,
    bool isDark,
    Color subtextColor, {
    required DeliveryStatus ds,
    required FailedDeliveryVerificationStatus rv,
  }) {
    final product = delivery['product']?.toString() ?? '';
    final specialInstr = delivery['special_instruction']?.toString() ?? '';
    final transactionAt = delivery['transaction_at']?.toString() ?? '';
    final deliveredAtMs = delivery['_delivered_at'] as int?;
    final deliveredDate = delivery['delivered_date']?.toString() ?? '';
    final isLocked = checkIsLockedFromMap(delivery);

    final hasDetails =
        (transactionAt.isNotEmpty && ds != DeliveryStatus.pending) ||
        product.isNotEmpty ||
        specialInstr.isNotEmpty;

    if (!hasDetails) return const SizedBox.shrink();

    final dividerColor = isDark
        ? DSColors.white.withValues(alpha: DSStyles.alphaSoft)
        : DSColors.black.withValues(alpha: DSStyles.alphaSoft);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DSSpacing.hSm,
        Divider(height: DSStyles.borderWidth, color: dividerColor),
        DSSpacing.hSm,

        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (ds == DeliveryStatus.delivered)
              if (deliveredAtMs != null || deliveredDate.isNotEmpty)
                Expanded(
                  child: DeliveryDetailCell(
                    label: 'TRANSACTION',
                    value: deliveredAtMs != null
                        ? formatEpoch(deliveredAtMs)
                        : formatDate(deliveredDate, includeTime: true),
                    isDark: isDark,
                    subtextColor: subtextColor,
                    valueColor: DSColors.success,
                  ),
                )
              else
                const SizedBox.shrink()
            else if (transactionAt.isNotEmpty && ds != DeliveryStatus.pending)
              Expanded(
                child: DeliveryDetailCell(
                  label: 'TRANSACTION',
                  value: formatDate(transactionAt, includeTime: true),
                  isDark: isDark,
                  subtextColor: subtextColor,
                ),
              ),
          ],
        ),

        // Show PRODUCT below SEQUENCE/TRANSACTION row if available
        if (product.isNotEmpty) ...[
          DSSpacing.hSm,
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: DeliveryDetailCell(
                  label: 'PRODUCT',
                  value: product,
                  isDark: isDark,
                  subtextColor: subtextColor,
                ),
              ),
              if (ds == DeliveryStatus.failedDelivery && !isLocked)
                _buildVerificationPill(rv),
            ],
          ),
        ],

        DeliveryOtherInfoSection(
          product: '', // Product is shown separately in the detail row above
          isDark: isDark,
          subtextColor: subtextColor,
          showTitle: false,
          isExpandedCard: true,
        ),
        DSSpacing.hXs,
      ],
    );
  }

  // ── Compact card ───────────────────────────────────────────────────────────
  Widget _buildCompactCard({
    required BuildContext context,
    required bool isDark,
    required Color statusColor,
    required String status,
    required String barcode,
    required String name,
    required bool isDirty,
    required bool isFailedWithPay,
    required bool isFailedNoPay,
    required bool isLocked,
    required bool isVisible,
    required bool inSyncQueue,
    required String product,
    required String mailType,
    required String address,
    required int attemptsCount,
  }) {
    final ds = DeliveryStatus.fromString(status);
    final cardBg = isDark ? DSColors.cardDark : DSColors.cardLight;
    final subtextColor = isDark
        ? DSColors.labelSecondaryDark
        : DSColors.labelSecondary;
    final cardBorder = isDark
        ? DSColors.separatorDark
        : DSColors.separatorLight;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: DSSpacing.sm),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: DSStyles.cardRadius,
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? DSColors.black.withValues(alpha: DSStyles.alphaMuted)
                : DSColors.black.withValues(alpha: DSStyles.alphaSoft),
            blurRadius: DSStyles.radiusSM * 0.75,
            offset: const Offset(0, DSSpacing.xs),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left accent bar
            Container(
              width: DSSpacing.xs,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    statusColor,
                    statusColor.withValues(alpha: DSStyles.alphaMuted),
                  ],
                ),
              ),
            ),
            // Content
            Expanded(
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: DSSpacing.md,
                    vertical: 9,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: (isPrivacyMode && !showChevron)
                              ? Alignment.center
                              : Alignment.centerLeft,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (!isPrivacyMode && name.isNotEmpty) ...[
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person_outline_rounded,
                                      size: DSIconSize.xs,
                                      color: subtextColor,
                                    ),
                                    DSSpacing.wXs,
                                    Flexible(
                                      child: Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            DSTypography.body(
                                              color: isDark
                                                  ? DSColors.labelPrimaryDark
                                                  : DSColors.labelPrimary,
                                            ).copyWith(
                                              fontSize: DSTypography.sizeSm,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                DSSpacing.hXs,
                              ],
                              Row(
                                children: [
                                  Icon(
                                    Icons.qr_code_scanner_rounded,
                                    size: DSIconSize.xs,
                                    color: subtextColor,
                                  ),
                                  DSSpacing.wXs,
                                  Flexible(
                                    child: Text(
                                      barcode.isEmpty ? 'UNKNOWN' : barcode,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          DSTypography.body(
                                            color: isDark
                                                ? DSColors.labelPrimaryDark
                                                : DSColors.labelPrimary,
                                          ).copyWith(
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.w800,
                                            fontSize: DSTypography.sizeSm,
                                            letterSpacing: DSTypography.lsLoose,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              DSSpacing.hXs,
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(top: 2),
                                    child: Icon(
                                      Icons.location_on_outlined,
                                      size: DSIconSize.xs,
                                      color: subtextColor,
                                    ),
                                  ),
                                  DSSpacing.wXs,
                                  Flexible(
                                    child: Text(
                                      isPrivacyMode
                                          ? (product.isNotEmpty
                                                ? product
                                                : 'DELIVERY ITEM')
                                          : address,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          DSTypography.caption(
                                            color: subtextColor,
                                          ).copyWith(
                                            fontSize: DSTypography.sizeXs,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: DSTypography.lsLoose,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      DSSpacing.wSm,
                      if (!isPrivacyMode)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isDirty)
                              DeliveryTinyPill(
                                label: 'UNSYNC',
                                color: DSColors.warning,
                              ),
                            if (inSyncQueue)
                              DeliveryTinyPill(
                                label: 'SYNC',
                                color: DSColors.primary,
                              ),
                            if (attemptsCount > 0)
                              DeliveryTinyPill(
                                label: ds == DeliveryStatus.delivered
                                    ? 'FA:$attemptsCount'
                                    : 'A:$attemptsCount',
                                color: attemptsCount >= 3
                                    ? DSColors.error
                                    : DSColors.pending,
                              ),
                            if (ds == DeliveryStatus.failedDelivery &&
                                !isLocked)
                              DeliveryTinyPill(
                                label: (isFailedWithPay || isFailedNoPay)
                                    ? 'ITEM RETURNED'
                                    : 'IN POSSESSION',
                                color: (isFailedWithPay || isFailedNoPay)
                                    ? DSColors.success
                                    : DSColors.warning,
                              ),
                          ],
                        ),
                      if (!isPrivacyMode && isLocked)
                        Padding(
                          padding: EdgeInsets.only(left: DSSpacing.sm),
                          child: Icon(
                            Icons.lock_outline_rounded,
                            color: subtextColor,
                            size: DSIconSize.xs,
                          ),
                        )
                      else if (!isPrivacyMode && !isVisible)
                        Padding(
                          padding: EdgeInsets.only(left: DSSpacing.sm),
                          child: Icon(
                            Icons.lock_outline_rounded,
                            color: DSColors.error,
                            size: DSIconSize.xs,
                          ),
                        )
                      else if (showChevron)
                        Padding(
                          padding: EdgeInsets.only(left: DSSpacing.sm),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: DSIconSize.sm,
                            color: subtextColor,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationPill(FailedDeliveryVerificationStatus rv) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: DSSpacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: (rv.isVerified ? DSColors.success : DSColors.warning).withValues(
          alpha: DSStyles.alphaSubtle,
        ),
        borderRadius: DSStyles.pillRadius,
        border: Border.all(
          color: (rv.isVerified ? DSColors.success : DSColors.warning)
              .withValues(alpha: DSStyles.alphaMuted),
        ),
      ),
      child: Text(
        rv.isVerified ? 'ITEM RETURNED' : 'IN POSSESSION',
        style: DSTypography.label(
          color: rv.isVerified ? DSColors.success : DSColors.warning,
        ).copyWith(fontSize: 9),
      ),
    );
  }
}
