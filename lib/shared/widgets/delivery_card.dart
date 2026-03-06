import 'package:flutter/material.dart';

import 'package:fsi_courier_app/shared/helpers/delivery_identifier.dart';

class DeliveryCard extends StatelessWidget {
  const DeliveryCard({
    super.key,
    required this.delivery,
    required this.onTap,
    this.compact = false,
  });

  final Map<String, dynamic> delivery;
  final VoidCallback onTap;
  final bool compact;

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
    final jobOrder = delivery['job_order']?.toString() ?? '';
    final address = delivery['address']?.toString() ?? '';
    final name = (delivery['name'] ??
            delivery['recipient'] ??
            '')
        .toString();
    final color = statusColor(status);
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
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
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
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
