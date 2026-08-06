// DOCS: docs/development-standards.md
// DOCS: docs/features/dispatch.md — update that file when you edit this one.

// =============================================================================
// dispatch_eligibility_screen.dart — Dispatch details
// =============================================================================
//
// Purpose:
//   Review a pending dispatch after eligibility check: summary, delivery
//   preview, accept (PIN) or reject with reason.
//
// UI standard (design-system.md):
//   • DsAppScaffold + glass AppHeaderBar (standalone)
//   • List body with DS spacing / section headers
//   • DsBottomActionBar for Accept / Reject CTAs (never black void)
//   • Gold = start-work Accept; error = Reject
//
// Route: /dispatches/eligibility
// =============================================================================

import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/device/device_info.dart';
import 'package:fsi_courier_app/core/sync/delivery_bootstrap_service.dart';
import 'package:fsi_courier_app/core/sync/sync_write_coordinator.dart';
import 'package:fsi_courier_app/core/services/dispatch_service.dart';
import 'package:fsi_courier_app/core/settings/debug_ui_provider.dart';
import 'package:fsi_courier_app/shared/helpers/post_submit_navigation.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/widgets/delivery_card.dart';
import 'package:fsi_courier_app/shared/widgets/loading_overlay.dart';
import 'package:fsi_courier_app/shared/widgets/pagination_bar.dart';
import 'package:fsi_courier_app/shared/widgets/pagination_swipe_area.dart';
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

  final _rejectReasonController = TextEditingController();
  bool _showRejectForm = false;
  String? _selectedRejectReason;
  String? _rejectRemarks;
  int _currentPage = 0;
  final int _pageSize = 10;

  String get _resolvedDispatchCode => widget.dispatchCode.trim();

  Map<String, dynamic> get _eligibilityResponse => widget.eligibilityResponse;

  @override
  void dispose() {
    _rejectReasonController.dispose();
    super.dispose();
  }

  String _getMaskedLast4(String code) {
    final clean = code.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (clean.length <= 4) return clean;
    return clean.substring(clean.length - 4);
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
        .read(dispatchServiceProvider)
        .acceptDispatch(
          dispatchCode: _resolvedDispatchCode,
          clientRequestId: acceptId,
          deviceInfo: await device.toMap(),
        );

    if (!mounted) return;

    final alreadyAccepted =
        result is ApiConflict<Map<String, dynamic>> ||
        (result is ApiServerError<Map<String, dynamic>> &&
            result.message.toLowerCase().contains('already accepted'));

    if (result is ApiSuccess<Map<String, dynamic>>) {
      await DeliveryBootstrapService.instance.seedForDelivery(
        ref.read(apiClientProvider),
      );
      if (!mounted) return;
      await ref
          .read(syncWriteCoordinatorProvider)
          .completeWrite(
            reason: 'dispatch_accept',
            kickQueue: false,
            refreshDeliveries: true,
          );
      if (!mounted) return;
      setState(() => _loading = false);
      showSuccessNotification(context, 'Dispatch accepted successfully.');
      goToDashboardAfterSubmit(context);
      return;
    }

    if (alreadyAccepted) {
      setState(() => _loading = false);
      showInfoNotification(
        context,
        'Dispatch already accepted. Opening dashboard.',
      );
      goToDashboardAfterSubmit(context);
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

    if (_selectedRejectReason == null) return;

    if (_selectedRejectReason == _otherRejectReason) {
      reason = _rejectReasonController.text.trim();
      if (reason.isEmpty) return;
    } else {
      reason = _selectedRejectReason!;
    }

    final confirmed = await _showRejectConfirmationDialog(reason);
    if (!confirmed) return;

    setState(() => _loading = true);

    const uuid = Uuid();
    final requestId = uuid.v4();
    final device = ref.read(deviceInfoProvider);

    final result = await ref
        .read(dispatchServiceProvider)
        .rejectDispatch(
          dispatchCode: _resolvedDispatchCode,
          clientRequestId: requestId,
          reason: reason,
          remarks: _rejectRemarks,
          deviceInfo: await device.toMap(),
        );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result is ApiSuccess<Map<String, dynamic>>) {
      showSuccessNotification(context, 'Dispatch rejected.');
      goToDashboardAfterSubmit(context);
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

  List<Map<String, dynamic>> _parseDeliveries(Map<String, dynamic> info) {
    if (info['deliveries'] is! List) return [];
    return (info['deliveries'] as List).whereType<Map>().map((e) {
      final d = Map<String, dynamic>.from(e);
      d['barcode'] = e['barcode'] ?? e['barcode_value'] ?? '';
      d['recipient_name'] = '';
      d['recipient_address'] = e['recipient_address'] ?? e['address'] ?? '';
      return d;
    }).toList();
  }

  String _maskedCode(bool showDebugUi) {
    final dispatchCode = _resolvedDispatchCode.replaceAll(
      RegExp(r'[^a-zA-Z0-9]'),
      '',
    );
    final last4 = _getMaskedLast4(dispatchCode);
    if (widget.showFullCode || showDebugUi) {
      return showDebugUi ? '$dispatchCode (debug)' : dispatchCode;
    }
    if (dispatchCode.length > last4.length) {
      return '${dispatchCode.substring(0, dispatchCode.length - last4.length)}****';
    }
    return '****';
  }

  Widget? _buildBottomBar({
    required bool eligible,
    required bool showMainActions,
  }) {
    if (_error != null || !eligible) return null;

    if (_showRejectForm) {
      final canReject =
          _selectedRejectReason != null &&
          (_selectedRejectReason != _otherRejectReason ||
              _rejectReasonController.text.trim().isNotEmpty);
      return DsBottomActionBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.cancel_rounded),
              label: const Text('REJECT DISPATCH'),
              style: FilledButton.styleFrom(
                backgroundColor: DSColors.error,
                foregroundColor: DSColors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: DSStyles.cardRadius,
                ),
              ),
              onPressed: canReject ? _submitReject : null,
            ),
            DSSpacing.hSm,
            TextButton(
              onPressed: () => setState(() {
                _showRejectForm = false;
                _selectedRejectReason = null;
                _rejectReasonController.clear();
                _rejectRemarks = null;
              }),
              child: const Text('CANCEL'),
            ),
          ],
        ),
      );
    }

    if (!showMainActions) return null;

    return DsBottomActionBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Gold = start-work hierarchy (dashboard dispatch).
          FilledButton.icon(
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text('ACCEPT DISPATCH'),
            style: FilledButton.styleFrom(
              backgroundColor: DSColors.gold,
              foregroundColor: DSColors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: DSStyles.cardRadius),
            ),
            onPressed: _loading ? null : _handleAccept,
          ),
          DSSpacing.hSm,
          OutlinedButton.icon(
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('REJECT DISPATCH'),
            style: OutlinedButton.styleFrom(
              foregroundColor: DSColors.error,
              side: const BorderSide(color: DSColors.error),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: DSStyles.cardRadius),
            ),
            onPressed: _loading
                ? null
                : () => setState(() => _showRejectForm = true),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPanel({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
    required List<Widget> actions,
  }) {
    return DSCard(
      child: Column(
        children: [
          Icon(icon, color: color, size: DSIconSize.heroSm),
          DSSpacing.hMd,
          Text(
            title,
            textAlign: TextAlign.center,
            style: DSTypography.heading().copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          DSSpacing.hSm,
          Text(
            message,
            textAlign: TextAlign.center,
            style: DSTypography.body(),
          ),
          DSSpacing.hLg,
          ...actions,
        ],
      ),
    );
  }

  Widget _buildRejectForm({required String maskedCode, required bool isDark}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DSSectionHeader(
          title: 'REJECT DISPATCH',
          padding: EdgeInsets.zero,
        ),
        DSSpacing.hSm,
        DSCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DISPATCH CODE',
                            style:
                                DSTypography.caption(
                                  color: DSColors.white.withValues(
                                    alpha: DSStyles.alphaDisabled,
                                  ),
                                ).copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: DSTypography.sizeXs,
                                  letterSpacing: DSTypography.lsLoose,
                                ),
                          ),
                          DSSpacing.hXs,
                          Text(
                            maskedCode,
                            style: DSTypography.heading().copyWith(
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
                      'Select a rejection reason. This action is final and cannot be undone.',
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
                      decoration: const InputDecoration(
                        labelText: 'REJECTION REASON *',
                        prefixIcon: Icon(Icons.help_outline_rounded),
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
                      onChanged: (v) =>
                          setState(() => _selectedRejectReason = v),
                    ),
                    if (_selectedRejectReason == _otherRejectReason) ...[
                      DSSpacing.hMd,
                      TextField(
                        controller: _rejectReasonController,
                        maxLength: 100,
                        maxLines: 2,
                        onChanged: (_) => setState(() {}),
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
                        hintText: 'Optional notes…',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEligibleBody({
    required Map<String, dynamic> info,
    required String maskedCode,
    required List<Map<String, dynamic>> deliveries,
    required int totalPages,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DispatchInfoCard(maskedCode: maskedCode, info: info),
        if (deliveries.isNotEmpty) ...[
          DSSpacing.hLg,
          DSSectionHeader(
            title: 'DELIVERIES (${deliveries.length})',
            padding: EdgeInsets.zero,
          ),
          DSSpacing.hSm,
          ...deliveries
              .skip(_currentPage * _pageSize)
              .take(_pageSize)
              .map(
                (d) => Padding(
                  padding: EdgeInsets.only(bottom: DSSpacing.sm),
                  child: DeliveryCard(
                    delivery: d,
                    compact: true,
                    showChevron: false,
                    showLockIcon: true,
                    enableHoldToReveal: false,
                    onTap: null,
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
              onPageChanged: (p) => setState(() => _currentPage = p),
            ),
          ],
        ],
        // Room above bottom action dock.
        DSSpacing.hHuge,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final eligible = _eligibilityResponse['eligible'] == true;
    final info = _eligibilityResponse;
    final reason =
        _eligibilityResponse['message']?.toString() ??
        'You are not eligible for this dispatch.';
    final showDebugUi = ref.watch(showDebugUiProvider);
    final maskedCode = _maskedCode(showDebugUi);
    final deliveries = _parseDeliveries(info);
    final totalPages = deliveries.isEmpty
        ? 0
        : (deliveries.length / _pageSize).ceil();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final showMainActions = eligible && _error == null && !_showRejectForm;

    return PopScope(
      canPop: GoRouter.of(context).canPop(),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBack();
      },
      child: DsAppScaffold(
        appBar: AppHeaderBar(
          title: 'Dispatch details',
          pageIcon: Icons.local_shipping_rounded,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            iconSize: DSIconSize.lg,
            color: DSGlass.onChrome(context),
            onPressed: () => _handleBack(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded),
              color: DSGlass.onChrome(context),
              tooltip: 'Scan Dispatch',
              onPressed: () =>
                  context.push('/scan', extra: {'mode': 'dispatch'}),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(
          eligible: eligible,
          showMainActions: showMainActions,
        ),
        body: LoadingOverlay(
          isLoading: _loading,
          child: PaginationSwipeArea(
            currentPage: _currentPage,
            totalPages: totalPages > 0 ? totalPages : 1,
            onPageChanged: (p) {
              if (totalPages <= 1) return;
              setState(() => _currentPage = p);
            },
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                DSSpacing.md,
                DSSpacing.md,
                DSSpacing.md,
                DSSpacing.xl,
              ),
              children: [
                if (_error != null)
                  _buildStatusPanel(
                    icon: Icons.error_rounded,
                    color: DSColors.warning,
                    title: 'ERROR',
                    message: _error!,
                    actions: [
                      FilledButton(
                        onPressed: _handleAccept,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: DSStyles.cardRadius,
                          ),
                        ),
                        child: const Text('RETRY'),
                      ),
                    ],
                  )
                else if (!eligible)
                  _buildStatusPanel(
                    icon: Icons.cancel_rounded,
                    color: DSColors.error,
                    title: 'NOT ELIGIBLE',
                    message: reason,
                    actions: [
                      OutlinedButton(
                        onPressed: _handleBack,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: DSStyles.cardRadius,
                          ),
                        ),
                        child: const Text('BACK'),
                      ),
                    ],
                  )
                else if (_showRejectForm)
                  _buildRejectForm(maskedCode: maskedCode, isDark: isDark)
                else
                  _buildEligibleBody(
                    info: info,
                    maskedCode: maskedCode,
                    deliveries: deliveries,
                    totalPages: totalPages,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
