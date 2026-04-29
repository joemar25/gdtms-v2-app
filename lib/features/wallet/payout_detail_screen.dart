// DOCS: docs/development-standards.md
// DOCS: docs/features/wallet.md — update that file when you edit this one.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';

import 'package:fsi_courier_app/core/config.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/features/wallet/widgets/deliveries_rundown_card.dart';

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
          : 'wallet.detail.not_found'.tr();
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
      appBar: AppHeaderBar(
        title: reference,
        actions: [
          if (transactionHistory.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.history_rounded),
              onPressed: () =>
                  _showTransactionHistory(context, transactionHistory),
              tooltip: 'wallet.detail.view_history'.tr(),
            ),
        ],
        showNotificationBell: false,
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
                padding: EdgeInsets.fromLTRB(
                  DSSpacing.md,
                  DSSpacing.sm,
                  DSSpacing.md,
                  DSSpacing.xl,
                ),
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

    return [
      _SectionCard(
        title: 'wallet.detail.deliveries_rundown'.tr().toUpperCase(),
        children: [
          DeliveriesRundownCard(dailyBreakdown: _accumulatedBreakdown),
          if (_hasMoreBreakdownPages)
            Padding(
              padding: const EdgeInsets.only(top: DSSpacing.md),
              child: Center(
                child: _loadingMoreDays
                    ? const CircularProgressIndicator()
                    : TextButton(
                        onPressed: _loadMoreBreakdown,
                        child: Text('wallet.detail.load_more'.tr()),
                      ),
              ),
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
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: isDark ? DSColors.cardDark : DSColors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(DSStyles.radiusSheet),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(
                    top: DSSpacing.md,
                    bottom: DSSpacing.xs,
                  ),
                  width: DSSpacing.xl,
                  height: DSStyles.strokeWidth * 2,
                  decoration: BoxDecoration(
                    color: isDark
                        ? DSColors.white.withValues(alpha: DSStyles.alphaMuted)
                        : DSColors.labelTertiary,
                    borderRadius: DSStyles.pillRadius,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(DSSpacing.lg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'wallet.detail.request_lifecycle'.tr(),
                      style: DSTypography.heading().copyWith(
                        fontSize: DSTypography.sizeLg,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: isDark
                            ? DSColors.white.withValues(
                                alpha: DSStyles.alphaSubtle,
                              )
                            : DSColors.black.withValues(
                                alpha: DSStyles.alphaSubtle,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  padding: EdgeInsets.fromLTRB(
                    DSSpacing.lg,
                    0,
                    DSSpacing.lg,
                    DSSpacing.xl,
                  ),
                  itemCount: history.length,
                  itemBuilder: (_, i) {
                    final item = history[i];
                    final label = '${item['label'] ?? item['event'] ?? ''}';
                    final timestamp = formatDate(
                      '${item['timestamp'] ?? ''}',
                      includeTime: true,
                    );
                    final remarks = item['remarks']?.toString() ?? '';
                    final isLast = i == history.length - 1;

                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Timeline spine
                          Column(
                            children: [
                              Container(
                                width: DSIconSize.xs,
                                height: DSIconSize.xs,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: DSColors.primary,
                                  border: Border.all(
                                    color: DSColors.primary.withValues(
                                      alpha: DSStyles.alphaSubtle,
                                    ),
                                    width: DSStyles.strokeWidth,
                                    strokeAlign: BorderSide.strokeAlignOutside,
                                  ),
                                ),
                              ),
                              if (!isLast)
                                Expanded(
                                  child: Container(
                                    width: DSStyles.strokeWidth,
                                    margin: const EdgeInsets.symmetric(
                                      vertical: DSSpacing.xs,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          DSColors.primary,
                                          DSColors.primary.withValues(
                                            alpha: DSStyles.alphaMuted,
                                          ),
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          DSSpacing.wMd,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label.replaceAll('_', ' ').toUpperCase(),
                                  style: DSTypography.body().copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: DSTypography.sizeSm,
                                    letterSpacing: DSTypography.lsLoose,
                                    color: isDark
                                        ? DSColors.white
                                        : DSColors.labelPrimary,
                                  ),
                                ),
                                const SizedBox(
                                  height: 2,
                                ), // Keep minimal gap for readability, or use token if available
                                Text(
                                  timestamp,
                                  style: DSTypography.caption(
                                    color: isDark
                                        ? DSColors.labelSecondaryDark
                                        : DSColors.labelSecondary,
                                  ).copyWith(fontSize: DSTypography.sizeSm),
                                ),
                                if (remarks.isNotEmpty) ...[
                                  DSSpacing.hXs,
                                  Container(
                                    padding: const EdgeInsets.all(DSSpacing.sm),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? DSColors.white.withValues(
                                              alpha: DSStyles.alphaSubtle,
                                            )
                                          : DSColors.black.withValues(
                                              alpha: DSStyles.alphaSubtle,
                                            ),
                                      borderRadius: DSStyles.cardRadius,
                                    ),
                                    child: Text(
                                      remarks,
                                      style: DSTypography.body().copyWith(
                                        fontSize: DSTypography.sizeSm,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                                if (!isLast) DSSpacing.hLg,
                              ],
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
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
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
        padding: const EdgeInsets.all(DSSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).brightness == Brightness.dark
                    ? DSColors.labelSecondaryDark
                    : DSColors.labelSecondary,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w600,
              ),
            ),
            DSSpacing.hSm,
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
      padding: EdgeInsets.symmetric(horizontal: DSSpacing.md, vertical: 5),
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
          label.toUpperCase(),
          style: DSTypography.label().copyWith(
            fontSize: DSTypography.sizeXs,
            fontWeight: FontWeight.w800,
            letterSpacing: DSTypography.lsExtraLoose,
            color: DSColors.white.withValues(alpha: DSStyles.alphaDisabled),
          ),
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
                  'wallet.detail.payout_amount'.tr().toUpperCase(),
                  style: DSTypography.label().copyWith(
                    fontSize: DSTypography.sizeXs,
                    fontWeight: FontWeight.w800,
                    letterSpacing: DSTypography.lsExtraLoose,
                    color: DSColors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _StatusBadgeLight(widget.status),
            ],
          ),
          DSSpacing.hXs,
          Text(
            '₱ ${widget.amount.toStringAsFixed(2)}',
            style: DSTypography.display(color: DSColors.white).copyWith(
              fontSize: DSIconSize.xl,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
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
                  child: _buildHeroDetail(
                    'wallet.detail.items'.tr(),
                    '${widget.totalItems}',
                  ),
                ),
              Expanded(
                flex: 3,
                child: _buildHeroDetail(
                  'wallet.detail.reference'.tr(),
                  widget.reference,
                ),
              ),
              Expanded(
                flex: 4,
                child: _buildHeroDetail(
                  'wallet.detail.period'.tr(),
                  widget.periodLabel,
                ),
              ),
            ],
          ),
          if (widget.breakdown.isNotEmpty) ...[
            DSSpacing.hMd,
            Center(
              child: Text(
                'wallet.detail.tap_to_reveal'.tr(),
                style:
                    DSTypography.caption(
                      color: DSColors.white.withValues(
                        alpha: DSStyles.alphaDisabled,
                      ),
                    ).copyWith(
                      fontSize: DSTypography.sizeSm,
                      letterSpacing: DSTypography.lsLoose,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBack(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? null : DSColors.primaryGradient,
        color: isDark ? DSColors.cardDark : null,
        borderRadius: DSStyles.cardRadius,
        boxShadow: DSStyles.shadowLG(context),
      ),
      padding: const EdgeInsets.all(DSSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'wallet.detail.breakdown_details'.tr().toUpperCase(),
                  style: DSTypography.label().copyWith(
                    fontSize: DSTypography.sizeXs,
                    fontWeight: FontWeight.w800,
                    letterSpacing: DSTypography.lsExtraLoose,
                    color: DSColors.white,
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
                final label = _formatKey(e.key);

                return Padding(
                  padding: const EdgeInsets.only(bottom: DSSpacing.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        label,
                        style: DSTypography.body().copyWith(
                          color: DSColors.white.withValues(
                            alpha: DSStyles.alphaOpaque,
                          ),
                          fontSize: DSTypography.sizeSm,
                        ),
                      ),
                      Text(
                        '₱ ${val.abs().toStringAsFixed(2)}',
                        style: DSTypography.body().copyWith(
                          color: isDeduction
                              ? DSColors.errorSurface
                              : DSColors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: DSTypography.sizeMd,
                          letterSpacing: -0.2,
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
              style:
                  DSTypography.caption(
                    color: DSColors.white.withValues(
                      alpha: DSStyles.alphaDisabled,
                    ),
                  ).copyWith(
                    fontSize: DSTypography.sizeSm,
                    letterSpacing: DSTypography.lsLoose,
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
