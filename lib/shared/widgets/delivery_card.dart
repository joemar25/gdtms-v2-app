// DOCS: docs/shared/widgets.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fsi_courier_app/core/models/delivery_status.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_helper.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_identifier.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';
import 'package:fsi_courier_app/shared/helpers/string_helper.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/shared/widgets/delivery_card_components.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_form_helpers.dart';

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

  @override
  Widget build(BuildContext context) {
    final isExpanded = !compact;
    final delivery = this.delivery;
    final barcode = resolveDeliveryIdentifier(delivery);
    final rawStatus = delivery['delivery_status']?.toString() ?? '';
    final status = rawStatus.toUpperCase().trim();
    final ds = DeliveryStatus.fromString(status);
    final product = (delivery['product'] ?? delivery['mail_type'] ?? '')
        .toString();
    final mailType = (delivery['mail_type'] ?? '').toString();

    final address = (delivery['address'] ?? delivery['delivery_address'] ?? '')
        .toString();
    final contact = (delivery['contact'] ?? '').toString().trim();
    final name =
        (delivery['name'] ??
                delivery['recipient'] ??
                delivery['recipient_name'] ??
                '')
            .toString();

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
    final isPaid = delivery['_paid_at'] != null;
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

    if (compact) {
      return _buildCompactCard(
        context: context,
        isDark: isDark,
        statusColor: colorForStatus,
        status: status,
        barcode: barcode,
        name: name,
        isDirty: isDirty,
        isPaid: isPaid,
        isFailedWithPay: isFailedWithPay,
        isFailedNoPay: isFailedNoPay,
        isLocked: isLocked,
        isVisible: isVisible,
        inSyncQueue: inSyncQueue,
        product: product,
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

    // ── Slide actions (expanded only) ────────────────────────────────────────
    final cleanedContact = contact.cleanContactNumber();
    final hasMap = address.isNotEmpty && !isPrivacyMode && !isLocked;
    final hasCall = cleanedContact.isNotEmpty && !isPrivacyMode && !isLocked;
    final hasUpdate = onUpdateTap != null && !isPrivacyMode;
    final slideCount =
        (hasMap ? 1 : 0) + (hasCall ? 1 : 0) + (hasUpdate ? 1 : 0);

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
              onLongPress: isChecking
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
                                    if (!isPrivacyMode &&
                                        (ds == DeliveryStatus.delivered ||
                                            (ds ==
                                                    DeliveryStatus
                                                        .failedDelivery &&
                                                attemptsCount >= 3)) &&
                                        mailType.isNotEmpty)
                                      Flexible(
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: DSSpacing.sm,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: DSColors.primary.withValues(
                                              alpha: DSStyles.alphaSoft,
                                            ),
                                            borderRadius: DSStyles.pillRadius,
                                          ),
                                          child: Text(
                                            mailType,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style:
                                                DSTypography.label(
                                                  color: DSColors.primary,
                                                ).copyWith(
                                                  fontSize: DSTypography.sizeSm,
                                                  letterSpacing: DSTypography.lsLoose,
                                                ),
                                          ),
                                        ),
                                      )
                                    else if (!isPrivacyMode &&
                                        isLocked &&
                                        product.isNotEmpty)
                                      Flexible(
                                        child: Text(
                                          product,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style:
                                              DSTypography.caption(
                                                color: subtextColor,
                                              ).copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    if (attemptsCount > 0)
                                      Padding(
                                        padding: EdgeInsets.only(left: DSSpacing.xs),
                                        child: DeliveryMiniPill(
                                          label: ds == DeliveryStatus.delivered
                                              ? 'FAILED ATTEMPTS: $attemptsCount'
                                              : 'ATTEMPTS: $attemptsCount',
                                          icon: Icons.autorenew_rounded,
                                          bg:
                                              (attemptsCount >= 3
                                                      ? DSColors.error
                                                      : DSColors.warning)
                                                  .withValues(alpha: DSStyles.alphaSubtle),
                                          border:
                                              (attemptsCount >= 3
                                                      ? DSColors.error
                                                      : DSColors.warning)
                                                  .withValues(alpha: DSStyles.alphaMuted),
                                          fg: attemptsCount >= 3
                                              ? DSColors.error
                                              : DSColors.warning,
                                        ),
                                      ),
                                    if (showLockIcon &&
                                        (isLocked || !isVisible))
                                      Padding(
                                        padding: EdgeInsets.only(left: DSSpacing.xs),
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
                          Text(
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
                                  letterSpacing: DSTypography.lsExtraLoose,
                                ),
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

                          // ── Row 5: Privacy Mode Product Label ──────────────────
                          if (isPrivacyMode && product.isNotEmpty) ...[
                            DSSpacing.hXs,
                            Row(
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: DSIconSize.xs,
                                  color: subtextColor,
                                ),
                                DSSpacing.wXs,
                                Flexible(
                                  child: Text(
                                    product.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        DSTypography.caption(
                                          color: subtextColor,
                                        ).copyWith(
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: DSTypography.lsLoose,
                                        ),
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
                          if (!isPrivacyMode &&
                              (isDirty || isPaid || inSyncQueue)) ...[
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
                                if (isPaid)
                                  DeliveryMiniPill(
                                    label: 'PAID',
                                    icon: Icons.check_circle_outline_rounded,
                                    bg: DSColors.success.withValues(
                                      alpha: DSStyles.alphaSubtle,
                                    ),
                                    border: DSColors.success.withValues(
                                      alpha: DSStyles.alphaMuted,
                                    ),
                                    fg: DSColors.success,
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
                                  SizedBox(
                                    width: 11,
                                    height: 11,
                                    child: CircularProgressIndicator(
                                      strokeWidth: DSStyles.strokeWidth,
                                      valueColor: AlwaysStoppedAnimation(
                                        DSColors.error,
                                      ),
                                    ),
                                  ),
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
                            _buildDetailSection(delivery, isDark, subtextColor),
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

  void _showHoldOptions(BuildContext context, bool isDark) {
    final identifier = resolveDeliveryIdentifier(delivery);
    final address =
        delivery['address']?.toString() ??
        delivery['delivery_address']?.toString() ??
        '';
    final contact = delivery['contact']?.toString() ?? '';
    final cleanedContact = contact.cleanContactNumber();
    final hasMap = address.isNotEmpty && !isPrivacyMode && !isChecking;
    final hasCall = cleanedContact.isNotEmpty && !isPrivacyMode && !isChecking;
    final accountNumber = delivery['account_number']?.toString() ?? '';
    final authRepNumber = delivery['auth_rep_number']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? DSColors.cardDark : DSColors.cardLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DSStyles.radiusCard),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(DSSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: DSIconSize.heroSm,
                    height: DSSpacing.xs,
                    margin: EdgeInsets.only(bottom: DSSpacing.xl),
                    decoration: BoxDecoration(
                      color: isDark
                          ? DSColors.white.withValues(alpha: DSStyles.alphaMuted)
                          : DSColors.black.withValues(alpha: DSStyles.alphaSubtle),
                      borderRadius: BorderRadius.circular(DSStyles.radiusSM),
                    ),
                  ),
                ),
                if (hasMap)
                  ListTile(
                    leading: const Icon(
                      Icons.map_rounded,
                      color: DSColors.primary,
                    ),
                    title: const Text('Open in Maps'),
                    onTap: () {
                      Navigator.pop(ctx);
                      final url =
                          'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(address)}';
                      launchUrl(
                        Uri.parse(url),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
                if (hasCall)
                  ListTile(
                    leading: const Icon(
                      Icons.phone_rounded,
                      color: DSColors.primary,
                    ),
                    title: const Text('Call Contact'),
                    subtitle: Text(cleanedContact),
                    onTap: () {
                      Navigator.pop(ctx);
                      launchUrl(
                        Uri.parse('tel:$cleanedContact'),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
                if (accountNumber.isNotEmpty)
                  ListTile(
                    leading: Icon(
                      Icons.account_balance_wallet_rounded,
                      color: isDark
                          ? DSColors.white.withValues(alpha: DSStyles.alphaDisabled)
                          : DSColors.black.withValues(alpha: DSStyles.alphaDisabled),
                    ),
                    title: const Text('Account Number'),
                    subtitle: Text(accountNumber),
                  ),
                if (authRepNumber.isNotEmpty)
                  ListTile(
                    leading: Icon(
                      Icons.badge_rounded,
                      color: isDark
                          ? DSColors.white.withValues(alpha: DSStyles.alphaDisabled)
                          : DSColors.black.withValues(alpha: DSStyles.alphaDisabled),
                    ),
                    title: const Text('Auth Rep Number'),
                    subtitle: Text(authRepNumber),
                  ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('View Delivery Details'),
                  onTap: () {
                    Navigator.pop(ctx);
                    showDeliveryAccountDetails(context, delivery, identifier);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Detail section ──────────────────────────────────────────────
  Widget _buildDetailSection(
    Map<String, dynamic> delivery,
    bool isDark,
    Color subtextColor,
  ) {
    final seqNum = delivery['sequence_number']?.toString() ?? '';
    final product = delivery['product']?.toString() ?? '';
    final mailType = delivery['mail_type']?.toString() ?? '';
    final specialInstr = delivery['special_instruction']?.toString() ?? '';
    final transactionAt = delivery['transaction_at']?.toString() ?? '';

    final rawStatus = delivery['delivery_status']?.toString() ?? '';
    final status = rawStatus.toUpperCase().trim();
    final ds = DeliveryStatus.fromString(status);
    final attemptsCount = getAttemptsCountFromMap(delivery);

    final showProductMailType =
        !((ds == DeliveryStatus.delivered ||
                (ds == DeliveryStatus.failedDelivery && attemptsCount >= 3)) &&
            mailType.isNotEmpty);

    final hasDetails =
        seqNum.isNotEmpty ||
        (transactionAt.isNotEmpty && ds != DeliveryStatus.pending) ||
        (showProductMailType && (product.isNotEmpty || mailType.isNotEmpty)) ||
        specialInstr.isNotEmpty;

    if (!hasDetails) return const SizedBox.shrink();

    final dividerColor = isDark
        ? DSColors.white.withValues(alpha: DSStyles.alphaSoft)
        : DSColors.black.withValues(alpha: DSStyles.alphaSoft);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DSSpacing.hMd,
        Divider(height: DSStyles.borderWidth, color: dividerColor),
        DSSpacing.hMd,

        Row(
          children: [
            if (seqNum.isNotEmpty)
              Expanded(
                child: DeliveryDetailCell(
                  label: 'SEQUENCE',
                  value: seqNum,
                  isDark: isDark,
                  subtextColor: subtextColor,
                ),
              ),
            if (transactionAt.isNotEmpty &&
                product.toLowerCase() != 'delivery' &&
                ds != DeliveryStatus.pending)
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

        if (showProductMailType &&
            (product.isNotEmpty || mailType.isNotEmpty)) ...[
          DSSpacing.hMd,
          DeliveryDetailCell(
            label: 'PRODUCT / MAIL TYPE',
            value: [product, mailType].where((e) => e.isNotEmpty).join(' · '),
            isDark: isDark,
            subtextColor: subtextColor,
          ),
        ],

        if (specialInstr.isNotEmpty) ...[
          DSSpacing.hMd,
          DeliveryDetailCell(
            label: 'SPECIAL INSTRUCTIONS',
            value: specialInstr,
            isDark: isDark,
            subtextColor: subtextColor,
            valueColor: DSColors.primary,
            isItalic: true,
          ),
        ],
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
    required bool isPaid,
    required bool isFailedWithPay,
    required bool isFailedNoPay,
    required bool isLocked,
    required bool isVisible,
    required bool inSyncQueue,
    required String product,
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
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
                                    fontSize: DSTypography.sizeMd,
                                    letterSpacing: DSTypography.lsExtraLoose,
                                  ),
                            ),
                            DSSpacing.hXs,
                            Text(
                              isPrivacyMode
                                  ? product
                                  : [
                                      address,
                                      product,
                                    ].where((e) => e.isNotEmpty).join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DSTypography.caption(color: subtextColor)
                                  .copyWith(
                                    fontSize: DSTypography.sizeXs,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: DSTypography.lsLoose,
                                  ),
                            ),
                          ],
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
                            if (isPaid)
                              DeliveryTinyPill(
                                label: 'PAID',
                                color: DSColors.success,
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
}
