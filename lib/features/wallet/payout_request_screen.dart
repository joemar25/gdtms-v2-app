import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/api/api_result.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/widgets/date_strip_with_deliveries.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';

class PayoutRequestScreen extends ConsumerStatefulWidget {
  const PayoutRequestScreen({super.key});

  @override
  ConsumerState<PayoutRequestScreen> createState() =>
      _PayoutRequestScreenState();
}

class _PayoutRequestScreenState extends ConsumerState<PayoutRequestScreen> {
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _previewData;
  String? _initialSelectedDate;
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _fetchPreview();
  }

  Future<void> _fetchPreview() async {
    setState(() {
      _previewData = null;
      _error = null;
      _loading = true;
    });

    final result = await ref
        .read(apiClientProvider)
        .get<Map<String, dynamic>>('/payment-request', parser: parseApiMap);

    if (!mounted) return;

    if (result case ApiSuccess<Map<String, dynamic>>(:final data)) {
      final preview = mapFromKey(data, 'data');
      final breakdown =
          (preview['daily_breakdown'] as List?)?.cast<Map<String, dynamic>>() ??
          [];

      String? selectedDate;
      if (breakdown.isNotEmpty) {
        // Try to select today's date
        final today = DateTime.now();
        final todayStr =
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        final todayInBreakdown = breakdown.firstWhere(
          (d) => d['date'] == todayStr,
          orElse: () => <String, dynamic>{},
        );

        if (todayInBreakdown.isNotEmpty) {
          selectedDate = todayStr;
        } else {
          // Fall back to the last date in breakdown (latest available)
          selectedDate = breakdown.last['date'] as String?;
        }
      }

      setState(() {
        _previewData = preview;
        _initialSelectedDate = selectedDate;
        _refreshKey++;
        _loading = false;
      });
    } else {
      setState(() {
        _error = 'Failed to load payment preview.';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _submit() async {
    final preview = _previewData;
    if (preview == null) return;

    final coverage = preview['coverage_period'] as Map<String, dynamic>?;
    final fromDate = coverage?['from_date'] as String?;
    final toDate = coverage?['to_date'] as String?;
    final estimatedNet =
        (preview['estimated_net_payable'] as num?)?.toDouble() ?? 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirm Payout Request',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You are about to submit a payout request for:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: ColorStyles.grabGreen.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: ColorStyles.grabGreen.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                '₱ ${estimatedNet.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: ColorStyles.grabGreen,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'This action cannot be undone. Proceed?',
              style: TextStyle(fontSize: 12, color: ColorStyles.subSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ColorStyles.grabGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await ref
        .read(apiClientProvider)
        .post<Map<String, dynamic>>(
          '/payment-request',
          data: {'from_date': fromDate, 'to_date': toDate},
          parser: parseApiMap,
        );

    if (!mounted) return;

    if (result is ApiSuccess<Map<String, dynamic>>) {
      // Signal wallet to reload before navigating back.
      ref.read(walletRefreshProvider.notifier).state++;
      showAppSnackbar(
        context,
        'Payout request submitted.',
        type: SnackbarType.success,
      );
      context.go('/wallet');
    } else if (result is ApiValidationError<Map<String, dynamic>>) {
      final firstError = result.errors.values.isNotEmpty
          ? result.errors.values.first.first
          : null;
      setState(() => _error = firstError ?? result.message ?? 'Invalid input.');
    } else if (result is ApiConflict<Map<String, dynamic>>) {
      setState(
        () => _error = result.message.isNotEmpty
            ? result.message
            : 'You have already submitted a payout request today.',
      );
    } else if (result is ApiServerError<Map<String, dynamic>>) {
      setState(
        () => _error = result.message.isNotEmpty
            ? result.message
            : 'Failed to submit payout request.',
      );
    } else {
      showAppSnackbar(
        context,
        'Failed to submit payout request.',
        type: SnackbarType.error,
      );
    }

    if (mounted) setState(() => _submitting = false);
  }

  String _fmtShort(String dateStr) {
    try {
      return DateFormat('MMM d').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }

  /// Ensures each delivery map has a [delivery_status] field so [DeliveryCard]
  /// colours correctly. Deliveries listed in a payment request are always
  /// "delivered" unless the API says otherwise.
  List<Map<String, dynamic>> _normalisedBreakdown(
    List<Map<String, dynamic>> raw,
  ) {
    return raw.map((day) {
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

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark
        ? const Color(0xFF121212)
        : ColorStyles.grabCardLight;
    final appBarBg = isDark ? ColorStyles.grabCardDark : ColorStyles.white;

    if (!isOnline) {
      return Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          backgroundColor: appBarBg,
          elevation: 0,
          title: const Text(
            'REQUEST PAYOUT',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 52,
                color: ColorStyles.grabOrange,
              ),
              const SizedBox(height: 16),
              const Text(
                'You\'re Offline',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Payout requests require an internet\nconnection. Please reconnect and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: ColorStyles.secondary),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        title: const Text(
          'REQUEST PAYOUT',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ColorStyles.white,
                    ),
                  )
                : const Icon(Icons.send_rounded),
            label: const Text(
              'SUBMIT REQUEST',
              style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.8),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: ColorStyles.grabGreen,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: (_submitting || _loading || _previewData == null)
                ? null
                : _submit,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchPreview,
        color: ColorStyles.grabGreen,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _previewData == null
            ? _buildErrorState()
            : _buildContent(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: ColorStyles.red),
          const SizedBox(height: 12),
          Text(
            _error ?? 'Something went wrong.',
            style: TextStyle(fontSize: 14, color: ColorStyles.secondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _fetchPreview,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final preview = _previewData!;
    final eligibleCount = preview['eligible_delivery_count'] as int? ?? 0;
    final estimatedGross =
        (preview['estimated_gross_amount'] as num?)?.toDouble() ?? 0;
    final estimatedPenalties =
        (preview['estimated_total_penalties'] as num?)?.toDouble() ?? 0;
    final estimatedIncentive =
        (preview['estimated_coordinator_incentive'] as num?)?.toDouble() ?? 0;
    final estimatedNet =
        (preview['estimated_net_payable'] as num?)?.toDouble() ?? 0;
    final dailyBreakdown = _normalisedBreakdown(
      (preview['daily_breakdown'] as List?)?.cast<Map<String, dynamic>>() ?? [],
    );
    final coverage = preview['coverage_period'] as Map<String, dynamic>?;
    final fromDate = coverage?['from_date'] as String? ?? '';
    final toDate = coverage?['to_date'] as String? ?? '';

    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
      children: [
        // ── Summary Card ──────────────────────────────────────────────
        _SummaryCard(
          eligibleCount: eligibleCount,
          estimatedGross: estimatedGross,
          estimatedPenalties: estimatedPenalties,
          estimatedIncentive: estimatedIncentive,
          estimatedNet: estimatedNet,
          isDark: isDark,
        ),
        const SizedBox(height: 16),

        // ── Coverage Period ───────────────────────────────────────────
        if (toDate.isNotEmpty) ...[
          _CoveragePeriodBar(
            fromDate: fromDate,
            toDate: toDate,
            fmtShort: _fmtShort,
          ),
          const SizedBox(height: 20),
        ],

        // ── Date Strip + Deliveries ───────────────────────────────────
        if (dailyBreakdown.isNotEmpty) ...[
          Text(
            'DELIVERIES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: ColorStyles.secondary,
            ),
          ),
          const SizedBox(height: 8),
          DateStripWithDeliveries(
            key: ValueKey(_refreshKey),
            dailyBreakdown: dailyBreakdown,
            initialSelectedDate: _initialSelectedDate,
          ),
        ],

        // ── Error banner ──────────────────────────────────────────────
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ColorStyles.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ColorStyles.red.withValues(alpha: 0.3)),
            ),
            child: Text(
              _error!,
              style: TextStyle(
                color: ColorStyles.red,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],

        const SizedBox(height: 24),
      ],
    );
  }
}

// ─── Coverage Period Bar ──────────────────────────────────────────────────────

class _CoveragePeriodBar extends StatelessWidget {
  const _CoveragePeriodBar({
    required this.fromDate,
    required this.toDate,
    required this.fmtShort,
  });

  final String fromDate;
  final String toDate;
  final String Function(String) fmtShort;

  @override
  Widget build(BuildContext context) {
    // If from == to (single day), just say "Up to [date]"
    final isSingleDay = fromDate == toDate || fromDate.isEmpty;
    final label = isSingleDay
        ? 'Up to ${fmtShort(toDate)}'
        : '${fmtShort(fromDate)}  –  ${fmtShort(toDate)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ColorStyles.grabGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorStyles.grabGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.date_range_rounded,
            size: 18,
            color: ColorStyles.grabGreen,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'COVERAGE PERIOD',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: ColorStyles.grabGreen,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (!isSingleDay)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: ColorStyles.grabGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '7 DAYS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: ColorStyles.grabGreen,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Summary Card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.eligibleCount,
    required this.estimatedGross,
    required this.estimatedPenalties,
    required this.estimatedIncentive,
    required this.estimatedNet,
    required this.isDark,
  });

  final int eligibleCount;
  final double estimatedGross;
  final double estimatedPenalties;
  final double estimatedIncentive;
  final double estimatedNet;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1E1E2E) : ColorStyles.white;
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : ColorStyles.tertiary;
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: ColorStyles.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Icon(
                  Icons.local_shipping_rounded,
                  size: 16,
                  color: ColorStyles.subSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ELIGIBLE DELIVERIES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: ColorStyles.subSecondary,
                    ),
                  ),
                ),
                Text(
                  '$eligibleCount',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: ColorStyles.grabGreen,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: ColorStyles.grabGreen.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                if (estimatedGross != estimatedNet) ...[
                  _AmountRow(label: 'Gross Amount', amount: estimatedGross),
                  if (estimatedPenalties != 0)
                    _AmountRow(
                      label: 'Penalties',
                      amount: estimatedPenalties,
                      isDeduction: true,
                    ),
                  if (estimatedIncentive != 0)
                    _AmountRow(
                      label: 'Coordinator Incentive',
                      amount: estimatedIncentive,
                      isDeduction: true,
                    ),
                  const SizedBox(height: 6),
                  const Divider(height: 1),
                  const SizedBox(height: 6),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ESTIMATED NET PAYABLE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: isDark
                            ? ColorStyles.grabGreen
                            : ColorStyles.grabDarkGreen,
                      ),
                    ),
                    Text(
                      '₱ ${estimatedNet.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: ColorStyles.grabGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amount,
    this.isDeduction = false,
  });

  final String label;
  final double amount;
  final bool isDeduction;

  @override
  Widget build(BuildContext context) {
    final color = isDeduction ? ColorStyles.red : ColorStyles.secondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color)),
          Text(
            '${isDeduction ? '-' : ''}₱ ${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
