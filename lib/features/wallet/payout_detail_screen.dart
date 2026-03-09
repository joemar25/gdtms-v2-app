import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/api/api_result.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';

class PayoutDetailScreen extends ConsumerStatefulWidget {
  const PayoutDetailScreen({super.key, required this.reference});

  final String reference;

  @override
  ConsumerState<PayoutDetailScreen> createState() => _PayoutDetailScreenState();
}

class _PayoutDetailScreenState extends ConsumerState<PayoutDetailScreen> {
  bool _loading = true;
  Map<String, dynamic> _data = {};
  String? _notFound;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await ref
        .read(apiClientProvider)
        .get<Map<String, dynamic>>(
          '/wallet/${widget.reference}',
          parser: parseApiMap,
        );

    if (!mounted) return;
    if (result case ApiSuccess<Map<String, dynamic>>(:final data)) {
      _data = mapFromKey(data, 'data');
    } else if (result is ApiServerError<Map<String, dynamic>>) {
      _notFound = result.message.isNotEmpty
          ? result.message
          : 'Payment request not found.';
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final reference =
        '${_data['reference'] ?? _data['payment_reference'] ?? widget.reference}';
    final status = '${_data['status'] ?? ''}';
    final amount = double.tryParse('${_data['amount'] ?? 0}') ?? 0.0;
    final from = formatDate('${_data['from_date'] ?? ''}');
    final to = formatDate('${_data['to_date'] ?? ''}');
    final periodLabel = (from == to) ? from : '$from – $to';
    final requestedAt = formatDate('${_data['requested_at'] ?? ''}');
    final approvedAt = formatDate('${_data['approved_at'] ?? ''}');
    final paidAt = formatDate('${_data['paid_at'] ?? ''}');
    final totalItems = _data['total_items'];
    final breakdown = asStringDynamicMap(_data['breakdown']);

    return Scaffold(
      appBar: AppBar(
        title: Text(reference),
        titleTextStyle: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notFound != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _notFound!,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                // ── Amount hero ──────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF007A36), Color(0xFF00B14F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: ColorStyles.grabGreen.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),

                  padding: const EdgeInsets.all(20),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Payout Amount',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          _StatusBadgeLight(status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '₱ ${amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white24, height: 1),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildHeroDetail('Reference', reference),
                          ),
                          Expanded(
                            flex: 4,
                            child: _buildHeroDetail('Period', periodLabel),
                          ),
                          if (totalItems != null)
                            Expanded(
                              flex: 2,
                              child: _buildHeroDetail('Items', '$totalItems'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Breakdown ────────────────────────────────────────────
                if (breakdown.isNotEmpty) ...[
                  _SectionCard(
                    title: 'Breakdown',
                    children: breakdown.entries.map((e) {
                      final val = double.tryParse('${e.value}') ?? 0.0;
                      final isDeduction = val < 0;
                      final isDark =
                          Theme.of(context).brightness == Brightness.dark;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatKey(e.key),
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${isDeduction ? '-' : ''}₱ ${val.abs().toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDeduction
                                    ? Colors.red.shade400
                                    : (isDark ? Colors.white : Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // ── Status History ───────────────────────────────────────
                _SectionCard(
                  title: 'Status History',
                  children: [
                    _buildHorizontalStepper(
                      context,
                      requestedAt,
                      approvedAt,
                      paidAt,
                    ),
                  ],
                ),

                // ── Daily breakdown ──────────────────────────────────────
                ..._buildDailyBreakdown(context),
              ],
            ),
    );
  }

  List<Widget> _buildDailyBreakdown(BuildContext context) {
    final raw = _data['daily_breakdown'];
    if (raw is! List || raw.isEmpty) return [];

    final days = raw.whereType<Map<String, dynamic>>().toList();
    return [
      for (final day in days) ...[
        _SectionCard(
          title: formatDate('${day['date'] ?? ''}'),
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_shipping_outlined,
                  size: 14,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 6),
                Text(
                  '${day['count'] ?? 0} deliver${(day['count'] ?? 0) == 1 ? 'y' : 'ies'}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...() {
              final deliveries = day['deliveries'];
              if (deliveries is! List) return <Widget>[];
              return deliveries
                  .whereType<Map<String, dynamic>>()
                  .map<Widget>((d) => _DeliveryRow(delivery: d))
                  .toList();
            }(),
          ],
        ),
        const SizedBox(height: 12),
      ],
    ];
  }

  String _formatKey(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  Widget _buildHeroDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalStepper(
    BuildContext context,
    String req,
    String app,
    String paid,
  ) {
    bool isDone(String val) =>
        val.isNotEmpty &&
        val.toLowerCase() != 'null' &&
        val != '—' &&
        val != '-';

    final steps = [
      {'title': 'Requested', 'date': req, 'done': isDone(req)},
      {'title': 'Approved', 'date': app, 'done': isDone(app)},
      {'title': 'Paid', 'date': paid, 'done': isDone(paid)},
    ];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(steps.length, (index) {
          final step = steps[index];
          final title = step['title'] as String;
          final date = step['date'] as String;
          final isDone = step['done'] as bool;
          final isLast = index == steps.length - 1;
          final isNextDone = !isLast && (steps[index + 1]['done'] as bool);

          return Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone
                            ? ColorStyles.grabGreen
                            : Colors.grey.shade300,
                      ),
                      child: isDone
                          ? const Icon(
                              Icons.check,
                              size: 12,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: isNextDone
                              ? ColorStyles.grabGreen
                              : Colors.grey.shade300,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDone ? textColor : Colors.grey.shade500,
                  ),
                ),
                if (date.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    date,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.grey.shade500,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _StatusBadgeLight extends StatelessWidget {
  const _StatusBadgeLight(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status.toLowerCase()) {
      'approved' => (Colors.white.withValues(alpha: 0.25), Colors.white),
      'rejected' => (Colors.red.shade400.withValues(alpha: 0.3), Colors.white),
      'processing' => (
        Colors.orange.shade300.withValues(alpha: 0.3),
        Colors.white,
      ),
      _ => (Colors.white.withValues(alpha: 0.15), Colors.white70),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.isEmpty
            ? '—'
            : status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── Daily breakdown delivery row ────────────────────────────────────────────

class _DeliveryRow extends StatelessWidget {
  const _DeliveryRow({required this.delivery});
  final Map<String, dynamic> delivery;

  @override
  Widget build(BuildContext context) {
    final barcode = delivery['barcode_value']?.toString() ?? '';
    final name = delivery['name']?.toString() ?? '';
    final address = delivery['address']?.toString() ?? '';
    final rate = double.tryParse('${delivery['rate'] ?? 0}') ?? 0.0;
    final penalty = double.tryParse('${delivery['late_penalty'] ?? 0}') ?? 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: barcode.isNotEmpty
          ? () => context.push('/deliveries/$barcode')
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A3D) : const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(color: ColorStyles.grabGreen, width: 3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    barcode,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (name.isNotEmpty)
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  if (address.isNotEmpty)
                    Text(
                      address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₱ ${rate.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ColorStyles.grabGreen,
                  ),
                ),
                if (penalty > 0)
                  Text(
                    '−₱ ${penalty.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 11, color: Colors.red),
                  ),
              ],
            ),
          ],
        ),
      ), // Container
    ); // GestureDetector
  }
}
