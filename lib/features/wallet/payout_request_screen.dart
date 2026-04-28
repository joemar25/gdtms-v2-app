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
import 'package:fsi_courier_app/design_system/design_system.dart';

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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: DSStyles.cardRadius),
        title: Text(
          widget.isConsolidation
              ? 'Confirm Consolidated Request'
              : 'Confirm Payout Request',
          style: DSTypography.heading().copyWith(
            fontSize: DSTypography.sizeMd,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to submit a payout request for:',
              style: DSTypography.body().copyWith(
                fontSize: DSTypography.sizeMd,
              ),
            ),
            DSSpacing.hMd,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: DSSpacing.base,
                vertical: DSSpacing.md,
              ),
              decoration: BoxDecoration(
                color: DSColors.primary.withValues(alpha: DSStyles.alphaSoft),
                borderRadius: DSStyles.cardRadius,
                border: Border.all(
                  color: DSColors.primary.withValues(
                    alpha: DSStyles.alphaDarkShadow,
                  ),
                ),
              ),
              child: Text(
                '₱ ${estimatedNet.toStringAsFixed(2)}',
                style: DSTypography.display(color: DSColors.primary).copyWith(
                  fontSize: DSTypography.sizeXl,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            DSSpacing.hSm,
            Text(
              'This action cannot be undone. Proceed?',
              style: DSTypography.caption(
                color: isDark
                    ? DSColors.labelSecondaryDark
                    : DSColors.labelSecondary,
              ).copyWith(fontSize: DSTypography.sizeSm),
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
              backgroundColor: DSColors.primary,
              shape: RoundedRectangleBorder(borderRadius: DSStyles.cardRadius),
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
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/wallet');
      }
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
            // In the context of a payout preview, FAILED_DELIVERY items are implicitly
            // verified with pay unless explicitly stated otherwise.
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
                  d['transaction_at'] ??
                  d['delivered_date'] ??
                  d['payout_date'],
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
      return <String, dynamic>{...day, 'deliveries': deliveries};
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Use the canonical theme tokens so this screen matches every other screen.
    // Do NOT hardcode raw Color() values here — use ColorStyles constants.
    final scaffoldBg = isDark ? DSColors.scaffoldDark : DSColors.scaffoldLight;
    final appBarBg = isDark ? DSColors.cardDark : DSColors.cardLight;

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
              Icon(Icons.wifi_off_rounded, size: 52, color: DSColors.error),
              DSSpacing.hBase,
              Text(
                'You\'re Offline',
                style: DSTypography.heading().copyWith(
                  fontSize: DSTypography.sizeMd,
                  fontWeight: FontWeight.w800,
                ),
              ),
              DSSpacing.hSm,
              Text(
                'Payout requests require an internet\nconnection. Please reconnect and try again.',
                textAlign: TextAlign.center,
                style: DSTypography.caption(
                  color: DSColors.accent,
                ).copyWith(fontSize: DSTypography.sizeMd),
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
          padding: const EdgeInsets.fromLTRB(
            DSSpacing.base,
            DSSpacing.sm,
            DSSpacing.base,
            DSSpacing.md,
          ),
          child: FilledButton.icon(
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: DSColors.white,
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
              style: DSTypography.label().copyWith(fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: DSColors.primary,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: DSStyles.cardRadius),
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
        color: DSColors.primary,
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
          Icon(Icons.error_outline_rounded, size: 48, color: DSColors.error),
          const SizedBox(height: 12),
          Text(
            _error ?? 'Something went wrong.',
            style: DSTypography.caption(
              color: DSColors.accent,
            ).copyWith(fontSize: DSTypography.sizeMd),
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
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: DSSpacing.md,
            ),
            decoration: BoxDecoration(
              color: DSColors.warning.withValues(alpha: DSStyles.alphaSoft),
              borderRadius: DSStyles.cardRadius,
              border: Border.all(
                color: DSColors.warning.withValues(
                  alpha: DSStyles.alphaDarkShadow,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.merge_rounded, color: DSColors.warning, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    preview['has_existing_request_today'] == true
                        ? "You've already submitted a payout request today. Only one request per day is allowed. Your eligible deliveries will automatically be included in tomorrow's request if you submit again."
                        : 'You currently have a pending payout request. If you submit another request, all eligible deliveries will be combined into a single consolidated payout.',
                    style: DSTypography.caption(color: DSColors.warning)
                        .copyWith(
                          fontSize: DSTypography.sizeMd,
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
            style: DSTypography.label(color: DSColors.accent).copyWith(
              fontSize: DSTypography.sizeSm,
              fontWeight: FontWeight.w800,
              letterSpacing: DSTypography.lsMegaLoose,
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
            padding: const EdgeInsets.all(DSSpacing.md),
            decoration: BoxDecoration(
              color: DSColors.warning.withValues(alpha: DSStyles.alphaSoft),
              borderRadius: DSStyles.cardRadius,
              border: Border.all(
                color: DSColors.warning.withValues(
                  alpha: DSStyles.alphaDarkShadow,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: DSColors.warning,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'You have already submitted a request today.',
                    style: DSTypography.caption(color: DSColors.warning)
                        .copyWith(
                          fontSize: DSTypography.sizeMd,
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
            padding: const EdgeInsets.all(DSSpacing.md),
            decoration: BoxDecoration(
              color:
                  (isDark ? DSColors.labelTertiaryDark : DSColors.labelTertiary)
                      .withValues(alpha: DSStyles.alphaSoft),
              borderRadius: DSStyles.cardRadius,
              border: Border.all(
                color:
                    (isDark
                            ? DSColors.labelTertiaryDark
                            : DSColors.labelTertiary)
                        .withValues(alpha: DSStyles.alphaDarkShadow),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: DSColors.accent,
                  size: 18,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No eligible deliveries found for payout.',
                    style: DSTypography.caption(color: DSColors.accent)
                        .copyWith(
                          fontSize: DSTypography.sizeMd,
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
            padding: const EdgeInsets.all(DSSpacing.md),
            decoration: BoxDecoration(
              color: DSColors.error.withValues(alpha: DSStyles.alphaSoft),
              borderRadius: DSStyles.cardRadius,
              border: Border.all(
                color: DSColors.error.withValues(
                  alpha: DSStyles.alphaDarkShadow,
                ),
              ),
            ),
            child: Text(
              _error!,
              style: DSTypography.body(color: DSColors.error).copyWith(
                fontSize: DSTypography.sizeMd,
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
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: DSSpacing.md),
//       decoration: BoxDecoration(
//         color: DSColors.primary.withValues(alpha: DSStyles.alphaSoft),
//         borderRadius: DSStyles.cardRadius,
//         border: Border.all(color: DSColors.primary.withValues(alpha: DSStyles.alphaDarkShadow)),
//       ),
//       child: Row(
//         children: [
//           Icon(
//             Icons.date_range_rounded,
//             size: 18,
//             color: DSColors.primary,
//           ),
//           const SizedBox(width: 10),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'COVERAGE PERIOD',
//                   style: TextStyle(
//                     fontSize: DSTypography.sizeXs,
//                     fontWeight: FontWeight.w700,
//                     letterSpacing: 1.0,
//                     color: DSColors.primary,
//                   ),
//                 ),
//                 const SizedBox(height: 2),
//                 Text(
//                   label,
//                   style: const TextStyle(
//                     fontSize: DSTypography.sizeMd,
//                     fontWeight: FontWeight.w800,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           if (!isSingleDay)
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: DSSpacing.md, vertical: DSSpacing.xs),
//               decoration: BoxDecoration(
//                 color: DSColors.primary.withValues(alpha: DSStyles.alphaActiveAccent),
//                 borderRadius: DSStyles.cardRadius,
//               ),
//               child: Text(
//                 '7 DAYS',
//                 style: TextStyle(
//                   fontSize: DSTypography.sizeXs,
//                   fontWeight: FontWeight.w800,
//                   color: DSColors.primary,
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
    final cardBg = isDark ? DSColors.cardDark : DSColors.white;
    final cardBorder = isDark
        ? DSColors.white.withValues(alpha: DSStyles.alphaSoft)
        : DSColors.separatorLight;
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: DSStyles.cardRadius,
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: DSColors.black.withValues(alpha: isDark ? 0.25 : 0.04),
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
                  color: isDark
                      ? DSColors.labelSecondaryDark
                      : DSColors.labelSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    deliveriesLabel,
                    style:
                        DSTypography.caption(
                          color: isDark
                              ? DSColors.labelSecondaryDark
                              : DSColors.labelSecondary,
                        ).copyWith(
                          fontSize: DSTypography.sizeSm,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Text(
                  '$eligibleCount',
                  style: DSTypography.label(color: DSColors.primary).copyWith(
                    fontSize: DSTypography.sizeMd,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DSSpacing.base,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: DSColors.primary.withValues(alpha: DSStyles.alphaSoft),
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
                      style: DSTypography.label(
                        color: DSColors.primary,
                      ).copyWith(fontSize: DSTypography.sizeSm),
                    ),
                    Text(
                      '₱ ${estimatedNet.toStringAsFixed(2)}',
                      style: DSTypography.heading(color: DSColors.primary)
                          .copyWith(
                            fontSize: DSTypography.sizeLg,
                            fontWeight: FontWeight.w800,
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
        ? DSColors.errorText
        : (isDeduction ? DSColors.error : DSColors.accent);
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
                style: DSTypography.caption(color: color).copyWith(
                  fontSize: DSTypography.sizeSm,
                  fontWeight: isDebug ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
              if (isDebug)
                Text(
                  'DEBUG ONLY — not visible in production',
                  style: DSTypography.caption(
                    color: DSColors.error.withValues(alpha: 0.7),
                  ).copyWith(fontSize: 9, letterSpacing: 0.3),
                ),
            ],
          ),
          Text(
            '${isDeduction ? '-' : ''}₱ ${amount.abs().toStringAsFixed(2)}',
            style: DSTypography.label(color: color).copyWith(
              fontSize: DSTypography.sizeSm,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
