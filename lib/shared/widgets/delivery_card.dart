// DOCS: docs/shared/widgets.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fsi_courier_app/core/models/delivery_status.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_helper.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_identifier.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';
import 'package:fsi_courier_app/shared/helpers/string_helper.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/shared/widgets/delivery_card_components.dart';

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
                    ? Colors.black.withValues(alpha: DSStyles.alphaDarkShadow)
                    : Colors.black.withValues(alpha: DSStyles.alphaSoft),
                blurRadius: 0,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
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
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                                const SizedBox(width: 8),
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
                                          padding: const EdgeInsets.symmetric(
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
                                                  letterSpacing: 0.3,
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
                                        padding: const EdgeInsets.only(left: 6),
                                        child: DeliveryMiniPill(
                                          label: ds == DeliveryStatus.delivered
                                              ? 'FAILED ATTEMPTS: $attemptsCount'
                                              : 'ATTEMPTS: $attemptsCount',
                                          icon: Icons.autorenew_rounded,
                                          bg:
                                              (attemptsCount >= 3
                                                      ? DSColors.error
                                                      : DSColors.warning)
                                                  .withValues(alpha: 0.08),
                                          border:
                                              (attemptsCount >= 3
                                                      ? DSColors.error
                                                      : DSColors.warning)
                                                  .withValues(alpha: 0.25),
                                          fg: attemptsCount >= 3
                                              ? DSColors.error
                                              : DSColors.warning,
                                        ),
                                      ),
                                    if (showLockIcon &&
                                        (isLocked || !isVisible))
                                      Padding(
                                        padding: const EdgeInsets.only(left: 6),
                                        child: Icon(
                                          Icons.lock_outline_rounded,
                                          color: isLocked
                                              ? subtextColor
                                              : DSColors.error,
                                          size: 15,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

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
                                  letterSpacing: DSTypography.lsMegaLoose,
                                ),
                          ),

                          // ── Row 3: Recipient name ────────────────────────────
                          if (!isPrivacyMode &&
                              name.isNotEmpty &&
                              !isLocked) ...[
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Icon(
                                  Icons.person_outline_rounded,
                                  size: 13,
                                  color: subtextColor,
                                ),
                                const SizedBox(width: 4),
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
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 1),
                                  child: Icon(
                                    Icons.location_on_outlined,
                                    size: 12,
                                    color: subtextColor,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    address,
                                    maxLines: isExpanded ? null : 1,
                                    overflow: isExpanded
                                        ? null
                                        : TextOverflow.ellipsis,
                                    style: DSTypography.caption(
                                      color: subtextColor,
                                    ).copyWith(height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // ── Row 5: Privacy Mode Product Label ──────────────────
                          if (isPrivacyMode && product.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 13,
                                  color: subtextColor,
                                ),
                                const SizedBox(width: 4),
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
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
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
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                if (isDirty)
                                  DeliveryMiniPill(
                                    label: 'UNSYNCED',
                                    icon: Icons.sync_problem_rounded,
                                    bg: DSColors.warning.withValues(
                                      alpha: 0.08,
                                    ),
                                    border: DSColors.warning.withValues(
                                      alpha: 0.25,
                                    ),
                                    fg: DSColors.warning,
                                  ),
                                if (isPaid)
                                  DeliveryMiniPill(
                                    label: 'PAID',
                                    icon: Icons.check_circle_outline_rounded,
                                    bg: DSColors.success.withValues(
                                      alpha: 0.08,
                                    ),
                                    border: DSColors.success.withValues(
                                      alpha: 0.25,
                                    ),
                                    fg: DSColors.success,
                                  ),
                                if (inSyncQueue)
                                  DeliveryMiniPill(
                                    label: 'PENDING SYNC',
                                    icon: Icons.sync_lock_rounded,
                                    bg: DSColors.primary.withValues(
                                      alpha: 0.08,
                                    ),
                                    border: DSColors.primary.withValues(
                                      alpha: 0.25,
                                    ),
                                    fg: DSColors.primary,
                                  ),
                              ],
                            ),
                          ],

                          // ── Footer ───────────────────────────────────────────
                          if (footerText != null || isChecking) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                if (isChecking) ...[
                                  SizedBox(
                                    width: 11,
                                    height: 11,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                        DSColors.error,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Checking eligibility…',
                                    style: DSTypography.caption(
                                      color: subtextColor,
                                    ).copyWith(fontSize: DSTypography.sizeSm),
                                  ),
                                ] else if (footerText != null) ...[
                                  Icon(
                                    footerIcon ?? Icons.info_outline,
                                    size: 13,
                                    color: subtextColor,
                                  ),
                                  const SizedBox(width: 4),
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
      padding: const EdgeInsets.only(bottom: 10),
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
            padding: const EdgeInsets.all(DSSpacing.base),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24.0),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
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
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    title: const Text('Account Number'),
                    subtitle: Text(accountNumber),
                  ),
                if (authRepNumber.isNotEmpty)
                  ListTile(
                    leading: Icon(
                      Icons.badge_rounded,
                      color: isDark ? Colors.white70 : Colors.black54,
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
                    if (identifier.isNotEmpty) {
                      context.push('/deliveries/$identifier');
                    }
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
        transactionAt.isNotEmpty ||
        (showProductMailType && (product.isNotEmpty || mailType.isNotEmpty)) ||
        specialInstr.isNotEmpty;

    if (!hasDetails) return const SizedBox.shrink();

    final dividerColor = isDark
        ? Colors.white.withValues(alpha: DSStyles.alphaSoft)
        : Colors.black.withValues(alpha: DSStyles.alphaSoft);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Divider(height: 1, color: dividerColor),
        const SizedBox(height: 14),

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
            if (transactionAt.isNotEmpty && product.toLowerCase() != 'delivery')
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
          const SizedBox(height: 12),
          DeliveryDetailCell(
            label: 'PRODUCT / MAIL TYPE',
            value: [product, mailType].where((e) => e.isNotEmpty).join(' · '),
            isDark: isDark,
            subtextColor: subtextColor,
          ),
        ],

        if (specialInstr.isNotEmpty) ...[
          const SizedBox(height: 12),
          DeliveryDetailCell(
            label: 'SPECIAL INSTRUCTIONS',
            value: specialInstr,
            isDark: isDark,
            subtextColor: subtextColor,
            valueColor: DSColors.primary,
            isItalic: true,
          ),
        ],
        const SizedBox(height: 4),
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
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: DSStyles.cardRadius,
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: DSStyles.alphaDarkShadow)
                : Colors.black.withValues(alpha: DSStyles.alphaSoft),
            blurRadius: 6,
            offset: const Offset(0, 2),
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
              width: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    statusColor,
                    statusColor.withValues(alpha: DSStyles.alphaBorder),
                  ],
                ),
              ),
            ),
            // Content
            Expanded(
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
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
                            const SizedBox(height: 2),
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
                                    letterSpacing: 0.3,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
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
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.lock_outline_rounded,
                            color: subtextColor,
                            size: 14,
                          ),
                        )
                      else if (!isPrivacyMode && !isVisible)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.lock_outline_rounded,
                            color: DSColors.error,
                            size: 14,
                          ),
                        )
                      else if (showChevron)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
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
