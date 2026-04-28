// DOCS: docs/features/wallet.md — update that file when you edit this one.

import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';
import 'package:fsi_courier_app/shared/widgets/date_strip_with_deliveries.dart';

import 'package:fsi_courier_app/core/config.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

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
      if ((_data['status'] as String?)?.toUpperCase() == 'PAID') {
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
    final totalItems = _data['total_items'];
    final breakdown = asStringDynamicMap(_data['breakdown']);
    final transactionHistory =
        (_data['transaction_history'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];

    return Scaffold(
      appBar: AppHeaderBar(title: reference),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notFound != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: DSIconSize.xl,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? DSColors.labelTertiaryDark
                        : DSColors.labelTertiary,
                  ),
                  DSSpacing.hMd,
                  Text(
                    _notFound!,
                    style: DSTypography.body(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? DSColors.labelSecondaryDark
                          : DSColors.labelSecondary,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(DSSpacing.md, DSSpacing.sm, DSSpacing.md, DSSpacing.xl),
                children: [
                  // ── Amount hero ──────────────────────────────────────────
                  _PayoutHeroFlipCard(
                    amount: amount,
                    status: status,
                    reference: reference,
                    periodLabel: periodLabel,
                    totalItems: totalItems,
                    breakdown: breakdown,
                  ).dsHeroEntry(),

                  DSSpacing.hMd,

                  // ── Status History ───────────────────────────────────────
                  _SectionCard(
                    title: 'Status History',
                    trailing: transactionHistory.isNotEmpty
                        ? TextButton(
                            onPressed: () => _showTransactionHistory(
                              context,
                              transactionHistory,
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: DSColors.primary,
                              textStyle: const TextStyle(
                                fontSize: DSTypography.sizeMd,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: const Text('View All'),
                          )
                        : null,
                    children: const [],
                  ).dsCardEntry(delay: DSAnimations.stagger(1, step: DSAnimations.staggerNormal)),

                  DSSpacing.hMd,

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
          (day['deliveries'] as List?)?.whereType<Map<String, dynamic>>().map((
            d,
          ) {
            final status = (d['delivery_status'] ?? 'DELIVERED')
                .toString()
                .toUpperCase();
            // FAILED_DELIVERY deliveries included in a payout are implicitly verified
            // with pay — no chevron, no navigation (same as status list).
            final defaultFailedDeliveryVerif = status == 'FAILED_DELIVERY'
                ? 'verified_with_pay'
                : 'unvalidated';
            return <String, dynamic>{
              ...d,
              'delivery_status': status,
              'barcode_value': d['barcode_value'] ?? d['barcode'],
              'sequence_number': d['sequence_number'] ?? d['sequence'],
              'product': d['product'] ?? d['mail_type'],
              'transaction_at':
                  d['transaction_at'] ?? d['delivered_date'] ?? d['paid_at'],
              'rts_verification_status':
                  d['rts_verification_status'] ??
                  d['failed_delivery_verification_status'] ??
                  d['verification_status'] ??
                  d['failed_delivery_verification'] ??
                  d['status_verification'] ??
                  defaultFailedDeliveryVerif,
            };
          }).toList() ??
          [];
      return <String, dynamic>{
        ...day,
        'deliveries': deliveries,
        'delivery_count':
            deliveries.length, // Ensure volume is available for the tiles
      };
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
            enableHoldToReveal: false,
            lockDeliveryNavigation: true,
          ),
        ],
      ),
      DSSpacing.hMd,
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
      backgroundColor: DSColors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.92,
        minChildSize: 0.3,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: isDark ? DSColors.cardDark : DSColors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(DSSpacing.xl)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: EdgeInsets.only(top: DSSpacing.md, bottom: DSSpacing.xs),
                  width: DSIconSize.heroSm,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? DSColors.white.withValues(
                            alpha: DSStyles.alphaMuted,
                          )
                        : DSColors.labelTertiary,
                    borderRadius: DSStyles.pillRadius,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(DSSpacing.lg, DSSpacing.md, DSSpacing.lg, 0),
                child: Text(
                  'Transaction History',
                  style: DSTypography.heading().copyWith(
                    fontSize: DSTypography.sizeMd,
                  ),
                ),
              ),
              DSSpacing.hMd,
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  padding: EdgeInsets.fromLTRB(DSSpacing.lg, 0, DSSpacing.lg, DSSpacing.xl),
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
                            width: DSStyles.strokeWidth,
                            child: Column(
                              children: [
                                Container(
                                  width: DSIconSize.xs,
                                  height: DSIconSize.xs,
                                  margin: EdgeInsets.only(top: DSSpacing.xs),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: DSColors.primary,
                                  ),
                                ),
                                if (!isLast)
                                  Expanded(
                                    child: Container(
                                      width: DSStyles.strokeWidth,
                                      margin: EdgeInsets.symmetric(
                                        vertical: DSSpacing.xs,
                                      ),
                                      color: DSColors.primary.withValues(
                                        alpha: DSStyles.alphaMuted,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          DSSpacing.wSm,
                          // Content
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    label,
                                    style:
                                        DSTypography.body(
                                          color: isDark
                                              ? DSColors.labelPrimaryDark
                                              : DSColors.labelPrimary,
                                        ).copyWith(
                                          fontSize: DSTypography.sizeMd,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  DSSpacing.hXs,
                                  Text(
                                    timestamp,
                                    style: TextStyle(
                                      fontSize: DSTypography.sizeSm,
                                      color: isDark
                                          ? DSColors.labelSecondaryDark
                                          : DSColors.labelSecondary,
                                    ),
                                  ),
                                  if (by != null && by.isNotEmpty) ...[
                                    DSSpacing.hXs,
                                    Text(
                                      'By: $by',
                                      style: TextStyle(
                                        fontSize: DSTypography.sizeSm,
                                        color: DSColors.accent,
                                      ),
                                    ),
                                  ],
                                  if (remarks != null &&
                                      remarks.isNotEmpty) ...[
                                    DSSpacing.hXs,
                                    Text(
                                      remarks,
                                      style: TextStyle(
                                        fontSize: DSTypography.sizeSm,
                                        color: isDark
                                            ? DSColors.labelSecondaryDark
                                            : DSColors.labelSecondary,
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
    final trailingWidget = trailing;
    return Card(
      elevation: DSStyles.elevationNone,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: DSStyles.cardRadius,
        side: BorderSide(
          color: Theme.of(
            context,
          ).dividerColor.withValues(alpha: DSStyles.alphaMuted),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(DSSpacing.md, DSSpacing.md, DSSpacing.md, DSSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? DSColors.labelSecondaryDark
                          : DSColors.labelSecondary,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (trailingWidget != null) trailingWidget,
              ],
            ),
            DSSpacing.hMd,
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
    final (bg, fg) = switch (status.toUpperCase()) {
      'PAID' => (
        DSColors.white.withValues(alpha: DSStyles.alphaMuted),
        DSColors.white,
      ),
      'REJECTED' => (
        DSColors.error.withValues(alpha: DSStyles.alphaMuted),
        DSColors.white,
      ),
      'PROCESSING' => (
        DSColors.warning.withValues(alpha: DSStyles.alphaMuted),
        DSColors.white,
      ),
      _ => (
        DSColors.white.withValues(alpha: DSStyles.alphaSubtle),
        DSColors.white.withValues(alpha: DSStyles.alphaDisabled),
      ),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: DSSpacing.md,
        vertical: 5,
      ),
      decoration: BoxDecoration(color: bg, borderRadius: DSStyles.cardRadius),
      child: Text(
        status.isEmpty ? '—' : status.replaceAll('_', ' ').toUpperCase(),
        style: DSTypography.label(
          color: fg,
        ).copyWith(fontSize: DSTypography.sizeSm, fontWeight: FontWeight.w600),
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
      duration: DSAnimations.dSlow,
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
          style: DSTypography.caption(
            color: DSColors.white.withValues(alpha: DSStyles.alphaDisabled),
          ).copyWith(fontSize: DSTypography.sizeSm),
        ),
        DSSpacing.hXs,
        Text(
          value,
          style: DSTypography.body(color: DSColors.white).copyWith(
            fontSize: DSTypography.sizeMd,
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
          colors: [DSColors.primary, DSColors.success],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: DSStyles.cardRadius,
        boxShadow: [
          BoxShadow(
            color: DSColors.primary.withValues(alpha: DSStyles.alphaMuted),
            blurRadius: DSStyles.radiusMD,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(DSSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Payout Amount',
                  style: DSTypography.caption(
                    color: DSColors.white.withValues(alpha: DSStyles.alphaDisabled),
                  ).copyWith(fontSize: DSTypography.sizeMd),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _StatusBadgeLight(widget.status),
            ],
          ),
          DSSpacing.hXs,
          Text(
            '₱ ${widget.amount.toStringAsFixed(2)}',
            style: DSTypography.display(
              color: DSColors.white,
            ).copyWith(fontSize: DSIconSize.xl, fontWeight: FontWeight.w800),
          ),
          DSSpacing.hMd,
          Divider(
            color: DSColors.white.withValues(alpha: DSStyles.alphaMuted),
            height: DSStyles.borderWidth,
          ),
          DSSpacing.hMd,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.totalItems != null)
                Expanded(
                  flex: 2,
                  child: _buildHeroDetail('Items', '${widget.totalItems}'),
                ),
              Expanded(
                flex: 3,
                child: _buildHeroDetail('Reference', widget.reference),
              ),
              Expanded(
                flex: 4,
                child: _buildHeroDetail('Period', widget.periodLabel),
              ),
            ],
          ),
          if (widget.breakdown.isNotEmpty) ...[
            DSSpacing.hMd,
            Center(
              child: Text(
                'Tap to reveal breakdown',
                style: DSTypography.caption(
                  color: DSColors.white.withValues(alpha: DSStyles.alphaMuted),
                ).copyWith(fontSize: DSTypography.sizeSm),
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
            ? DSColors.cardDark
            : DSColors.white,
        borderRadius: DSStyles.cardRadius,
        border: Border.all(
          color: Theme.of(
            context,
          ).dividerColor.withValues(alpha: DSStyles.alphaSoft),
        ),
      ),
      padding: EdgeInsets.all(DSSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Breakdown Details',
                  style: TextStyle(
                    fontSize: DSTypography.sizeMd,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? DSColors.white
                        : DSColors.labelPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _StatusBadgeLight(widget.status),
            ],
          ),
          DSSpacing.hMd,
          ...widget.breakdown.entries
              .where((e) {
                if (e.key == 'coordinator_incentive') return kAppDebugMode;
                return true;
              })
              .map((e) {
                final val = double.tryParse('${e.value}') ?? 0.0;
                final isDeduction = val < 0;
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final isCoordinator = e.key == 'coordinator_incentive';

                return Padding(
                  padding: EdgeInsets.only(bottom: DSSpacing.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isCoordinator
                                  ? '⚠ ${_formatKey(e.key)}'
                                  : _formatKey(e.key),
                              style: TextStyle(
                                fontSize: DSTypography.sizeMd,
                                color: isCoordinator
                                    ? DSColors.error
                                    : (isDark
                                          ? DSColors.labelTertiary
                                          : DSColors.labelSecondary),
                                fontWeight: isCoordinator
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (isCoordinator)
                              Text(
                                'DEBUG ONLY',
                                style: TextStyle(
                                  fontSize: DSTypography.sizeXs,
                                  color: DSColors.error,
                                  letterSpacing: 0.4,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '${isDeduction ? '-' : ''}₱ ${val.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: DSTypography.sizeMd,
                          fontWeight: FontWeight.w600,
                          color: isCoordinator
                              ? DSColors.error
                              : (isDeduction
                                    ? DSColors.error
                                    : (isDark ? DSColors.white : DSColors.labelPrimary)),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          DSSpacing.hMd,
          Center(
            child: Text(
              'Tap to flip back',
              style: DSTypography.caption(
                color: DSColors.labelSecondary.withValues(alpha: DSStyles.alphaDisabled),
              ).copyWith(fontSize: DSTypography.sizeSm),
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
