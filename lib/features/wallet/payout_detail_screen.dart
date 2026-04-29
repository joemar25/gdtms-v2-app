// DOCS: docs/development-standards.md
// DOCS: docs/features/wallet.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/utils/formatters.dart';
import 'package:fsi_courier_app/features/wallet/widgets/deliveries_rundown_card.dart';
import 'package:fsi_courier_app/features/wallet/widgets/payout_history_sheet.dart';
import 'package:fsi_courier_app/features/wallet/widgets/payout_detail_components.dart';

/// Detailed view of a specific payout request.
///
/// Displays the breakdown of earnings, transaction history, and the
/// list of individual deliveries included in the payout.
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
      if ((_data['status'] as String?)?.toUpperCase() == 'PAID') {
        _markLocalDeliveriesAsPaid(_data);
      }
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
    final from = AppFormatters.date(
      DateTime.tryParse('${_data['from_date'] ?? ''}') ?? DateTime(0),
      context,
    );
    final to = AppFormatters.date(
      DateTime.tryParse('${_data['to_date'] ?? ''}') ?? DateTime(0),
      context,
    );
    final periodLabel = (from == to) ? from : '$from – $to';
    final totalItems = _data['total_items'];
    final breakdown = asStringDynamicMap(_data['breakdown']);
    final transactionHistory =
        (_data['transaction_history'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];

    final requestedAt = _data['requested_at'] != null
        ? formatDate('${_data['requested_at']}', includeTime: true)
        : null;

    return Scaffold(
      appBar: AppHeaderBar(
        title: reference,
        actions: [
          if (transactionHistory.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.history_rounded),
              onPressed: () => showPayoutHistorySheet(
                context: context,
                history: _data['transaction_history'] ?? [],
              ),
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
                padding: const EdgeInsets.fromLTRB(
                  DSSpacing.md,
                  DSSpacing.sm,
                  DSSpacing.md,
                  DSSpacing.xl,
                ),
                children: [
                  PayoutHeroFlipCard(
                    amount: amount,
                    status: status,
                    reference: reference,
                    periodLabel: periodLabel,
                    requestedAt: requestedAt,
                    totalItems: totalItems,
                    breakdown: breakdown,
                  ).dsHeroEntry(),

                  DSSpacing.hMd,
                  ..._buildDateStripSection(),
                ],
              ),
            ),
    );
  }

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

    final List<Map<String, dynamic>>
    normalised = raw.whereType<Map<String, dynamic>>().map((day) {
      final deliveries =
          (day['deliveries'] as List?)?.whereType<Map<String, dynamic>>().map((
            d,
          ) {
            final status = (d['delivery_status'] ?? 'DELIVERED')
                .toString()
                .toUpperCase();
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
        'delivery_count': deliveries.length,
      };
    }).toList();

    // Sort by date descending (latest first)
    normalised.sort((a, b) {
      final dateA = DateTime.tryParse('${a['date'] ?? ''}') ?? DateTime(0);
      final dateB = DateTime.tryParse('${b['date'] ?? ''}') ?? DateTime(0);
      return dateB.compareTo(dateA);
    });

    return normalised;
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
        final merged = [..._accumulatedBreakdown, ...newDays];
        // Ensure the entire merged list is sorted by date descending
        merged.sort((a, b) {
          final dateA = DateTime.tryParse('${a['date'] ?? ''}') ?? DateTime(0);
          final dateB = DateTime.tryParse('${b['date'] ?? ''}') ?? DateTime(0);
          return dateB.compareTo(dateA);
        });
        _accumulatedBreakdown = merged;
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
      SectionCard(
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
      ).dsCardEntry(delay: DSAnimations.stagger(1)),
      DSSpacing.hMd,
    ];
  }
}
