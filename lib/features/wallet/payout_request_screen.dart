// DOCS: docs/development-standards.md
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
import 'package:easy_localization/easy_localization.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/config.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/utils/formatters.dart';
import 'package:fsi_courier_app/features/wallet/widgets/payout_summary_card.dart';
import 'package:fsi_courier_app/features/wallet/widgets/deliveries_rundown_card.dart';

/// Screen for requesting a payout of accumulated earnings.
///
/// This screen allows couriers to review their eligible deliveries, see
/// estimated gross/net amounts, and submit a formal payment request.
/// It enforces the payout window time constraints and handles server
/// validation and conflict states.
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
        _loading = false;
      });
    } else {
      setState(() {
        _error = 'wallet.request.error_loading_preview'.tr();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<bool?> _showConfirmDialog(double estimatedNet) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: DSStyles.cardRadius),
        title: Text(
          widget.isConsolidation
              ? 'wallet.request.confirm_title_consolidated'.tr()
              : 'wallet.request.confirm_title'.tr(),
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
              'wallet.request.confirm_body'.tr(),
              style: DSTypography.body().copyWith(
                fontSize: DSTypography.sizeMd,
              ),
            ),
            DSSpacing.hMd,
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(DSSpacing.md),
              decoration: BoxDecoration(
                color: DSColors.primary.withValues(alpha: DSStyles.alphaSoft),
                borderRadius: DSStyles.cardRadius,
                border: Border.all(
                  color: DSColors.primary.withValues(
                    alpha: DSStyles.alphaMuted,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    AppFormatters.currency(estimatedNet),
                    style: DSTypography.display(color: DSColors.primary)
                        .copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: DSTypography.sizeHero,
                          letterSpacing: DSTypography.lsTight,
                        ),
                  ),
                ],
              ),
            ),
            DSSpacing.hSm,
            Text(
              'wallet.request.confirm_warning'.tr(),
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
            child: Text('wallet.request.confirm_cancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: DSColors.primary,
              shape: RoundedRectangleBorder(borderRadius: DSStyles.cardRadius),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('wallet.request.confirm_submit'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!isWithinPayoutRequestWindow()) {
      final fromLabel = kPayoutWindowStartHour == 0
          ? '12:00 AM'
          : '${kPayoutWindowStartHour.toString().padLeft(2, '0')}:00 AM';
      final toLabel = kPayoutWindowEndHour == 12
          ? '12:00 PM'
          : '${kPayoutWindowEndHour.toString().padLeft(2, '0')}:00';
      setState(() {
        _error = 'wallet.request.request_window_denied'.tr(
          namedArgs: {'from': fromLabel, 'to': toLabel},
        );
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

    final confirmed = await _showConfirmDialog(estimatedNet);
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
      ref.read(walletRefreshProvider.notifier).increment();
      showAppSnackbar(
        context,
        'wallet.request.submitted_success'.tr(),
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
      setState(
        () => _error = firstError ?? result.message ?? 'errors.not_found'.tr(),
      );
    } else if (result is ApiConflict<Map<String, dynamic>>) {
      setState(
        () => _error = result.message.isNotEmpty
            ? result.message
            : 'wallet.request.already_submitted_today'.tr(),
      );
    } else if (result is ApiServerError<Map<String, dynamic>>) {
      setState(
        () => _error = result.message.isNotEmpty
            ? result.message
            : 'wallet.request.failed_submit'.tr(),
      );
    } else {
      showAppSnackbar(
        context,
        'wallet.request.failed_submit'.tr(),
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
    }).toList()..sort((a, b) {
      final dateA = DateTime.tryParse('${a['date'] ?? ''}') ?? DateTime(0);
      final dateB = DateTime.tryParse('${b['date'] ?? ''}') ?? DateTime(0);
      return dateB.compareTo(dateA);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Standard scaffolding following FSI Design System rules.
    final scaffoldBg = isDark ? DSColors.scaffoldDark : DSColors.scaffoldLight;
    final appBarBg = isDark ? DSColors.cardDark : DSColors.cardLight;

    if (!isOnline) {
      return SecureView(
        child: Scaffold(
          backgroundColor: scaffoldBg,
          appBar: AppHeaderBar(
            title: widget.isConsolidation
                ? 'wallet.request.appbar_title_consolidate'.tr()
                : 'wallet.request.appbar_title'.tr(),
            backgroundColor: appBarBg,
          ),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  size: DSIconSize.xl,
                  color: DSColors.error,
                ),
                DSSpacing.hMd,
                Text(
                  'wallet.request.offline_title'.tr(),
                  style: DSTypography.heading().copyWith(
                    fontSize: DSTypography.sizeMd,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                DSSpacing.hSm,
                Text(
                  'wallet.request.offline_body'.tr(),
                  textAlign: TextAlign.center,
                  style: DSTypography.caption(
                    color: DSColors.accent,
                  ).copyWith(fontSize: DSTypography.sizeMd),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SecureView(
      child: Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppHeaderBar(
          title: kAppDebugMode
              ? 'wallet.request.appbar_title_debug'.tr()
              : 'wallet.request.appbar_title'.tr(),
          backgroundColor: appBarBg,
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              DSSpacing.md,
              DSSpacing.sm,
              DSSpacing.md,
              DSSpacing.md,
            ),
            child: FilledButton.icon(
              icon: _submitting
                  ? const SizedBox(
                      width: DSIconSize.lg,
                      height: DSIconSize.lg,
                      child: CircularProgressIndicator(
                        strokeWidth: DSStyles.strokeWidth,
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
                    ? 'wallet.request.confirm_button_consolidate'.tr()
                    : 'wallet.request.confirm_button'.tr(),
                style: DSTypography.label().copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: DSColors.primary,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: DSStyles.cardRadius,
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
          color: DSColors.primary,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _previewData == null
              ? _buildErrorState()
              : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: DSIconSize.xl,
            color: DSColors.error,
          ),
          DSSpacing.hMd,
          Text(
            _error ?? 'common.error'.tr(),
            style: DSTypography.caption(
              color: DSColors.accent,
            ).copyWith(fontSize: DSTypography.sizeMd),
            textAlign: TextAlign.center,
          ),
          DSSpacing.hMd,
          TextButton.icon(
            onPressed: _fetchPreview,
            icon: const Icon(Icons.refresh_rounded),
            label: Text('wallet.request.try_again'.tr()),
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
      padding:
          EdgeInsets.all(DSSpacing.md) + EdgeInsets.only(bottom: bottomPadding),
      children: [
        if (widget.isConsolidation) ...[
          Container(
            padding: const EdgeInsets.all(DSSpacing.md),
            decoration: BoxDecoration(
              color: DSColors.warning.withValues(alpha: DSStyles.alphaSoft),
              borderRadius: DSStyles.cardRadius,
              border: Border.all(
                color: DSColors.warning.withValues(alpha: DSStyles.alphaMuted),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.merge_rounded,
                  color: DSColors.warning,
                  size: DSIconSize.md,
                ),
                DSSpacing.wMd,
                Expanded(
                  child: Text(
                    preview['has_existing_request_today'] == true
                        ? 'wallet.request.existing_request_details'.tr()
                        : 'wallet.request.pending_request_warning'.tr(),
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
          DSSpacing.hMd,
        ],

        PayoutSummaryCard(
          eligibleCount: eligibleCount,
          estimatedGross: estimatedGross,
          estimatedPenalties: estimatedPenalties,
          estimatedIncentive: estimatedIncentive,
          estimatedNet: estimatedNet,
          deliveriesLabel: 'wallet.card.eligible_deliveries',
        ).dsCardEntry(
          delay: DSAnimations.stagger(0, step: DSAnimations.staggerNormal),
        ),
        DSSpacing.hMd,

        if (dailyBreakdown.isNotEmpty) ...[
          DSSectionHeader(
            title: 'wallet.detail.deliveries_rundown'.tr(),
            padding: EdgeInsets.zero,
          ).dsFadeEntry(
            delay: DSAnimations.stagger(1, step: DSAnimations.staggerNormal),
          ),
          DSSpacing.hSm,
          DeliveriesRundownCard(dailyBreakdown: dailyBreakdown).dsFadeEntry(
            delay: DSAnimations.stagger(2, step: DSAnimations.staggerNormal),
          ),
        ],

        if (!widget.isConsolidation &&
            preview['has_existing_request_today'] == true) ...[
          DSSpacing.hMd,
          Container(
            padding: EdgeInsets.all(DSSpacing.md),
            decoration: BoxDecoration(
              color: DSColors.warning.withValues(alpha: DSStyles.alphaSoft),
              borderRadius: DSStyles.cardRadius,
              border: Border.all(
                color: DSColors.warning.withValues(alpha: DSStyles.alphaMuted),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: DSColors.warning,
                  size: DSIconSize.md,
                ),
                DSSpacing.wMd,
                Expanded(
                  child: Text(
                    'wallet.request.existing_request_today_notice'.tr(),
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
          DSSpacing.hMd,
          Container(
            padding: EdgeInsets.all(DSSpacing.md),
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
                        .withValues(alpha: DSStyles.alphaMuted),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: DSColors.accent,
                  size: DSIconSize.md,
                ),
                DSSpacing.wMd,
                Expanded(
                  child: Text(
                    'wallet.request.no_eligible_deliveries'.tr(),
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

        if (_error != null) ...[
          DSSpacing.hMd,
          Container(
            padding: EdgeInsets.all(DSSpacing.md),
            decoration: BoxDecoration(
              color: DSColors.error.withValues(alpha: DSStyles.alphaSoft),
              borderRadius: DSStyles.cardRadius,
              border: Border.all(
                color: DSColors.error.withValues(alpha: DSStyles.alphaMuted),
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

        DSSpacing.hXl,
      ],
    );
  }
}
