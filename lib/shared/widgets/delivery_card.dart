// DOCS: docs/shared/widgets.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/core/models/delivery_status.dart';
import 'package:fsi_courier_app/styles/ui_styles.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_helper.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_identifier.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';

class DeliveryCard extends StatelessWidget {
  const DeliveryCard({
    super.key,
    required this.delivery,
    required this.onTap,
    this.compact = false,
    this.showChevron = true,
    this.enableHoldToReveal = true, // Legacy: ignored now
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
    return switch (DeliveryStatus.fromString(status)) {
      DeliveryStatus.pending => const Color(0xFFFF6E00),
      DeliveryStatus.delivered => const Color(0xFF00B14F),
      DeliveryStatus.failedDelivery => const Color(0xFFE53935),
      DeliveryStatus.osa => const Color(0xFFFFB300),
      _ => const Color(0xFF607D8B),
    };
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

    // Prefer mail type for delivered items in the header (handled below).
    final address = (delivery['address'] ?? delivery['delivery_address'] ?? '')
        .toString();
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

    final colorForStatus = isDirty
        ? const Color(0xFFFFB300)
        : statusColor(status);
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
    final cardBg = isDark ? const Color(0xFF161625) : Colors.white;
    final cardBorder = isDark
        ? const Color(0xFF2A2A40)
        : const Color(0xFFE8EAF0);
    final subtextColor = isDark
        ? const Color(0xFF6B7280)
        : const Color(0xFF9CA3AF);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.fastOutSlowIn,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: UIStyles.cardRadius,
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: UIStyles.alphaDarkShadow)
                : Colors.black.withValues(alpha: UIStyles.alphaSoft),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: UIStyles.cardRadius,
          onTap: isChecking ? null : onTap,
          splashColor: colorForStatus.withValues(alpha: UIStyles.alphaSoft),
          highlightColor: colorForStatus.withValues(alpha: UIStyles.alphaSoft),
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
                          // Status badge — hide if status is empty AND not dirty (Privacy mode also hides status)
                          if (!isPrivacyMode && (status.isNotEmpty || isDirty))
                            _StatusBadge(
                              label: isDirty
                                  ? 'UNSYNCED'
                                  : status.replaceAll('_', ' '),
                              color: colorForStatus,
                              icon: isDirty
                                  ? Icons.sync_problem_rounded
                                  : iconForStatus,
                            ),
                          if (!isPrivacyMode && (status.isNotEmpty || isDirty))
                            const SizedBox(width: 8),
                          // Right side: job order / product + lock + chevron
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // For delivered items prefer showing the mail type
                                // in the header to avoid duplicating the product
                                // which is already shown in the details below.
                                if (!isPrivacyMode &&
                                    (ds == DeliveryStatus.delivered ||
                                        (ds == DeliveryStatus.failedDelivery &&
                                            attemptsCount >= 3)) &&
                                    mailType.isNotEmpty)
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF2196F3,
                                        ).withValues(alpha: UIStyles.alphaSoft),
                                        borderRadius: UIStyles.pillRadius,
                                      ),
                                      child: Text(
                                        mailType,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF2196F3),
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
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: subtextColor,
                                      ),
                                    ),
                                  ),
                                // Attempts pill for Failed Delivery items
                                if (attemptsCount > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: _MiniPill(
                                      label: ds == DeliveryStatus.delivered
                                          ? 'FAILED ATTEMPTS: $attemptsCount'
                                          : 'ATTEMPTS: $attemptsCount',
                                      icon: Icons.autorenew_rounded,
                                      bg: attemptsCount >= 3
                                          ? Colors.red.shade50
                                          : Colors.orange.shade50,
                                      border: attemptsCount >= 3
                                          ? Colors.red.shade300
                                          : Colors.orange.shade300,
                                      fg: attemptsCount >= 3
                                          ? Colors.red.shade700
                                          : Colors.orange.shade800,
                                    ),
                                  ),
                                // Lock icon
                                if (showLockIcon && (isLocked || !isVisible))
                                  Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: Icon(
                                      Icons.lock_outline_rounded,
                                      color: isLocked
                                          ? subtextColor
                                          : Colors.red.shade400,
                                      size: 15,
                                    ),
                                  ),
                                // Minimal Chevron
                                if (showChevron && !isChecking)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.06,
                                              )
                                            : Colors.grey.shade100,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.chevron_right_rounded,
                                        color: subtextColor,
                                        size: 17,
                                      ),
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
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 1.2,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF111827),
                        ),
                      ),

                      // ── Row 3: Recipient name ────────────────────────────
                      if (!isPrivacyMode && name.isNotEmpty && !isLocked) ...[
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
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF374151),
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
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.4,
                                  color: subtextColor,
                                ),
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
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: subtextColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // ── Metadata chips ───────────────────────────────────
                      if (!isPrivacyMode && delivery['metadata'] is List) ...[
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
                              _MiniPill(
                                label: 'UNSYNCED',
                                icon: Icons.sync_problem_rounded,
                                bg: Colors.amber.shade50,
                                border: Colors.amber.shade300,
                                fg: Colors.amber.shade800,
                              ),
                            if (isPaid)
                              _MiniPill(
                                label: 'PAID',
                                icon: Icons.check_circle_outline_rounded,
                                bg: Colors.green.shade50,
                                border: Colors.green.shade200,
                                fg: Colors.green.shade700,
                              ),
                            if (inSyncQueue)
                              _MiniPill(
                                label: 'PENDING SYNC',
                                icon: Icons.sync_lock_rounded,
                                bg: Colors.blue.shade50,
                                border: Colors.blue.shade200,
                                fg: Colors.blue.shade800,
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
                                    ColorStyles.grabOrange,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Checking eligibility…',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: subtextColor,
                                ),
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
                                style: TextStyle(
                                  fontSize: 11,
                                  color: subtextColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],

                      // ── Detail section (Auto-visible if not compact) ────────────────────────
                      if (isExpanded && !isPrivacyMode)
                        _buildDetailSection(delivery, isDark, subtextColor),

                      // ── Update action button (expanded only) ─────────────────────────────────
                      if (onUpdateTap != null &&
                          !isPrivacyMode &&
                          isExpanded) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: onUpdateTap,
                            icon: const Icon(Icons.edit_rounded, size: 14),
                            label: const Text('UPDATE'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 36),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: UIStyles.pillRadius,
                              ),
                              side: BorderSide(color: colorForStatus),
                              backgroundColor: colorForStatus.withValues(
                                alpha: UIStyles.alphaActiveAccent,
                              ),
                              foregroundColor: colorForStatus,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Detail section ──────────────────────────────────────────────
  Widget _buildDetailSection(
    Map<String, dynamic> delivery,
    bool isDark,
    Color subtextColor,
  ) {
    // Normalize strings with safe defaults to simplify checks below.
    final seqNum = delivery['sequence_number']?.toString() ?? '';
    final product = delivery['product']?.toString() ?? '';
    final mailType = delivery['mail_type']?.toString() ?? '';
    final specialInstr = delivery['special_instruction']?.toString() ?? '';
    final transactionAt = delivery['transaction_at']?.toString() ?? '';

    final rawStatus = delivery['delivery_status']?.toString() ?? '';
    final status = rawStatus.toUpperCase().trim();
    final ds = DeliveryStatus.fromString(status);
    final attemptsCount = getAttemptsCountFromMap(delivery);

    // If the header already shows the mail type for delivered items or
    // failed-delivery items with max attempts, don't repeat it in the detail grid.
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
        ? Colors.white.withValues(alpha: UIStyles.alphaSoft)
        : Colors.black.withValues(alpha: UIStyles.alphaSoft);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Divider(height: 1, color: dividerColor),
        const SizedBox(height: 14),

        // Detail grid
        Row(
          children: [
            if (seqNum.isNotEmpty)
              Expanded(
                child: _DetailCell(
                  label: 'SEQUENCE',
                  value: seqNum,
                  isDark: isDark,
                  subtextColor: subtextColor,
                ),
              ),
            if (transactionAt.isNotEmpty)
              Expanded(
                child: _DetailCell(
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
          _DetailCell(
            label: 'PRODUCT / MAIL TYPE',
            value: [product, mailType].where((e) => e.isNotEmpty).join(' · '),
            isDark: isDark,
            subtextColor: subtextColor,
          ),
        ],

        if (specialInstr.isNotEmpty) ...[
          const SizedBox(height: 12),
          _DetailCell(
            label: 'SPECIAL INSTRUCTIONS',
            value: specialInstr,
            isDark: isDark,
            subtextColor: subtextColor,
            valueColor: const Color(0xFF2196F3),
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
    final cardBg = isDark ? const Color(0xFF161625) : Colors.white;
    final subtextColor = isDark
        ? const Color(0xFF6B7280)
        : const Color(0xFF9CA3AF);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: UIStyles.cardRadius,
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A40) : const Color(0xFFE8EAF0),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: UIStyles.alphaDarkShadow)
                : Colors.black.withValues(alpha: UIStyles.alphaSoft),
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
                    statusColor.withValues(alpha: UIStyles.alphaBorder),
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
                    horizontal: 12,
                    vertical: 9,
                  ),
                  child: Row(
                    children: [
                      // Barcode + name/product/address
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              barcode.isEmpty ? 'UNKNOWN' : barcode,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 0.8,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isPrivacyMode
                                  ? product // ONLY barcode and product in privacy mode
                                  : [
                                          address,
                                          product,
                                        ] // Compact mode shows address instead of name
                                        .where((e) => e.isNotEmpty)
                                        .join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: subtextColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Pills (Hidden in Privacy mode)
                      if (!isPrivacyMode)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isDirty)
                              _TinyPill(
                                label: 'UNSYNC',
                                color: Colors.amber.shade700,
                              ),
                            if (inSyncQueue)
                              _TinyPill(
                                label: 'SYNC',
                                color: Colors.blue.shade600,
                              ),
                            if (isPaid)
                              _TinyPill(
                                label: 'PAID',
                                color: Colors.green.shade600,
                              ),
                            if (attemptsCount > 0)
                              _TinyPill(
                                label: ds == DeliveryStatus.delivered
                                    ? 'FA:$attemptsCount'
                                    : 'A:$attemptsCount',
                                color: attemptsCount >= 3
                                    ? Colors.red.shade600
                                    : Colors.orange.shade600,
                              ),
                          ],
                        ),
                      // Lock / chevron
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
                            color: Colors.red.shade400,
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
                      // Update icon pill (compact mode)
                      if (onUpdateTap != null && !isPrivacyMode)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Material(
                            color: statusColor.withValues(
                              alpha: UIStyles.alphaActiveAccent,
                            ),
                            borderRadius: UIStyles.pillRadius,
                            child: InkWell(
                              onTap: onUpdateTap,
                              borderRadius: UIStyles.pillRadius,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.edit_rounded,
                                      size: 11,
                                      color: statusColor,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'UPDATE',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: statusColor,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: UIStyles.alphaActiveAccent),
        borderRadius: UIStyles.pillRadius,
        border: Border.all(
          color: color.withValues(alpha: UIStyles.alphaDarkShadow),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({
    required this.label,
    required this.icon,
    required this.bg,
    required this.border,
    required this.fg,
  });

  final String label;
  final IconData icon;
  final Color bg;
  final Color border;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: UIStyles.pillRadius,
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  const _TinyPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: UIStyles.alphaActiveAccent),
        borderRadius: UIStyles.pillRadius,
        border: Border.all(
          color: color.withValues(alpha: UIStyles.alphaDarkShadow),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 7,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _DetailCell extends StatelessWidget {
  const _DetailCell({
    required this.label,
    required this.value,
    required this.isDark,
    required this.subtextColor,
    this.valueColor,
    this.isItalic = false,
  });

  final String label;
  final String value;
  final bool isDark;
  final Color subtextColor;
  final Color? valueColor;
  final bool isItalic;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: subtextColor,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color:
                valueColor ??
                (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1F2937)),
            fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ],
    );
  }
}

class InfoChip extends StatelessWidget {
  const InfoChip({
    super.key,
    required this.icon,
    required this.label,
    this.isDark = false,
  });

  final IconData icon;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final color = isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: color),
          ),
        ),
      ],
    );
  }
}
