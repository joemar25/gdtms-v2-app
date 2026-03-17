import 'package:flutter/material.dart';

import 'package:fsi_courier_app/shared/helpers/delivery_identifier.dart';

class DeliveryCard extends StatelessWidget {
  const DeliveryCard({
    super.key,
    required this.delivery,
    required this.onTap,
    this.compact = false,
    this.showChevron = true,
  });

  final Map<String, dynamic> delivery;
  final VoidCallback onTap;
  final bool compact;
  final bool showChevron;

  static Color statusColor(String status) {
    return switch (status.toLowerCase()) {
      'pending' => Colors.orange,
      'delivered' => Colors.green,
      'rts' => Colors.red,
      'osa' => Colors.amber,
      'dispatched' => Colors.blue,
      _ => Colors.grey,
    };
  }

  @override
  Widget build(BuildContext context) {
    final barcode = resolveDeliveryIdentifier(delivery);
    final status = delivery['delivery_status']?.toString() ?? 'pending';
    final jobOrder = (delivery['job_order'] ?? delivery['tracking_number'] ?? '').toString();
    final address = (delivery['address'] ?? delivery['delivery_address'] ?? '').toString();
    final name = (delivery['name'] ??
            delivery['recipient'] ??
            delivery['recipient_name'] ??
            '')
        .toString();
    final syncStatus = delivery['_sync_status']?.toString() ?? 'clean';
    final isDirty = syncStatus == 'dirty';
    final color = isDirty ? Colors.amber.shade700 : statusColor(status);
    final isPaid = delivery['_paid_at'] != null;
    final rtsVerifStatus =
        delivery['_rts_verification_status']?.toString() ??
        delivery['rts_verification_status']?.toString() ??
        'unvalidated';
    final isRtsWithPay = status == 'rts' && rtsVerifStatus == 'verified_with_pay';
    final isRtsNoPay = status == 'rts' && rtsVerifStatus == 'verified_no_pay';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    if (compact) {
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
          onTap: onTap,
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
                      if (name.isNotEmpty) ...[
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
                if (isRtsWithPay || isRtsNoPay) ...[
                  const SizedBox(width: 5),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: isRtsWithPay
                          ? Colors.green.shade500
                          : Colors.red.shade400,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    isRtsWithPay ? 'W/PAY' : 'NO PAY',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: isRtsWithPay
                          ? Colors.teal.shade600
                          : Colors.red.shade400,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // ── Full card ─────────────────────────────────────────────────────────
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(color: color, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
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
                        if (jobOrder.isNotEmpty)
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
                    if (name.isNotEmpty) ...[
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
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                    if (isDirty) ...[
                      const SizedBox(height: 5),
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
                            Icon(Icons.sync_problem_rounded, size: 10, color: Colors.amber.shade700),
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
                    ],
                    if (isPaid) ...[
                      const SizedBox(height: 5),
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
                    ],
                    if (isRtsWithPay || isRtsNoPay) ...[
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isRtsWithPay
                              ? Colors.teal.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isRtsWithPay
                                ? Colors.teal.shade200
                                : Colors.red.shade200,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: isRtsWithPay
                                    ? Colors.green.shade500
                                    : Colors.red.shade400,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isRtsWithPay ? 'WITH PAY' : 'NO PAY',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: isRtsWithPay
                                    ? Colors.teal.shade700
                                    : Colors.red.shade600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showChevron) ...[
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
