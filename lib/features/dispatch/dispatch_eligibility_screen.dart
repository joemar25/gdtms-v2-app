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

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/device/device_info.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/widgets/delivery_card.dart';
import 'package:fsi_courier_app/shared/widgets/loading_overlay.dart';
import 'package:fsi_courier_app/shared/widgets/success_overlay.dart';
import 'package:fsi_courier_app/shared/widgets/pagination_bar.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

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
  static const List<String> _predefinedRejectReasons = [
    'RECIPIENT NOT AVAILABLE',
    'INVALID / INCOMPLETE ADDRESS',
    'DAMAGED DOCUMENTS',
    'DUPLICATE DISPATCH',
    'OUTSIDE ASSIGNED AREA',
    'SAFETY CONCERN',
  ];

  bool _loading = false;
  bool _showSuccess = false;
  String? _error;

  // Reject form state
  final _rejectReasonController = TextEditingController();
  bool _showRejectForm = false;
  String? _rejectError;
  bool _rejecting = false;
  String? _selectedRejectReason;
  int _currentPage = 0;

  String get _resolvedDispatchCode => widget.dispatchCode.trim();

  /// Get eligibility response from widget (data fetched before navigation)
  Map<String, dynamic> get _eligibilityResponse => widget.eligibilityResponse;

  @override
  void initState() {
    super.initState();
    // No need to fetch - data passed from notifications screen navigation
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
          builder: (ctx) => _PinConfirmDialog(expectedPin: actual),
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

  Future<void> _acceptDispatch() async {
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
      // Store the deliveries from the eligibility response into local SQLite.
      // The eligibility payload already contains the full deliveries list:
      // [{barcode_value, job_order, name, address, contact, product,
      //   special_instruction, delivery_status}, ...]
      final rawDeliveries = _eligibilityResponse['deliveries'];
      if (rawDeliveries is List) {
        final deliveries = rawDeliveries
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (deliveries.isNotEmpty) {
          await LocalDeliveryDao.instance.insertAll(
            deliveries,
            dispatchCode: _resolvedDispatchCode,
          );
        }
      }
      ref.read(deliveryRefreshProvider.notifier).increment();
      setState(() {
        _showSuccess = true;
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
      setState(() => _rejectError = 'Please select a rejection reason.');
      return;
    }

    if (_selectedRejectReason == _otherRejectReason) {
      reason = _rejectReasonController.text.trim();
      if (reason.isEmpty) {
        setState(() => _rejectError = 'Please specify your rejection reason.');
        return;
      }
    } else {
      reason = _selectedRejectReason!;
    }

    if (reason.isEmpty) {
      setState(() => _rejectError = 'Rejection reason is required.');
      return;
    }

    final confirmed = await _showRejectConfirmationDialog(reason);
    if (!confirmed) return;

    setState(() {
      _rejecting = true;
      _rejectError = null;
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
            'device_info': await device.toMap(),
          },
          parser: parseApiMap,
        );

    if (!mounted) return;
    setState(() => _rejecting = false);

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
                const SizedBox(width: 8),
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
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(DSSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: DSStyles.alphaSoft),
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
    // Data is guaranteed to be present (fetched before navigation)
    final eligible = _eligibilityResponse['eligible'] == true;
    // Response is flat (not nested under 'data')
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Extract deliveries for use below actions
    final deliveries = info['deliveries'] is List
        ? (info['deliveries'] as List).whereType<Map>().map((e) {
            final d = Map<String, dynamic>.from(e);
            // Clear status so only barcode and product are shown
            d['delivery_status'] = '';
            return d;
          }).toList()
        : <Map<String, dynamic>>[];

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
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(DSSpacing.base),
                children: [
                  // Show error state if API call failed
                  if (_error != null) ...[
                    const SizedBox(height: 40),
                    Icon(
                      Icons.error_rounded,
                      color: DSColors.warning,
                      size: 64,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'ERROR',
                      textAlign: TextAlign.center,
                      style: DSTypography.heading().copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: DSTypography.sizeMd,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: DSTypography.body(),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _handleBack,
                      child: const Text('BACK'),
                    ),
                  ] else if (!eligible) ...[
                    const SizedBox(height: 40),
                    Icon(Icons.cancel_rounded, color: DSColors.error, size: 64),
                    const SizedBox(height: 12),
                    Text(
                      'NOT ELIGIBLE',
                      textAlign: TextAlign.center,
                      style: DSTypography.heading().copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: DSTypography.sizeMd,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      reason,
                      textAlign: TextAlign.center,
                      style: DSTypography.body(),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _handleBack,
                      child: const Text('BACK'),
                    ),
                  ] else if (_showRejectForm) ...[
                    // ── Reject Form ─────────────────────────────────────────
                    _SectionHeader(label: 'REJECT DISPATCH'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(DSSpacing.base),
                      decoration: BoxDecoration(
                        color: isDark ? DSColors.cardDark : DSColors.cardLight,
                        borderRadius: DSStyles.cardRadius,
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.red.shade100,
                        ),
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: DSStyles.alphaSoft,
                                  ),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(DSSpacing.sm),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(
                                    alpha: DSStyles.alphaSoft,
                                  ),
                                  borderRadius: DSStyles.cardRadius,
                                ),
                                child: const Icon(
                                  Icons.gpp_maybe_outlined,
                                  color: Colors.red,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  maskedCode,
                                  style: DSTypography.heading().copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: DSTypography.sizeMd,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Select a rejection reason.',
                            style: DSTypography.caption().copyWith(
                              fontSize: DSTypography.sizeSm,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedRejectReason,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'REJECTION REASON *',
                              prefixIcon: const Icon(Icons.list_alt_rounded),
                              filled: true,
                              fillColor: isDark
                                  ? DSColors.scaffoldDark
                                  : Colors.grey.withValues(
                                      alpha: DSStyles.alphaSoft,
                                    ),
                              errorText: _rejectError,
                              border: OutlineInputBorder(
                                borderRadius: DSStyles.cardRadius,
                                borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.white24
                                      : Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: DSStyles.cardRadius,
                                borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.white24
                                      : Colors.grey.shade300,
                                ),
                              ),
                            ),
                            hint: const Text('Select reason'),
                            items:
                                [
                                  ..._predefinedRejectReasons,
                                  _otherRejectReason,
                                ].map((reason) {
                                  return DropdownMenuItem<String>(
                                    value: reason,
                                    child: Text(reason),
                                  );
                                }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedRejectReason = value;
                                _rejectError = null;
                                if (value != _otherRejectReason) {
                                  _rejectReasonController.clear();
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    if (_selectedRejectReason == _otherRejectReason) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _rejectReasonController,
                        maxLength: 100,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'SPECIFY REASON *',
                          hintText: 'STATE YOUR REASON HERE...',
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 40),
                            child: Icon(Icons.edit_note_rounded),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? DSColors.scaffoldDark
                              : Colors.grey.withValues(
                                  alpha: DSStyles.alphaSoft,
                                ),
                          border: OutlineInputBorder(
                            borderRadius: DSStyles.cardRadius,
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white24
                                  : Colors.grey.shade300,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: DSStyles.cardRadius,
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white24
                                  : Colors.grey.shade300,
                            ),
                          ),
                          alignLabelWithHint: true,
                        ),
                        onChanged: (_) {
                          if (_rejectError != null) {
                            setState(() => _rejectError = null);
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(DSSpacing.md),
                      decoration: BoxDecoration(
                        color: DSColors.warning.withValues(
                          alpha: DSStyles.alphaSoft,
                        ),
                        borderRadius: DSStyles.cardRadius,
                        border: Border.all(
                          color: DSColors.warning.withValues(
                            alpha: DSStyles.alphaDarkShadow,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            color: DSColors.warning,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'You will be asked to confirm once more before submitting rejection.',
                              style: DSTypography.label().copyWith(
                                fontSize: DSTypography.sizeSm,
                                color: isDark
                                    ? DSColors.warning
                                    : Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                            onPressed: _rejecting
                                ? null
                                : () => setState(() => _showRejectForm = false),
                            child: const Text('BACK'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: DSColors.error,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: DSStyles.cardRadius,
                              ),
                            ),
                            onPressed: _rejecting ? null : _submitReject,
                            child: _rejecting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('SUBMIT REJECTION'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // ── Dispatch Info Card ───────────────────────────────────
                    _DispatchInfoCard(maskedCode: maskedCode, info: info),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(DSSpacing.md),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(
                            alpha: DSStyles.alphaSoft,
                          ),
                          borderRadius: DSStyles.cardRadius,
                          border: Border.all(
                            color: Colors.red.withValues(
                              alpha: DSStyles.alphaDarkShadow,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: DSColors.error,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: DSTypography.body().copyWith(
                                  color: DSColors.error,
                                  fontSize: DSTypography.sizeMd,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (!widget.skipPinDialog) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(DSSpacing.md),
                        decoration: BoxDecoration(
                          color: DSColors.warning.withValues(
                            alpha: DSStyles.alphaSoft,
                          ),
                          borderRadius: DSStyles.cardRadius,
                          border: Border.all(
                            color: DSColors.warning.withValues(
                              alpha: DSStyles.alphaBorder,
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.lock_outline,
                              color: DSColors.warning,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'To confirm acceptance, you will need to enter the last 4 digits of the dispatch code.',
                                style: DSTypography.body().copyWith(
                                  fontSize: DSTypography.sizeSm,
                                  color: isDark
                                      ? DSColors.warning
                                      : Colors.amber.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    FilledButton.icon(
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('ACCEPT DISPATCH'),
                      style: FilledButton.styleFrom(
                        backgroundColor: DSColors.primary,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: DSStyles.cardRadius,
                        ),
                      ),
                      onPressed: _loading ? null : _acceptDispatch,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('REJECT DISPATCH'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DSColors.error,
                        side: const BorderSide(color: DSColors.error),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: DSStyles.cardRadius,
                        ),
                      ),
                      onPressed: () => setState(() => _showRejectForm = true),
                    ),

                    // ── Deliveries list below actions ───────────────────────
                    if (deliveries.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'DELIVERIES (${deliveries.length})',
                            style: DSTypography.label().copyWith(
                              fontSize: DSTypography.sizeSm,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade500,
                              letterSpacing: DSTypography.lsGiantLoose,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Local Pagination for Preview
                      // Using kCompactDeliveriesPerPage (20)
                      Builder(
                        builder: (context) {
                          final pageSize = kCompactDeliveriesPerPage;
                          final total = deliveries.length;
                          final totalPages = (total / pageSize).ceil();
                          final start = _currentPage * pageSize;
                          final end = (start + pageSize > total)
                              ? total
                              : start + pageSize;
                          final visibleDeliveries = deliveries.sublist(
                            start,
                            end,
                          );

                          return GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onHorizontalDragEnd: (details) {
                              final velocity = details.primaryVelocity ?? 0;
                              if (velocity < -500 &&
                                  _currentPage < totalPages - 1) {
                                HapticFeedback.mediumImpact();
                                setState(() => _currentPage++);
                              } else if (velocity > 500 && _currentPage > 0) {
                                HapticFeedback.mediumImpact();
                                setState(() => _currentPage--);
                              }
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ...visibleDeliveries.map(
                                  (d) => DeliveryCard(
                                    delivery: d,
                                    compact: true,
                                    isPrivacyMode:
                                        true, // Only barcode and product
                                    showChevron: false,
                                    enableHoldToReveal: false,
                                    onTap: null,
                                  ),
                                ),
                                if (totalPages > 1) ...[
                                  const SizedBox(height: 12),
                                  PaginationBar(
                                    currentPage: _currentPage,
                                    totalPages: totalPages,
                                    firstItem: start + 1,
                                    lastItem: end,
                                    totalCount: total,
                                    onPageChanged: (p) =>
                                        setState(() => _currentPage = p),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ],
              ),
              // Loading state handled by wrapper
              if (_showSuccess)
                SuccessOverlay(
                  onDone: () {
                    if (!mounted) return;
                    showAppSnackbar(
                      context,
                      'Dispatch accepted successfully!',
                      type: SnackbarType.success,
                    );
                    context.go('/dashboard');
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── PIN Confirmation Dialog ──────────────────────────────────────────────────

class _PinConfirmDialog extends StatefulWidget {
  const _PinConfirmDialog({required this.expectedPin});
  final String expectedPin;

  @override
  State<_PinConfirmDialog> createState() => _PinConfirmDialogState();
}

class _PinConfirmDialogState extends State<_PinConfirmDialog> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  String? _error;

  @override
  void initState() {
    super.initState();
    // Wire up backspace handling for each focus node
    for (int i = 0; i < 4; i++) {
      final index = i;
      _focusNodes[index].onKeyEvent = (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            _controllers[index].text.isEmpty &&
            index > 0) {
          _focusNodes[index - 1].requestFocus();
          _controllers[index - 1].clear();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      };
    }
    // Auto-focus the first digit when dialog is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 3) {
      _focusNodes[index + 1].requestFocus();
    }
    // REMOVE the "value.isEmpty" block — onKeyEvent handles backspace now
    setState(() => _error = null);

    final entered = _controllers.map((c) => c.text).join();
    if (entered.length == 4 && _controllers.every((c) => c.text.isNotEmpty)) {
      Future.delayed(const Duration(milliseconds: 100), _confirm);
    }
  }

  void _confirm() {
    final entered = _controllers.map((c) => c.text).join();
    if (entered.length < 4) {
      setState(() => _error = 'Please enter all 4 digits.');
      return;
    }
    if (entered != widget.expectedPin) {
      setState(() {
        _error = 'Incorrect last 4 digits.';
        for (final c in _controllers) {
          c.clear();
        }
      });
      _focusNodes[0].requestFocus();
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: DSStyles.cardRadius),
      child: Padding(
        padding: const EdgeInsets.all(DSSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 36,
              color: DSColors.primary,
            ),
            const SizedBox(height: 12),
            const Text(
              'CONFIRM ACCEPTANCE',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: DSTypography.sizeMd,
                letterSpacing: DSTypography.lsLoose,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'ENTER LAST 4 DIGITS OF DISPATCH CODE TO CONFIRM',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: DSTypography.sizeSm,
                color: Colors.grey.shade600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4,
                (i) => Expanded(
                  child: Container(
                    height: 58,
                    margin: const EdgeInsets.symmetric(
                      horizontal: DSSpacing.xs,
                    ),
                    child: TextFormField(
                      controller: _controllers[i],
                      focusNode: _focusNodes[i],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: DSStyles.cardRadius,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: DSStyles.cardRadius,
                          borderSide: const BorderSide(
                            color: DSColors.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: DSTypography.sizeLg,
                        fontWeight: FontWeight.w800,
                      ),
                      onChanged: (v) => _onDigitChanged(i, v),
                    ),
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: DSTypography.sizeSm,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('CANCEL'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: DSColors.primary,
                    ),
                    onPressed: _confirm,
                    child: const Text('CONFIRM'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Dispatch Info Card ───────────────────────────────────────────────────────

class _DispatchInfoCard extends StatelessWidget {
  const _DispatchInfoCard({required this.maskedCode, required this.info});
  final String maskedCode;
  final Map<String, dynamic> info;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? DSColors.cardDark : DSColors.cardLight;

    final branch = info['branch'] is Map
        ? info['branch'] as Map
        : <String, dynamic>{};
    final branchName = branch['branch_name']?.toString() ?? '-';
    final volume = info['volume']?.toString() ?? '-';
    final tat = info['tat']?.toString() ?? '';
    final transmittalDate = info['transmittal_date']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header card ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(DSSpacing.base),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: DSStyles.cardRadius,
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Status indicator
              Positioned(
                left: -16, // account for container padding
                top: -16,
                bottom: -16,
                width: 4,
                child: Container(color: DSColors.primary),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    maskedCode,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: DSTypography.sizeMd,
                      letterSpacing: DSTypography.lsLoose,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.store_outlined,
                    label: 'BRANCH',
                    value: branchName,
                  ),
                  _InfoRow(
                    icon: Icons.inventory_2_outlined,
                    label: 'ITEMS',
                    value: volume,
                  ),
                  _InfoRow(
                    icon: Icons.event_outlined,
                    label: 'TRANSMITTAL DATE',
                    value: transmittalDate.isNotEmpty
                        ? formatDate(transmittalDate)
                        : '-',
                  ),
                  _InfoRow(
                    icon: Icons.schedule_outlined,
                    label: 'TAT',
                    value: tat.isNotEmpty
                        ? formatDate(tat, includeTime: false)
                        : '-',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DSSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: DSTypography.sizeSm,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: DSTypography.sizeMd,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: DSTypography.sizeSm,
        fontWeight: FontWeight.w700,
        color: Colors.grey.shade500,
        letterSpacing: DSTypography.lsGiantLoose,
      ),
    );
  }
}
