// DOCS: docs/development-standards.md
// DOCS: docs/features/dispatch.md — update that file when you edit this one.

// =============================================================================
// dispatch_eligibility_screen.dart
// =============================================================================
//
// Purpose:
//   Gate screen that the courier passes through before starting a dispatch run.
//   It fetches the courier's eligibility status from the server and either
//   allows them to proceed to the dispatch list or shows a blocking reason
//   (e.g. unsynced deliveries, account suspension, incomplete profile).
//
// Flow:
//   1. Screen mounts → calls GET /dispatch/eligibility.
//   2. If eligible → shows a "START DISPATCH" button that navigates to
//      DispatchListScreen.
//   3. If ineligible → displays the server-provided reason and blocks access.
//   4. Device info (free storage, OS version) is attached to the eligibility
//      request so the server can enforce minimum-spec requirements.
//
// Navigation:
//   Route: /dispatch/eligibility
//   Pushed from: DashboardScreen DISPATCH card
//   Pushes to: DispatchListScreen on success
// =============================================================================

import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/device/device_info.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/widgets/delivery_card.dart';
import 'package:fsi_courier_app/shared/widgets/loading_overlay.dart';
import 'package:fsi_courier_app/shared/widgets/pagination_bar.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/features/dispatch/widgets/dispatch_info_card.dart';
import 'package:fsi_courier_app/features/dispatch/widgets/pin_confirm_dialog.dart';

class DispatchEligibilityScreen extends ConsumerStatefulWidget {
  const DispatchEligibilityScreen({
    super.key,
    required this.dispatchCode,
    required this.eligibilityResponse,
    required this.autoAccept,
    this.skipPinDialog = false,
    this.showFullCode = false,
  });

  final String dispatchCode;
  final Map<String, dynamic> eligibilityResponse;
  final bool autoAccept;
  final bool skipPinDialog;
  final bool showFullCode;

  @override
  ConsumerState<DispatchEligibilityScreen> createState() =>
      _DispatchEligibilityScreenState();
}

class _DispatchEligibilityScreenState
    extends ConsumerState<DispatchEligibilityScreen> {
  static const String _otherRejectReason = 'OTHERS (SPECIFY)';
  static const List<String> _rejectReasons = [
    'RECIPIENT NOT AVAILABLE',
    'INVALID / INCOMPLETE ADDRESS',
    'DAMAGED DOCUMENTS',
    'DUPLICATE DISPATCH',
    'OUTSIDE ASSIGNED AREA',
    'SAFETY CONCERN',
    _otherRejectReason,
  ];

  bool _loading = false;
  String? _error;

  // Reject form state
  final _rejectReasonController = TextEditingController();
  bool _showRejectForm = false;
  String? _selectedRejectReason;
  String? _rejectRemarks;
  int _currentPage = 0;
  final int _pageSize = 10;

  String get _resolvedDispatchCode => widget.dispatchCode.trim();

  /// Get eligibility response from widget (data fetched before navigation)
  Map<String, dynamic> get _eligibilityResponse => widget.eligibilityResponse;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _rejectReasonController.dispose();
    super.dispose();
  }

  String _getMaskedLast4(String code) {
    if (code.length <= 4) return code;
    return code.substring(code.length - 4);
  }

  Future<bool> _showPinDialog() async {
    final actual = _getMaskedLast4(_resolvedDispatchCode);
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => PinConfirmDialog(expectedPin: actual),
        ) ??
        false;
  }

  Future<bool> _handleBack() async {
    if (GoRouter.of(context).canPop()) {
      context.pop();
      return false;
    }
    context.go('/dashboard');
    return false;
  }

  Future<void> _handleAccept() async {
    if (!widget.skipPinDialog) {
      final confirmed = await _showPinDialog();
      if (!confirmed) return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    const uuid = Uuid();
    final acceptId = uuid.v4();
    final device = ref.read(deviceInfoProvider);

    final result = await ref
        .read(apiClientProvider)
        .post<Map<String, dynamic>>(
          '/accept-dispatch',
          data: {
            'dispatch_code': _resolvedDispatchCode,
            'client_request_id': acceptId,
            'device_info': await device.toMap(),
          },
          parser: parseApiMap,
        );

    if (!mounted) return;

    final alreadyAccepted =
        result is ApiConflict<Map<String, dynamic>> ||
        (result is ApiServerError<Map<String, dynamic>> &&
            result.message.toLowerCase().contains('already accepted'));

    if (result is ApiSuccess<Map<String, dynamic>>) {
      final rawDeliveries = _eligibilityResponse['deliveries'];
      if (rawDeliveries is List) {
        final deliveries = rawDeliveries
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (deliveries.isNotEmpty) {
          final tat = _eligibilityResponse['tat']?.toString();
          final transmittalDate = _eligibilityResponse['transmittal_date']
              ?.toString();

          await LocalDeliveryDao.instance.insertAll(
            deliveries,
            dispatchCode: _resolvedDispatchCode,
            tat: tat,
            transmittalDate: transmittalDate,
          );
        }
      }
      ref.read(deliveryRefreshProvider.notifier).increment();
      setState(() {
        _loading = false;
      });
      return;
    }

    if (alreadyAccepted) {
      setState(() => _loading = false);
      showAppSnackbar(
        context,
        'Dispatch already accepted. Opening deliveries.',
        type: SnackbarType.info,
      );
      context.go('/deliveries');
      return;
    }

    setState(() {
      _loading = false;
      _error = switch (result) {
        ApiBadRequest(:final message) => message,
        ApiConflict(:final message) => message,
        ApiServerError(:final message) => message,
        ApiValidationError(:final message) =>
          (message != null && message.isNotEmpty)
              ? message
              : 'Unable to accept dispatch.',
        ApiNetworkError(:final message) => message,
        ApiRateLimited(:final message) => message,
        _ => 'Unable to accept dispatch.',
      };
    });
  }

  Future<void> _submitReject() async {
    String reason;

    if (_selectedRejectReason == null) {
      return;
    }

    if (_selectedRejectReason == _otherRejectReason) {
      reason = _rejectReasonController.text.trim();
      if (reason.isEmpty) {
        return;
      }
    } else {
      reason = _selectedRejectReason!;
    }

    final confirmed = await _showRejectConfirmationDialog(reason);
    if (!confirmed) return;

    setState(() {
      _loading = true;
    });

    const uuid = Uuid();
    final requestId = uuid.v4();
    final device = ref.read(deviceInfoProvider);

    final result = await ref
        .read(apiClientProvider)
        .post<Map<String, dynamic>>(
          '/reject-dispatch',
          data: {
            'dispatch_code': _resolvedDispatchCode,
            'client_request_id': requestId,
            'reason': reason,
            'remarks': _rejectRemarks,
            'device_info': await device.toMap(),
          },
          parser: parseApiMap,
        );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result is ApiSuccess<Map<String, dynamic>>) {
      showSuccessNotification(context, 'Dispatch rejected.');
      context.go('/dashboard');
    } else {
      final errorMessage = switch (result) {
        ApiBadRequest(:final message) => message,
        ApiValidationError(:final message) => message ?? 'Validation error',
        ApiNetworkError(:final message) => message,
        ApiRateLimited(:final message) => message,
        ApiConflict(:final message) => message,
        ApiServerError(:final message) => message,
        _ => 'Failed to reject dispatch. Please try again.',
      };
      showErrorNotification(context, errorMessage);
    }
  }

  Future<bool> _showRejectConfirmationDialog(String reason) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: DSStyles.cardRadius),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: DSColors.error),
                DSSpacing.wSm,
                Expanded(
                  child: Text(
                    'Confirm Rejection',
                    style: DSTypography.heading().copyWith(
                      fontSize: DSTypography.sizeMd,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This action cannot be undone. Please confirm before submitting.',
                  style: DSTypography.body().copyWith(
                    fontSize: DSTypography.sizeMd,
                  ),
                ),
                DSSpacing.hSm,
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(DSSpacing.md),
                  decoration: BoxDecoration(
                    color: DSColors.labelSecondary.withValues(
                      alpha: DSStyles.alphaSoft,
                    ),
                    borderRadius: DSStyles.cardRadius,
                  ),
                  child: Text(
                    reason,
                    style: DSTypography.body().copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('CANCEL'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: DSColors.error),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('CONFIRM SUBMIT'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final eligible = _eligibilityResponse['eligible'] == true;
    final info = _eligibilityResponse;
    final reason =
        _eligibilityResponse['message']?.toString() ??
        'You are not eligible for this dispatch.';
    final dispatchCode = _resolvedDispatchCode;
    final last4 = _getMaskedLast4(dispatchCode);
    final maskedCode = widget.showFullCode
        ? dispatchCode
        : dispatchCode.length > last4.length
        ? '${dispatchCode.substring(0, dispatchCode.length - last4.length)}****'
        : '****';

    final deliveries = info['deliveries'] is List
        ? (info['deliveries'] as List).whereType<Map>().map((e) {
            final d = Map<String, dynamic>.from(e);
            d['delivery_status'] = '';
            return d;
          }).toList()
        : <Map<String, dynamic>>[];

    final totalPages = (deliveries.length / _pageSize).ceil();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: GoRouter.of(context).canPop(),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        appBar: AppHeaderBar(
          leading: BackButton(onPressed: () => _handleBack()),
          title: 'DISPATCH DETAILS',
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded),
              tooltip: 'Scan Dispatch',
              onPressed: () =>
                  context.push('/scan', extra: {'mode': 'dispatch'}),
            ),
          ],
        ),
        body: LoadingOverlay(
          isLoading: _loading,
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(DSSpacing.md),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      Center(
                        child: Icon(
                          Icons.error_rounded,
                          color: DSColors.warning,
                          size: 64,
                        ),
                      ).dsHeroEntry(),
                      DSSpacing.hMd,
                      Text(
                        'ERROR',
                        textAlign: TextAlign.center,
                        style: DSTypography.heading().copyWith(
                          color: DSColors.warning,
                          fontWeight: FontWeight.w800,
                        ),
                      ).dsFadeEntry(delay: DSAnimations.stagger(1)),
                      DSSpacing.hSm,
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: DSTypography.body(),
                      ).dsFadeEntry(delay: DSAnimations.stagger(2)),
                      DSSpacing.hXl,
                      FilledButton(
                        onPressed: _handleAccept,
                        child: const Text('RETRY'),
                      ).dsCtaEntry(delay: DSAnimations.stagger(3)),
                    ] else if (!eligible) ...[
                      Center(
                        child: Icon(
                          Icons.cancel_rounded,
                          color: DSColors.error,
                          size: DSIconSize.xl,
                        ),
                      ).dsHeroEntry(),
                      DSSpacing.hMd,
                      Text(
                        'NOT ELIGIBLE',
                        textAlign: TextAlign.center,
                        style: DSTypography.heading().copyWith(
                          color: DSColors.error,
                          fontWeight: FontWeight.w800,
                        ),
                      ).dsFadeEntry(delay: DSAnimations.stagger(1)),
                      DSSpacing.hSm,
                      Text(
                        reason,
                        textAlign: TextAlign.center,
                        style: DSTypography.body(),
                      ).dsFadeEntry(delay: DSAnimations.stagger(2)),
                      DSSpacing.hXl,
                      OutlinedButton(
                        onPressed: _handleBack,
                        child: const Text('BACK'),
                      ).dsCtaEntry(delay: DSAnimations.stagger(3)),
                    ] else if (_showRejectForm) ...[
                      DSSectionHeader(
                        title: 'REJECT DISPATCH',
                        padding: EdgeInsets.zero,
                      ).dsFadeEntry(),
                      DSSpacing.hSm,
                      DSCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DSHeroCard(
                              accentColor: DSColors.error,
                              padding: EdgeInsets.all(DSSpacing.md),
                              child: Row(
                                children: [
                                  Container(
                                    width: DSIconSize.heroSm,
                                    height: DSIconSize.heroSm,
                                    decoration: BoxDecoration(
                                      color: DSColors.white.withValues(
                                        alpha: DSStyles.alphaSubtle,
                                      ),
                                      borderRadius: DSStyles.pillRadius,
                                    ),
                                    child: const Icon(
                                      Icons.gpp_maybe_outlined,
                                      color: DSColors.white,
                                      size: DSIconSize.md,
                                    ),
                                  ),
                                  DSSpacing.wMd,
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'DISPATCH CODE',
                                          style:
                                              DSTypography.caption(
                                                color: DSColors.white
                                                    .withValues(
                                                      alpha: DSStyles
                                                          .alphaDisabled,
                                                    ),
                                              ).copyWith(
                                                fontWeight: FontWeight.w700,
                                                fontSize: DSTypography.sizeXs,
                                                letterSpacing:
                                                    DSTypography.lsLoose,
                                              ),
                                        ),
                                        Text(
                                          maskedCode,
                                          style: DSTypography.heading()
                                              .copyWith(
                                                fontWeight: FontWeight.w800,
                                                fontSize: DSTypography.sizeMd,
                                                color: DSColors.white,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(DSSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Please select the reason for rejecting this dispatch. This action is final and cannot be undone.',
                                    style: DSTypography.caption().copyWith(
                                      fontSize: DSTypography.sizeSm,
                                      color: isDark
                                          ? DSColors.labelSecondaryDark
                                          : DSColors.labelSecondary,
                                      height: DSStyles.heightNormal,
                                    ),
                                  ),
                                  DSSpacing.hLg,
                                  DropdownButtonFormField<String>(
                                    initialValue: _selectedRejectReason,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: 'REJECTION REASON *',
                                      prefixIcon: const Icon(
                                        Icons.help_outline_rounded,
                                      ),
                                    ),
                                    items: _rejectReasons.map((r) {
                                      return DropdownMenuItem(
                                        value: r,
                                        child: Text(
                                          r,
                                          style: DSTypography.body().copyWith(
                                            fontSize: DSTypography.sizeSm,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (v) => setState(
                                      () => _selectedRejectReason = v,
                                    ),
                                  ),
                                  if (_selectedRejectReason ==
                                      _otherRejectReason) ...[
                                    DSSpacing.hMd,
                                    TextField(
                                      controller: _rejectReasonController,
                                      maxLength: 100,
                                      maxLines: 2,
                                      decoration: const InputDecoration(
                                        labelText: 'SPECIFY REASON *',
                                        alignLabelWithHint: true,
                                      ),
                                    ),
                                  ],
                                  DSSpacing.hMd,
                                  TextField(
                                    onChanged: (v) => _rejectRemarks = v,
                                    maxLines: 3,
                                    decoration: const InputDecoration(
                                      labelText: 'REMARKS',
                                      hintText: 'Optional notes...',
                                      alignLabelWithHint: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ).dsCardEntry(delay: DSAnimations.stagger(1)),
                      DSSpacing.hXl,
                      FilledButton(
                        onPressed: _selectedRejectReason == null
                            ? null
                            : _submitReject,
                        style: FilledButton.styleFrom(
                          backgroundColor: DSColors.error,
                          minimumSize: const Size(double.infinity, 52),
                        ),
                        child: const Text('REJECT DISPATCH'),
                      ).dsCtaEntry(delay: DSAnimations.stagger(2)),
                      DSSpacing.hSm,
                      TextButton(
                        onPressed: () =>
                            setState(() => _showRejectForm = false),
                        child: const Text('CANCEL'),
                      ).dsFadeEntry(delay: DSAnimations.stagger(3)),
                    ] else ...[
                      DispatchInfoCard(
                        maskedCode: maskedCode,
                        info: info,
                      ).dsCardEntry(),

                      DSSpacing.hXl,
                      FilledButton.icon(
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('ACCEPT DISPATCH'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                        ),
                        onPressed: _handleAccept,
                      ).dsCtaEntry(delay: DSAnimations.stagger(1)),

                      DSSpacing.hSm,
                      OutlinedButton.icon(
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('REJECT DISPATCH'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: DSColors.error,
                          side: const BorderSide(color: DSColors.error),
                          minimumSize: const Size(double.infinity, 52),
                        ),
                        onPressed: () => setState(() => _showRejectForm = true),
                      ).dsCtaEntry(delay: DSAnimations.stagger(2)),

                      if (deliveries.isNotEmpty) ...[
                        DSSpacing.hXl,
                        DSSectionHeader(
                          title: 'DELIVERIES (${deliveries.length})',
                          padding: EdgeInsets.zero,
                        ).dsFadeEntry(delay: DSAnimations.stagger(3)),
                        DSSpacing.hSm,

                        ...deliveries
                            .skip(_currentPage * _pageSize)
                            .take(_pageSize)
                            .map(
                              (d) =>
                                  Padding(
                                    padding: EdgeInsets.only(
                                      bottom: DSSpacing.sm,
                                    ),
                                    child: DeliveryCard(
                                      delivery: d,
                                      compact: true,
                                      isPrivacyMode: true,
                                      showChevron: false,
                                      enableHoldToReveal: false,
                                      onTap: null,
                                    ),
                                  ).dsCardEntry(
                                    delay: DSAnimations.stagger(
                                      4 + deliveries.indexOf(d),
                                      step: DSAnimations.staggerFine,
                                    ),
                                  ),
                            ),

                        if (totalPages > 1) ...[
                          DSSpacing.hMd,
                          PaginationBar(
                            currentPage: _currentPage,
                            totalPages: totalPages,
                            firstItem: _currentPage * _pageSize + 1,
                            lastItem: math.min(
                              (_currentPage + 1) * _pageSize,
                              deliveries.length,
                            ),
                            totalCount: deliveries.length,
                            onPageChanged: (p) =>
                                setState(() => _currentPage = p),
                          ).dsFadeEntry(delay: DSAnimations.stagger(5)),
                        ],
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
