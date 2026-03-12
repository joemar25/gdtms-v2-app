import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/api/api_result.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';
import 'package:fsi_courier_app/shared/widgets/date_strip_with_deliveries.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';
import 'package:fsi_courier_app/core/config.dart';

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

  // ── Daily-breakdown pagination ─────────────────────────────────────────
  int _breakdownPage = 1;
  bool _loadingMoreDays = false;
  bool _hasMoreBreakdownPages = false;
  List<Map<String, dynamic>> _accumulatedBreakdown = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _markLocalDeliveriesAsPaid(Map<String, dynamic> data) {
    // API v2.0: daily_breakdown is { data: [...], meta: {} }
    // API v1.x: daily_breakdown is a flat List
    final rawBreakdown = data['daily_breakdown'];
    final List<dynamic> raw;
    if (rawBreakdown is List) {
      raw = rawBreakdown;
    } else if (rawBreakdown is Map<String, dynamic>) {
      final inner = rawBreakdown['data'];
      raw = inner is List ? inner : const [];
    } else {
      return;
    }
    final barcodes = <String>[];
    for (final day in raw.whereType<Map<String, dynamic>>()) {
      final deliveries = day['deliveries'];
      if (deliveries is! List) continue;
      for (final d in deliveries.whereType<Map<String, dynamic>>()) {
        final barcode = (d['barcode_value'] ?? d['barcode'])?.toString() ?? '';
        if (barcode.isNotEmpty) barcodes.add(barcode);
      }
    }
    if (barcodes.isNotEmpty) {
      LocalDeliveryDao.instance.markAsPaid(barcodes);
    }
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
      // Privacy rule: if payout is paid, mark all associated delivered records
      // with paid_at so the cleanup service applies the shorter 1-day retention
      // (kPaidDeliveryRetentionDays) instead of the standard window.
      if ((_data['status'] as String?)?.toLowerCase() == 'paid') {
        _markLocalDeliveriesAsPaid(_data);
      }
      // Initialise breakdown + pagination
      _accumulatedBreakdown = _normalisedBreakdown();
      _breakdownPage = 1;
      final rawBreakdown = _data['daily_breakdown'];
      if (rawBreakdown is Map<String, dynamic>) {
        final meta = rawBreakdown['meta'] as Map<String, dynamic>?;
        if (meta != null) {
          final currentPage = (meta['current_page'] as num?)?.toInt() ?? 1;
          final lastPage = (meta['last_page'] as num?)?.toInt() ?? 1;
          _breakdownPage = currentPage;
          _hasMoreBreakdownPages = currentPage < lastPage;
        }
      }
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
    final requestedAt = formatDate(
      '${_data['requested_at'] ?? ''}',
      includeTime: true,
    );
    final approvedAt = formatDate(_data['approved_at'], includeTime: true);
    final paidAt = formatDate('${_data['paid_at'] ?? ''}', includeTime: true);
    final totalItems = _data['total_items'];
    final breakdown = asStringDynamicMap(_data['breakdown']);
    final transactionHistory =
        (_data['transaction_history'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];

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
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  // ── Amount hero ──────────────────────────────────────────
                  _PayoutHeroFlipCard(
                    amount: amount,
                    status: status,
                    reference: reference,
                    periodLabel: periodLabel,
                    totalItems: totalItems,
                    breakdown: breakdown,
                  ),

                  const SizedBox(height: 12),

                  // ── Status History ───────────────────────────────────────
                  _SectionCard(
                    title: 'Status History', trailing: transactionHistory.isNotEmpty
                        ? TextButton(
                            onPressed: () => _showTransactionHistory(
                              context,
                              transactionHistory,
                            ),
                            child: const Text('View all'),
                          )
                        : null,                    children: [
                      _buildHorizontalStepper(
                        context,
                        status,
                        requestedAt,
                        approvedAt,
                        paidAt,
                      ),
                    ],
                  ),

                  // ── Daily breakdown ──────────────────────────────────────
                  ..._buildDateStripSection(),
                ],
              ),
            ),
    );
  }

  // Normalises the daily_breakdown from the API into a flat list suitable for
  // DateStripWithDeliveries.
  List<Map<String, dynamic>> _normalisedBreakdown([dynamic rawOverride]) {
    final rawBreakdown = rawOverride ?? _data['daily_breakdown'];
    final List<dynamic> raw;
    if (rawBreakdown is List) {
      raw = rawBreakdown;
    } else if (rawBreakdown is Map<String, dynamic>) {
      final inner = rawBreakdown['data'];
      raw = inner is List ? inner : const [];
    } else {
      return [];
    }

    return raw.whereType<Map<String, dynamic>>().map((day) {
      // Ensure each delivery has a delivery_status field so DeliveryCard
      // can colour-code correctly (all deliveries in a payout are delivered).
      final deliveries =
          (day['deliveries'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(
                (d) => <String, dynamic>{
                  ...d,
                  'delivery_status': d['delivery_status'] ?? 'delivered',
                },
              )
              .toList() ??
          [];
      return <String, dynamic>{...day, 'deliveries': deliveries};
    }).toList();
  }

  Future<void> _loadMoreBreakdown() async {
    if (_loadingMoreDays || !mounted) return;
    setState(() => _loadingMoreDays = true);
    final nextPage = _breakdownPage + 1;
    final result = await ref
        .read(apiClientProvider)
        .get<Map<String, dynamic>>(
          '/wallet/${widget.reference}?page=$nextPage',
          parser: parseApiMap,
        );
    if (!mounted) return;
    if (result case ApiSuccess<Map<String, dynamic>>(:final data)) {
      final pageData = mapFromKey(data, 'data');
      final newDays = _normalisedBreakdown(pageData['daily_breakdown']);
      final rawBreakdown = pageData['daily_breakdown'];
      final meta = (rawBreakdown is Map<String, dynamic>)
          ? rawBreakdown['meta'] as Map<String, dynamic>?
          : null;
      final lastPage = (meta?['last_page'] as num?)?.toInt() ?? nextPage;
      setState(() {
        _accumulatedBreakdown = [..._accumulatedBreakdown, ...newDays];
        _breakdownPage = nextPage;
        _hasMoreBreakdownPages = nextPage < lastPage;
        _loadingMoreDays = false;
      });
    } else {
      setState(() => _loadingMoreDays = false);
    }
  }

  List<Widget> _buildDateStripSection() {
    if (_accumulatedBreakdown.isEmpty) return [];

    // Anchor the strip at the coverage end date so deliveries are visible
    // immediately without scrolling.
    final toDateStr = _data['to_date'] as String?;
    DateTime? referenceDate;
    if (toDateStr != null && toDateStr.isNotEmpty) {
      try {
        referenceDate = DateTime.parse(toDateStr);
      } catch (_) {}
    }

    // Pre-select the last day that contains deliveries.
    final daysWithDeliveries = _accumulatedBreakdown
        .where((d) => (d['deliveries'] as List?)?.isNotEmpty == true)
        .toList();
    final initialDate = daysWithDeliveries.isNotEmpty
        ? daysWithDeliveries.last['date'] as String?
        : _accumulatedBreakdown.last['date'] as String?;

    return [
      _SectionCard(
        title: 'DAILY BREAKDOWN',
        children: [
          DateStripWithDeliveries(
            dailyBreakdown: _accumulatedBreakdown,
            initialSelectedDate: initialDate,
            referenceDate: referenceDate,
            showDayTotal: false,
            dataMode: false,
            hasMorePages: _hasMoreBreakdownPages,
            onLoadMore: _loadingMoreDays ? null : _loadMoreBreakdown,
          ),
        ],
      ),
      const SizedBox(height: 12),
    ];
  }



  void _showTransactionHistory(
    BuildContext context,
    List<Map<String, dynamic>> history,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.92,
        minChildSize: 0.3,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: isDark ? ColorStyles.grabCardDark : ColorStyles.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Text(
                  'Transaction History',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? ColorStyles.white : ColorStyles.black,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  itemCount: history.length,
                  itemBuilder: (_, i) {
                    final item = history[i];
                    final label = '${item['label'] ?? item['event'] ?? ''}';
                    final timestamp = formatDate(
                      '${item['timestamp'] ?? ''}',
                      includeTime: true,
                    );
                    final by = item['by']?.toString();
                    final remarks = item['remarks']?.toString();
                    final isLast = i == history.length - 1;

                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Timeline spine
                          SizedBox(
                            width: 28,
                            child: Column(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  margin: const EdgeInsets.only(top: 3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: ColorStyles.grabGreen,
                                  ),
                                ),
                                if (!isLast)
                                  Expanded(
                                    child: Container(
                                      width: 2,
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      color: ColorStyles.grabGreen
                                          .withValues(alpha: 0.25),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Content
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                bottom: isLast ? 0 : 16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? ColorStyles.white
                                          : ColorStyles.black,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    timestamp,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: ColorStyles.subSecondary,
                                    ),
                                  ),
                                  if (by != null && by.isNotEmpty) ...[                                    const SizedBox(height: 2),
                                    Text(
                                      'By: $by',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: ColorStyles.secondary,
                                      ),
                                    ),
                                  ],
                                  if (remarks != null &&
                                      remarks.isNotEmpty) ...[                                    const SizedBox(height: 2),
                                    Text(
                                      remarks,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: ColorStyles.subSecondary,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalStepper(
    BuildContext context,
    String status,
    String req,
    String app,
    String paid,
  ) {
    bool isDone(String val) =>
        val.isNotEmpty &&
        val.toLowerCase() != 'null' &&
        val != '—' &&
        val != '-';

    final s = status.toLowerCase();
    
    // Status Lifecycle: Submitted (Pending) -> Operations Approved -> HR Processing -> Paid
    final steps = [
      {'title': 'Submitted', 'date': req, 'done': true}, // Always done if we are here
      {
        'title': 'Ops Approved', 
        'date': (isDone(app) && s != 'pending') ? app : '', 
        'done': s == 'ops_approved' || s == 'hr_approved' || s == 'paid'
      },
      {
        'title': 'HR Processing', 
        'date': '', // API doesn't seem to provide a specific hr_approved_at yet
        'done': s == 'hr_approved' || s == 'paid'
      },
      {'title': 'Paid', 'date': paid, 'done': s == 'paid'},
    ];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          // Row 1: circles + connector lines, centered vertically
          Row(
            children: List.generate(steps.length, (index) {
              final isDone = steps[index]['done'] as bool;
              final isFirst = index == 0;
              final isLast = index == steps.length - 1;
              final isNextDone = !isLast && (steps[index + 1]['done'] as bool);

              return Expanded(
                child: Row(
                  children: [
                    // Leading connector line (all steps except first)
                    if (!isFirst)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: isDone
                              ? ColorStyles.grabGreen
                              : Colors.grey.shade300,
                        ),
                      ),
                    // Step circle (centered)
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
                    // Trailing connector line (all steps except last)
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
              );
            }),
          ),
          const SizedBox(height: 8),
          // Row 2: labels centered under each circle
          Row(
            children: List.generate(steps.length, (index) {
              final step = steps[index];
              final title = step['title'] as String;
              final date = step['date'] as String;
              final isDone = step['done'] as bool;

              return Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
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
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
    this.trailing,
  });
  final String title;
  final List<Widget> children;
  final Widget? trailing;

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
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.grey.shade500,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
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
        status.isEmpty ? '—' : status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _PayoutHeroFlipCard extends StatefulWidget {
  const _PayoutHeroFlipCard({
    required this.amount,
    required this.status,
    required this.reference,
    required this.periodLabel,
    this.totalItems,
    required this.breakdown,
  });

  final double amount;
  final String status;
  final String reference;
  final String periodLabel;
  final int? totalItems;
  final Map<String, dynamic> breakdown;

  @override
  State<_PayoutHeroFlipCard> createState() => _PayoutHeroFlipCardState();
}

class _PayoutHeroFlipCardState extends State<_PayoutHeroFlipCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    _isFront = !_isFront;
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

  Widget _buildFront() {
    return Container(
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
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              _StatusBadgeLight(widget.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '₱ ${widget.amount.toStringAsFixed(2)}',
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
                child: _buildHeroDetail('Reference', widget.reference),
              ),
              Expanded(
                flex: 4,
                child: _buildHeroDetail('Period', widget.periodLabel),
              ),
              if (widget.totalItems != null)
                Expanded(
                  flex: 2,
                  child: _buildHeroDetail('Items', '${widget.totalItems}'),
                ),
            ],
          ),
          if (widget.breakdown.isNotEmpty) ...[
            const SizedBox(height: 14),
            Center(
              child: Text(
                'Tap to reveal breakdown',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBack(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? ColorStyles.grabCardDark
            : ColorStyles.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Breakdown Details',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87,
                ),
              ),
              _StatusBadgeLight(widget.status),
            ],
          ),
          const SizedBox(height: 16),
          ...widget.breakdown.entries.where((e) {
            if (e.key == 'coordinator_incentive') return kAppDebugMode;
            return true;
          }).map((e) {
            final val = double.tryParse('${e.value}') ?? 0.0;
            final isDeduction = val < 0;
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    e.key == 'coordinator_incentive' 
                        ? 'Coordinator Incentive (for debug only)' 
                        : _formatKey(e.key),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
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
          }),
          const SizedBox(height: 14),
          Center(
            child: Text(
              'Tap to flip back',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.breakdown.isNotEmpty ? _flip : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final isUnder = _controller.value > 0.5;
          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.001) // perspective
            ..rotateX(_controller.value * math.pi);
            
          return Transform(
            transform: transform,
            alignment: Alignment.center,
            child: isUnder
                ? Transform(
                    transform: Matrix4.identity()..rotateX(math.pi),
                    alignment: Alignment.center,
                    child: _buildBack(context),
                  )
                : _buildFront(),
          );
        },
      ),
    );
  }
}
