import 'package:flutter/material.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_helper.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_identifier.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';

class DeliveryCard extends StatefulWidget {
  const DeliveryCard({
    super.key,
    required this.delivery,
    required this.onTap,
    this.compact = false,
    this.showChevron = true,
    this.enableHoldToReveal = true,
  });

  final Map<String, dynamic> delivery;
  final VoidCallback onTap;
  final bool compact;
  final bool showChevron;
  final bool enableHoldToReveal;

  static Color statusColor(String status) {
    return switch (status.toUpperCase()) {
      'PENDING' => Colors.orange,
      'DELIVERED' => Colors.green,
      'RTS' => Colors.red,
      'OSA' => Colors.amber,
      'DISPATCHED' => Colors.blue,
      _ => Colors.grey,
    };
  }

  @override
  State<DeliveryCard> createState() => _DeliveryCardState();
}

class _DeliveryCardState extends State<DeliveryCard> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final delivery = widget.delivery;
    final barcode = resolveDeliveryIdentifier(delivery);
    final rawStatus = delivery['delivery_status']?.toString() ?? 'PENDING';
    final status = rawStatus.toUpperCase();
    final jobOrder = (delivery['job_order'] ?? delivery['tracking_number'] ?? '').toString();
    final product = (delivery['product'] ?? delivery['mail_type'] ?? '').toString();
    final address = (delivery['address'] ?? delivery['delivery_address'] ?? '').toString();
    final name = (delivery['name'] ??
            delivery['recipient'] ??
            delivery['recipient_name'] ??
            '')
        .toString();
    final syncStatus = delivery['_sync_status']?.toString() ?? 'clean';
    final isDirty = syncStatus == 'dirty';
    final inSyncQueue = delivery['_in_sync_queue'] == true;
    final color = isDirty ? Colors.amber.shade700 : DeliveryCard.statusColor(status);
    final rtsVerifStatus =
        (delivery['_rts_verification_status']?.toString() ??
        delivery['rts_verification_status']?.toString() ??
        'unvalidated').toLowerCase();
    final isRtsWithPay = status == 'RTS' && (rtsVerifStatus == 'verified_with_pay');
    final isRtsNoPay = status == 'RTS' && (rtsVerifStatus == 'verified_no_pay');
    final isPaid = delivery['_paid_at'] != null;
    final isLocked = checkIsLockedFromMap(delivery);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    // Synchronous visibility evaluation mirroring LocalDeliveryDao.isVisibleToRider
    final isArchived = delivery['_is_archived'] == true;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final tomorrowStart = DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;

    bool isVisible = false;
    if (!isArchived) {
      if (status == 'PENDING') {
        isVisible = true;
      } else if (status == 'DELIVERED') {
        final deliveredAt = delivery['_delivered_at'] as int? ?? 0;
        isVisible = deliveredAt >= todayStart && deliveredAt < tomorrowStart;
      } else if (status == 'RTS') {
        final completedAt = delivery['_completed_at'] as int? ?? 0;
        // RTS items in the list are only those not yet verified into a payout.
        isVisible = completedAt >= todayStart && completedAt < tomorrowStart && !isRtsWithPay && !isRtsNoPay;
      } else if (status == 'OSA') {
        final completedAt = delivery['_completed_at'] as int? ?? 0;
        isVisible = completedAt >= todayStart && completedAt < tomorrowStart;
      }
    }

    if (widget.compact) {
      return _buildCompactCard(
        context: context,
        cardBg: cardBg,
        color: color,
        barcode: barcode,
        name: name,
        isDirty: isDirty,
        isPaid: isPaid,
        isRtsWithPay: isRtsWithPay,
        isRtsNoPay: isRtsNoPay,
        isLocked: isLocked,
        isVisible: isVisible,
        inSyncQueue: inSyncQueue,
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.fastOutSlowIn,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _isExpanded
            ? (isDark ? Colors.blueGrey.shade900 : Colors.blue.shade50)
            : cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: _isExpanded ? 15 : 10,
            offset: Offset(0, _isExpanded ? 5 : 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: widget.onTap,
          child: GestureDetector(
            onLongPress: () {
              if (widget.compact || !widget.enableHoldToReveal || isLocked) return;
              setState(() => _isExpanded = !_isExpanded);
            },
            behavior: HitTestBehavior.translucent,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    barcode.isEmpty ? 'Unknown' : barcode,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                // Locked: show product type instead of internal job-order ID
                                if (isLocked && product.isNotEmpty)
                                  Text(
                                    product,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade500,
                                    ),
                                  )
                                else if (!isLocked && jobOrder.isNotEmpty)
                                  Text(
                                    jobOrder,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                              ],
                            ),
                            if (name.isNotEmpty && !isLocked) ...[
                              const SizedBox(height: 3),
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            if (address.isNotEmpty && !isLocked) ...[
                              const SizedBox(height: 2),
                              Text(
                                address,
                                maxLines: _isExpanded ? null : 1,
                                overflow: _isExpanded ? null : TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (isLocked) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.lock_outline_rounded, color: Colors.grey.shade400, size: 16),
                      ] else if (!isVisible) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.lock_outline_rounded, color: Colors.red.shade300, size: 16),
                      ] else if (widget.showChevron) ...[
                        const SizedBox(width: 8),
                        AnimatedRotation(
                          turns: _isExpanded ? 0.25 : 0.0, // 90 degrees when expanded
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          child: Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (isDirty || isPaid || inSyncQueue) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (isDirty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.amber.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.sync_problem_rounded,
                                  size: 10,
                                  color: Colors.amber.shade700,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'UNSYNCED',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.amber.shade800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (isDirty && isPaid) const SizedBox(width: 6),
                        if (isPaid)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Text(
                              'PAID',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.green.shade700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        if ((isDirty || isPaid) && inSyncQueue) const SizedBox(width: 6),
                        if (inSyncQueue)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.sync_lock_rounded, size: 10, color: Colors.blue.shade700),
                                const SizedBox(width: 3),
                                Text(
                                  'PENDING SYNC',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.blue.shade800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                  ClipRect(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.fastOutSlowIn,
                      alignment: Alignment.topCenter,
                      child: _isExpanded
                          ? _buildDetailedSection(delivery, isDark)
                          : const SizedBox(width: double.infinity),
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

  Widget _buildDetailedSection(Map<String, dynamic> delivery, bool isDark) {
    final seqNum = delivery['sequence_number']?.toString();
    final product = delivery['product']?.toString();
    final mailType = delivery['mail_type']?.toString();
    final specialInstr = delivery['special_instruction']?.toString();
    final transactionAt = delivery['transaction_at']?.toString();

    final labelStyle = TextStyle(
      fontSize: 9,
      fontWeight: FontWeight.w700,
      color: Colors.grey.shade500,
      letterSpacing: 0.8,
    );
    final valueStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, color: Colors.grey.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          Row(
            children: [
              if (seqNum != null && seqNum.isNotEmpty)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SEQUENCE', style: labelStyle),
                      const SizedBox(height: 2),
                      Text(seqNum, style: valueStyle),
                    ],
                  ),
                ),
              if (transactionAt != null && transactionAt.isNotEmpty)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TRANSACTION', style: labelStyle),
                      const SizedBox(height: 2),
                      Text(formatDate(transactionAt, includeTime: true), style: valueStyle),
                    ],
                  ),
                ),
            ],
          ),
          if ((product != null && product.isNotEmpty) || (mailType != null && mailType.isNotEmpty)) ...[
            const SizedBox(height: 10),
            Text('PRODUCT / MAIL TYPE', style: labelStyle),
            const SizedBox(height: 2),
            Text(
              [product, mailType].where((e) => e != null && e.isNotEmpty).join(' | '),
              style: valueStyle,
            ),
          ],
          if (specialInstr != null && specialInstr.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('SPECIAL INSTRUCTIONS', style: labelStyle),
            const SizedBox(height: 2),
            Text(
              specialInstr,
              style: valueStyle.copyWith(
                color: Colors.blue.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: () => setState(() => _isExpanded = false),
              icon: const Icon(Icons.expand_less_rounded, size: 18),
              label: const Text('COLLAPSE', style: TextStyle(fontSize: 12, letterSpacing: 1)),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildCompactCard({
    required BuildContext context,
    required Color cardBg,
    required Color color,
    required String barcode,
    required String name,
    required bool isDirty,
    required bool isPaid,
    required bool isRtsWithPay,
    required bool isRtsNoPay,
    required bool isLocked,
    required bool isVisible,
    required bool inSyncQueue,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: color, width: 3),
        ),
      ),
      child: InkWell(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      barcode.isEmpty ? 'Unknown' : barcode,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    if (name.isNotEmpty && !isLocked) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isDirty) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.amber.shade400),
                  ),
                  child: Text(
                    'UNSYNCED',
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                      color: Colors.amber.shade800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
              if (inSyncQueue) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sync_lock_rounded, size: 8, color: Colors.blue.shade700),
                      const SizedBox(width: 2),
                      Text(
                        'PENDING SYNC',
                        style: TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.w800,
                          color: Colors.blue.shade800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Compact mode indicator
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.compress_rounded, size: 10, color: Colors.grey),
              ),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              if (isPaid) ...[
                const SizedBox(width: 4),
                Text(
                  'PAID',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: Colors.green.shade600,
                  ),
                ),
              ],
              if (isLocked)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(Icons.lock_outline_rounded, color: Colors.grey.shade400, size: 14),
                )
              else if (!isVisible) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(Icons.lock_outline_rounded, color: Colors.red.shade300, size: 14),
                ),
              ] else if (widget.showChevron)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: AnimatedRotation(
                    turns: _isExpanded ? 0.25 : 0.0, // 90 degrees when expanded
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey.shade400),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
