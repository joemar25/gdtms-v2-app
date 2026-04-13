// DOCS: docs/features/wallet.md — update that file when you edit this one.

// =============================================================================
// payout_request_screen.dart
// =============================================================================
//
// Purpose:
//   Lets the courier submit a payout request for their accumulated earnings.
//   The screen previews the deliveries that will be included in the payout,
//   the total amount, and the target account details before final submission.
//
// Key behaviours:
//   • Delivery date strip — a horizontal date selector showing which days'
//     delivered parcels are being grouped into the payout. Tapping a date
//     expands the list of deliveries for that day.
//   • Summary card — shows the total payout amount and fee breakdown.
//   • SUBMIT button — calls POST /payouts. Handles the following server
//     responses gracefully:
//       - ApiConflict    : a payout is already pending, shows a user-friendly
//                          message instead of an error.
//       - ApiServerError : surfaces the server message to the courier.
//       - ApiSuccess     : pops back to WalletScreen with a success notification.
//   • Requires connectivity — offline guard prevents submission and shows an
//     offline banner.
//
// Navigation:
//   Route: /wallet/payout-request
//   Pushed from: WalletScreen (REQUEST PAYOUT button)
//   Pops to: WalletScreen on success or cancel
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/config.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/widgets/date_strip_with_deliveries.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';

class PayoutRequestScreen extends ConsumerStatefulWidget {
  const PayoutRequestScreen({super.key, this.isConsolidation = false});

  final bool isConsolidation;

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

    final api = ref.read(apiClientProvider);
    final results = await Future.wait([
      api.get<Map<String, dynamic>>('/payment-request', parser: parseApiMap),
      api.get<Map<String, dynamic>>('/me/payment-method', parser: parseApiMap),
    ]);

    if (!mounted) return;

    final previewResult = results[0];

    if (previewResult is ApiSuccess<Map<String, dynamic>>) {
      final preview = mapFromKey(previewResult.data, 'data');
      setState(() {
        _previewData = preview;
        _initialSelectedDate = null;
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
    // ── Time-window guard (defense-in-depth) ────────────────────────────────
    // The WalletScreen already prevents navigation here outside the window, but
    // guard again in case the screen is reached via a deep-link or future route.
    if (!isWithinPayoutRequestWindow()) {
      setState(() {
        _error =
            'Payout requests are only allowed between '
            '${kPayoutWindowStartHour.toString().padLeft(2, '0')}:00 AM '
            'and 12:00 PM. Please try again during that window.';
      });
      return;
    }

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
        title: Text(
          widget.isConsolidation
              ? 'Confirm Consolidated Request'
              : 'Confirm Payout Request',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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
      ref.read(walletRefreshProvider.notifier).increment();
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

  /// Ensures each delivery map has a [delivery_status] field so [DeliveryCard]
  /// colours correctly. Deliveries listed in a payment request are always
  /// "delivered" unless the API says otherwise.
  List<Map<String, dynamic>> _normalisedBreakdown(
    List<Map<String, dynamic>> raw,
  ) {
    return raw.map((day) {
      final deliveries =
          (day['deliveries'] as List?)?.whereType<Map<String, dynamic>>().map((
            d,
          ) {
            final status = (d['delivery_status']?.toString() ?? 'DELIVERED')
                .toUpperCase();
            // In the context of a payout preview, RTS items are implicitly
            // verified with pay unless explicitly stated otherwise.
            final defaultRtsVerif = status == 'RTS'
                ? 'verified_with_pay'
                : 'unvalidated';

            return <String, dynamic>{
              ...d,
              'delivery_status': status,
              'barcode_value': d['barcode_value'] ?? d['barcode'],
              'sequence_number': d['sequence_number'] ?? d['sequence'],
              'product': d['product'] ?? d['mail_type'],
              'transaction_at':
                  d['transaction_at'] ??
                  d['delivered_date'] ??
                  d['payout_date'],
              'rts_verification_status':
                  d['rts_verification_status'] ??
                  d['verification_status'] ??
                  d['rts_verification'] ??
                  d['status_verification'] ??
                  defaultRtsVerif,
            };
          }).toList() ??
          [];
      return <String, dynamic>{...day, 'deliveries': deliveries};
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Use the canonical theme tokens so this screen matches every other screen.
    // Do NOT hardcode raw Color() values here — use ColorStyles constants.
    final scaffoldBg = isDark
        ? ColorStyles.scaffoldDark
        : ColorStyles.scaffoldLight;
    final appBarBg = isDark ? ColorStyles.appBarDark : ColorStyles.appBarLight;

    if (!isOnline) {
      return Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppHeaderBar(
          title: widget.isConsolidation
              ? 'Consolidate Request'
              : 'Request Payout',
          // pageIcon: Icons.payments_rounded,
          backgroundColor: appBarBg,
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
      appBar: AppHeaderBar(
        title: kAppDebugMode ? 'Request Payout (DEBUG)' : 'Request Payout',
        backgroundColor: appBarBg,
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
                : Icon(
                    isWithinPayoutRequestWindow()
                        ? Icons.payments_rounded
                        : Icons.lock_clock_rounded,
                  ),
            label: Text(
              widget.isConsolidation
                  ? 'SUBMIT CONSOLIDATED REQUEST'
                  : 'SUBMIT REQUEST',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: ColorStyles.grabGreen,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed:
                (_submitting ||
                    _loading ||
                    _previewData == null ||
                    (_previewData!['eligible_delivery_count'] as int? ?? 0) ==
                        0 ||
                    _previewData!['has_existing_request_today'] == true ||
                    !isWithinPayoutRequestWindow())
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
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
      children: [
        // ── Consolidation notice ──────────────────────────────────────
        if (widget.isConsolidation) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.merge_rounded,
                  color: Colors.amber.shade700,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    preview['has_existing_request_today'] == true
                        ? "You've already submitted a payout request today. Only one request per day is allowed. Your eligible deliveries will automatically be included in tomorrow's request if you submit again."
                        : 'You currently have a pending payout request. If you submit another request, all eligible deliveries will be combined into a single consolidated payout.',
                    style: TextStyle(
                      color: Colors.amber.shade700,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Summary Card ──────────────────────────────────────────────
        _SummaryCard(
          eligibleCount: eligibleCount,
          estimatedGross: estimatedGross,
          estimatedPenalties: estimatedPenalties,
          estimatedIncentive: estimatedIncentive,
          estimatedNet: estimatedNet,
          isDark: isDark,
          deliveriesLabel: widget.isConsolidation
              ? 'ELIGIBLE FOR CONSOLIDATION'
              : 'ELIGIBLE DELIVERIES',
        ),
        const SizedBox(height: 12),

        // // ── Coverage Period ───────────────────────────────────────────
        // if (toDate.isNotEmpty) ...[
        //   _CoveragePeriodBar(
        //     fromDate: fromDate,
        //     toDate: toDate,
        //     fmtShort: _fmtShort,
        //   ),
        //   const SizedBox(height: 20),
        // ],

        // ── Date Strip + Deliveries ───────────────────────────────────
        if (dailyBreakdown.isNotEmpty) ...[
          Text(
            widget.isConsolidation
                ? 'ELIGIBLE FOR CONSOLIDATION'
                : 'DELIVERIES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: ColorStyles.secondary,
            ),
          ),
          const SizedBox(height: 8),
          DateStripWithDeliveries(
            dailyBreakdown: dailyBreakdown,
            initialSelectedDate: _initialSelectedDate,
            enableHoldToReveal: false,
          ),
        ],

        // ── Submission limits banner (hidden in consolidation — banner above covers it) ──
        if (!widget.isConsolidation &&
            preview['has_existing_request_today'] == true) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Colors.amber.shade700,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'You have already submitted a request today.',
                    style: TextStyle(
                      color: Colors.amber.shade700,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else if (eligibleCount == 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.grey, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No eligible deliveries found for payout.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
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

// // ─── Coverage Period Bar ──────────────────────────────────────────────────────
// // mar-note: do not remove this, since this can be useful someday

// class _CoveragePeriodBar extends StatelessWidget {
//   const _CoveragePeriodBar({
//     required this.fromDate,
//     required this.toDate,
//     required this.fmtShort,
//   });

//   final String fromDate;
//   final String toDate;
//   final String Function(String) fmtShort;

//   @override
//   Widget build(BuildContext context) {
//     // If from == to (single day), just say "Up to [date]"
//     final isSingleDay = fromDate == toDate || fromDate.isEmpty;
//     final label = isSingleDay
//         ? 'Up to ${fmtShort(toDate)}'
//         : '${fmtShort(fromDate)}  –  ${fmtShort(toDate)}';

//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
//       decoration: BoxDecoration(
//         color: ColorStyles.grabGreen.withValues(alpha: 0.08),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: ColorStyles.grabGreen.withValues(alpha: 0.3)),
//       ),
//       child: Row(
//         children: [
//           Icon(
//             Icons.date_range_rounded,
//             size: 18,
//             color: ColorStyles.grabGreen,
//           ),
//           const SizedBox(width: 10),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'COVERAGE PERIOD',
//                   style: TextStyle(
//                     fontSize: 10,
//                     fontWeight: FontWeight.w700,
//                     letterSpacing: 1.0,
//                     color: ColorStyles.grabGreen,
//                   ),
//                 ),
//                 const SizedBox(height: 2),
//                 Text(
//                   label,
//                   style: const TextStyle(
//                     fontSize: 15,
//                     fontWeight: FontWeight.w800,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           if (!isSingleDay)
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//               decoration: BoxDecoration(
//                 color: ColorStyles.grabGreen.withValues(alpha: 0.15),
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               child: Text(
//                 '7 DAYS',
//                 style: TextStyle(
//                   fontSize: 10,
//                   fontWeight: FontWeight.w800,
//                   color: ColorStyles.grabGreen,
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }

// ─── Summary Card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.eligibleCount,
    required this.estimatedGross,
    required this.estimatedPenalties,
    required this.estimatedIncentive,
    required this.estimatedNet,
    required this.isDark,
    this.deliveriesLabel = 'ELIGIBLE DELIVERIES',
  });

  final int eligibleCount;
  final double estimatedGross;
  final double estimatedPenalties;
  final double estimatedIncentive;
  final double estimatedNet;
  final bool isDark;
  final String deliveriesLabel;

  @override
  Widget build(BuildContext context) {
    // Cards sit one layer above the scaffold — use grabCardDark / white.
    final cardBg = isDark ? ColorStyles.grabCardDark : ColorStyles.white;
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
                    deliveriesLabel,
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
                  // Coordinator incentive is an internal field — hidden from
                  // production couriers; visible only in debug builds.
                  if (kAppDebugMode && estimatedIncentive != 0)
                    _AmountRow(
                      label: '⚠ Coordinator Incentive',
                      amount: estimatedIncentive,
                      isDeduction: true,
                      isDebug: true,
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
    this.isDebug = false,
  });

  final String label;
  final double amount;
  final bool isDeduction;
  final bool isDebug;

  @override
  Widget build(BuildContext context) {
    final color = isDebug
        ? Colors.red.shade700
        : (isDeduction ? ColorStyles.red : ColorStyles.secondary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: isDebug ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
              if (isDebug)
                Text(
                  'DEBUG ONLY — not visible in production',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.red.shade400,
                    letterSpacing: 0.3,
                  ),
                ),
            ],
          ),
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
