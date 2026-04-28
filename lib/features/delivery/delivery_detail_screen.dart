// DOCS: docs/features/delivery.md — update that file when you edit this one.

// =============================================================================
// delivery_detail_screen.dart
// =============================================================================
//
// Purpose:
//   Read-only detail view for a single delivery item. Shows all available
//   metadata (recipient, address, contact, mail type, dispatch info, notes)
//   and provides the primary action to update the delivery status.
//
// Key behaviours:
//   • UPDATE FAB — disabled (greyed out, "SYNC PENDING…") when the delivery has
//     an active sync-queue entry, preventing double-submission.
//   • Delivered lock — when status is DELIVERED, address and contact rows become
//     non-tappable (no accidental navigation away).
//   • Timeline — full status history rendered from rawJson, restricted to debug
//     app builds; hidden in production since it is not essential UI.
//   • Tappable rows — delivery address launches Maps; contact number launches
//     the dialler; both respect null-safety and lock state.
//   • Online refresh — when online, pulls the latest server record and merges it
//     into local SQLite before rendering.
//
// Data:
//   Sourced from local SQLite ([LocalDeliveryDao.getByBarcode]). An optional
//   online refresh is triggered on mount when connectivity is available.
//
// Navigation:
//   Route: /deliveries/:barcode
//   Pushed from: DeliveryStatusListScreen, SyncScreen, ScanScreen
// =============================================================================

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/database/sync_operations_dao.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/core/models/delivery_status.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_helper.dart';
import 'package:fsi_courier_app/shared/helpers/string_helper.dart';

import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/core/config.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/widgets/contact_app_sheet.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Local design tokens for DeliveryDetailScreen.
// Typography, spacing, and radii are screen-local.
// Background/surface constants delegate to ColorStyles — do NOT duplicate.
// ─────────────────────────────────────────────────────────────────────────────

// Local design tokens migrated to global Design System.

// Contact app sheet logic moved to shared/widgets/contact_app_sheet.dart

// ─────────────────────────────────────────────────────────────────────────────
// DeliveryDetailScreen — all logic and conditions preserved
// ─────────────────────────────────────────────────────────────────────────────

class DeliveryDetailScreen extends ConsumerStatefulWidget {
  const DeliveryDetailScreen({super.key, required this.barcode});

  final String barcode;

  @override
  ConsumerState<DeliveryDetailScreen> createState() =>
      _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends ConsumerState<DeliveryDetailScreen> {
  bool _loading = true;
  Map<String, dynamic> _delivery = {};
  bool _isOfflineMode = false;
  bool _hasPendingSync = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ─── Data loading (unchanged) ─────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _isOfflineMode = false;
    });

    // ── VISIBILITY GATE ──────────────────────────────────────────────────────
    // Rule: A courier may only view a delivery that is currently visible in one
    // of their active list screens. The visibility rules (defined in
    // LocalDeliveryDao.isVisibleToRider) are:
    //
    //   • PENDING   — any non-archived pending record
    //   • DELIVERED — delivered_at is today (paid status does not lock details)
    //   • FAILED_DELIVERY — completed_at is today AND rts_verification_status is
    //                        NOT 'verified_with_pay' OR 'verified_no_pay'
    //   • OSA       — completed_at is today
    //
    // This check MUST run before the API call so that:
    //   (a) a smart user who knows a barcode cannot reach it by scanning or
    //       typing it directly into the scan input.
    //   (b) items that have fallen out of the active window (yesterday's Failed Delivery,
    //       verified Failed Delivery) are never accessible, even if the API still returns data.
    //
    // The scan screen also runs this check as a UX pre-filter, but the gate
    // HERE is the canonical, tamper-proof enforcement point.
    final isVisible = await LocalDeliveryDao.instance.isVisibleToRider(
      widget.barcode,
    );
    if (!mounted) return;
    if (!isVisible) {
      // Determine a helpful message based on the local record's status.
      final local = await LocalDeliveryDao.instance.getByBarcode(
        widget.barcode,
      );
      if (!mounted) return;
      final status = (local?.deliveryStatus ?? '').toUpperCase();
      final rtsVerif = (local?.rtsVerificationStatus ?? 'unvalidated')
          .toLowerCase();

      final ds = DeliveryStatus.fromString(status);
      String reason;
      if (ds == DeliveryStatus.osa) {
        reason = 'OSA items cannot be opened.';
      } else if (ds == DeliveryStatus.failedDelivery &&
          (rtsVerif == 'verified_with_pay' || rtsVerif == 'verified_no_pay')) {
        // RULE: Verified failed-delivery items are fully settled — no further action needed.
        reason =
            'This failed delivery has already been verified and is no longer actionable.';
      } else {
        // RULE: Item not in today's active window (e.g. yesterday's DELIVERED/FAILED_DELIVERY/OSA).
        reason = 'This delivery is not in your active list.';
      }

      // Pop back gracefully — the user should not see a blank/broken screen.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(reason), backgroundColor: DSColors.error),
        );
        // Use go('/dashboard') if nothing is beneath us in the stack.
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/dashboard');
        }
      }
      return;
    }
    // ── END VISIBILITY GATE ───────────────────────────────────────────────────

    final isOnline = ref.read(isOnlineProvider);

    if (isOnline) {
      final result = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>(
            '/deliveries/${widget.barcode}',
            parser: parseApiMap,
          );

      if (!mounted) return;

      if (result case ApiSuccess<Map<String, dynamic>>(:final data)) {
        final deliveryData = mapFromKey(data, 'data');
        _delivery = deliveryData;

        if (deliveryData.isNotEmpty) {
          await LocalDeliveryDao.instance.updateFromJson(
            widget.barcode,
            deliveryData,
          );
        }
        setState(() => _loading = false);
        return;
      }
    }

    final local = await LocalDeliveryDao.instance.getByBarcode(widget.barcode);
    final pendingSync = await SyncOperationsDao.instance.hasPendingSync(
      widget.barcode,
    );

    if (!mounted) return;
    if (local != null) {
      _delivery = local.toDeliveryMap();
      _isOfflineMode = true;
    }
    setState(() {
      _hasPendingSync = pendingSync;
      _loading = false;
    });

    if (kAppDebugMode) {
      debugPrint('[DEBUG-DET] delivery keys: ${_delivery.keys}');
    }
  }

  // ─── Actions (logic unchanged) ────────────────────────────────────────────

  Future<void> _onPhoneTap(String? phone, {String? targetName}) async {
    if (!mounted) return;
    final barcode = widget.barcode;
    final resolvedName = targetName ?? _str('name');
    final template =
        'Hi${resolvedName.isNotEmpty ? ' $resolvedName' : ''}! '
        "I'm your FSI courier "
        '${barcode.isNotEmpty ? 'with tracking number $barcode' : 'with your delivery'}. '
        'Please be ready or contact me for re-scheduling. Thank you!';
    await showContactAppSheet(context, phone ?? '', messageTemplate: template);
  }

  // Future<void> _onViberTap(String? phone, {String? targetName}) async {
  //   if (!mounted) return;
  //   final barcode = widget.barcode;
  //   final resolvedName = targetName ?? _str('name');
  //   final template =
  //       'Hi${resolvedName.isNotEmpty ? ' $resolvedName' : ''}! '
  //       "I'm your FSI courier "
  //       '${barcode.isNotEmpty ? 'with tracking number $barcode' : 'with your delivery'}. '
  //       'Please be ready or contact me for re-scheduling. Thank you!';

  //   final cleaned = (phone ?? '').trim();
  //   if (cleaned.isEmpty) return;
  //   final noPlus = cleaned.replaceAll('+', '');
  //   final uri = Uri.parse(
  //     'viber://chat?number=$noPlus&text=${Uri.encodeComponent(template)}',
  //   );

  //   HapticFeedback.lightImpact();
  //   await launchUrl(uri, mode: LaunchMode.externalApplication);
  // }

  Future<void> _launchMaps(String? address) async {
    final destination = address?.trim() ?? '';
    if (destination.isEmpty) return;
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(destination)}';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  // ─── Helpers (unchanged) ──────────────────────────────────────────────────

  String _str(String key) => _delivery[key]?.toString().trim() ?? '';

  Future<void> _copyToClipboard(String text, String label) async {
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.mediumImpact();
    if (mounted) {
      showSuccessNotification(context, 'Copied $label to clipboard');
    }
  }

  /// Parses the piece count from a barcode that uses the `BASE/N` convention.
  /// e.g. "FSI123456/3" → 3 pieces total, "FSI123456/2" → 2 pieces.
  /// Returns 0 if the barcode has no slash or the part after is not a number.
  int get _pieceCountFromBarcode {
    final b = widget.barcode;
    final slashIdx = b.lastIndexOf('/');
    if (slashIdx < 0 || slashIdx == b.length - 1) return 0;
    return int.tryParse(b.substring(slashIdx + 1).trim()) ?? 0;
  }

  DeliveryStatus get _ds => DeliveryStatus.fromString(_str('delivery_status'));

  bool get _isFailedDeliveryLocked {
    if (_ds != DeliveryStatus.failedDelivery) return false;
    return FailedDeliveryVerificationStatus.fromString(
      _delivery['rts_verification_status']?.toString() ??
          _delivery['failed_delivery_verification_status']?.toString(),
    ).isVerified;
  }

  // String get _failedDeliveryVerifStatus =>
  //     _delivery['rts_verification_status']?.toString() ??
  //     _delivery['failed_delivery_verification_status']?.toString() ??
  //     'unvalidated';

  bool get _canShowContactInfo {
    if (_ds == DeliveryStatus.pending) return true;
    if (_ds == DeliveryStatus.failedDelivery && !_isFailedDeliveryLocked) {
      return true;
    }
    return false;
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(deliveryRefreshProvider, (_, _) => _load());

    final status = _str('delivery_status').toUpperCase();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Scaffold background is inherited from the global ThemeData set in app.dart.
    // Do NOT override it here — use the theme token so this screen stays consistent.
    // (bgColor kept for in-screen Card/surface use only)
    // final bgColor = isDark ? _DS.bgDark : _DS.bg; // <- removed scaffold override

    // RULE: If status is 'OSA', do not ever show update status button here.
    // NEW RULE: If status is 'FAILED_DELIVERY' and already verified OR attempts >= 3, hide the button.
    final isLockedGlobal = checkIsLockedFromMap(_delivery);
    // FAB shown for PENDING and unverified failedDelivery (courier can reattempt).
    final showFab =
        (_ds == DeliveryStatus.pending ||
            _ds == DeliveryStatus.failedDelivery) &&
        !isLockedGlobal;

    return Scaffold(
      appBar: AppHeaderBar(
        titleWidget: _buildAppBarTitle(context, status, isDark),
        backgroundColor: DSColors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
      ),
      floatingActionButton: showFab
          ? FloatingActionButton.extended(
              onPressed: _hasPendingSync
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      context.push('/deliveries/${widget.barcode}/update');
                    },
              backgroundColor: _hasPendingSync
                  ? DSColors.labelSecondary
                  : DSColors.primary,
              elevation: _hasPendingSync ? 0 : 6,
              icon: _hasPendingSync
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: DSColors.white.withValues(alpha: 0.7),
                      ),
                    )
                  : const Icon(Icons.edit_rounded, size: DSIconSize.md, color: DSColors.white),
              label: Text(
                _hasPendingSync ? 'SYNC PENDING…' : 'UPDATE STATUS',
                style: DSTypography.button(
                  color: DSColors.white,
                ).copyWith(letterSpacing: DSTypography.lsSlightlyLoose),
              ),
            )
          : null,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: DSColors.primary,
              ),
            )
          : Column(
              children: [
                if (_isOfflineMode) const _OfflineBanner(),
                Expanded(
                  child: RefreshIndicator(
                    color: DSColors.primary,
                    onRefresh: _load,
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        DSSpacing.base,
                        DSSpacing.sm,
                        DSSpacing.base,
                        showFab
                            ? DSSpacing.xxl +
                                  88.0 +
                                  MediaQuery.of(context).padding.bottom
                            : DSSpacing.xxl,
                      ),
                      children: [
                        // ── Account details card ──────────────────────────
                        if (!checkIsLockedFromMap(_delivery))
                          DSCard(
                            margin: const EdgeInsets.only(
                              bottom: DSSpacing.base,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const DSSectionHeader(title: 'Account Details'),
                                DSInfoTile(
                                  label: 'Name',
                                  value: _str('name'),
                                  onLongPress: () =>
                                      _copyToClipboard(_str('name'), 'Name'),
                                ),
                                if (_pieceCountFromBarcode > 0)
                                  DSInfoTile(
                                    label: 'Pieces',
                                    value:
                                        '$_pieceCountFromBarcode piece${_pieceCountFromBarcode > 1 ? 's' : ''} in this bundle',
                                  ),
                                if (_canShowContactInfo) ...[
                                  DSInfoTile(
                                    label: 'Address',
                                    value: _str('address'),
                                    onTap: () => _launchMaps(_str('address')),
                                    onLongPress: () => _copyToClipboard(
                                      _str('address'),
                                      'Address',
                                    ),
                                  ),
                                  DSInfoTile(
                                    label: 'Contact',
                                    value: _str('contact').cleanContactNumber(),
                                    onTap: () => _onPhoneTap(
                                      _str('contact').cleanContactNumber(),
                                    ),
                                    onLongPress: () => _copyToClipboard(
                                      _str('contact').cleanContactNumber(),
                                      'Contact',
                                    ),
                                    showDivider: false,
                                  ),
                                ],
                              ],
                            ),
                          ),

                        // ── Delivery details (most important, always on top) ──
                        _buildDeliveryDetailsCard(isDark),

                        // ── Proof of delivery ─────────────────────────────
                        _buildDeliveredDetails(isDark),

                        // ── Failed Delivery attempts ─────────────────────────────
                        _buildFailedDeliveryAttempts(isDark),

                        // ── History timeline ──────────────────────────────
                        _buildTimeline(isDark),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAppBarTitle(BuildContext context, String status, bool isDark) {
    return !_loading
        ? Row(
            children: [
              Flexible(
                child: Text(
                  widget.barcode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      DSTypography.title(
                        color: isDark
                            ? DSColors.labelPrimaryDark
                            : DSColors.labelPrimary,
                      ).copyWith(
                        fontSize: DSTypography.sizeMd,
                        letterSpacing: DSTypography.lsSlightlyLoose,
                      ),
                ),
              ),
              DSSpacing.wMd,
            ],
          )
        : Text(
            widget.barcode,
            style:
                DSTypography.title(
                  color: isDark
                      ? DSColors.labelPrimaryDark
                      : DSColors.labelPrimary,
                ).copyWith(
                  fontSize: DSTypography.sizeMd,
                  letterSpacing: DSTypography.lsSlightlyLoose,
                ),
          );
  }

  // ─── Proof of delivery (all conditions preserved) ─────────────────────────

  Widget _buildDeliveredDetails(bool isDark) {
    // Proof of Delivery is only meaningful for delivered items — FAILED_DELIVERY/OSA were
    // never physically delivered so there is nothing to prove.
    if (_str('delivery_status').toUpperCase() != 'DELIVERED') {
      return const SizedBox.shrink();
    }

    final authRep = _str('authorized_rep');
    final contactRep = _str('contact_rep');
    final recipient = _str('recipient');
    var relationship = _str('relationship');
    final placementType = _str('placement_type');
    final note = _str('note');
    final transactionAt = _str('transaction_at');
    final deliveredDate = _str('delivered_date');

    // Relationship transformation: resolve stored value to its display label.
    if (relationship.isNotEmpty) {
      final match = kRelationshipOptions.firstWhere(
        (e) => e['value']!.toUpperCase() == relationship.toUpperCase(),
        orElse: () => {},
      );
      relationship = match['label'] ?? relationship;
      if (placementType.isNotEmpty) {
        relationship = '$relationship ($placementType)';
      }
    }

    // Transaction/Delivered date logic
    String transactionDateToShow = '';
    String deliveredDateToShow = '';
    if (transactionAt.isNotEmpty &&
        deliveredDate.isNotEmpty &&
        transactionAt == deliveredDate) {
      deliveredDateToShow = formatDate(deliveredDate, includeTime: true);
      transactionDateToShow = '';
    } else {
      transactionDateToShow = transactionAt.isNotEmpty
          ? formatDate(transactionAt, includeTime: true)
          : '';
      deliveredDateToShow = deliveredDate.isNotEmpty
          ? formatDate(deliveredDate, includeTime: true)
          : '';
    }

    final hasAny =
        authRep.isNotEmpty ||
        contactRep.isNotEmpty ||
        recipient.isNotEmpty ||
        relationship.isNotEmpty ||
        placementType.isNotEmpty ||
        note.isNotEmpty ||
        transactionDateToShow.isNotEmpty ||
        deliveredDateToShow.isNotEmpty;

    if (!hasAny) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: DSSpacing.base),
      child: DSCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DSSectionHeader(title: 'Proof of Delivery'),
            if (recipient.isNotEmpty)
              DSInfoTile(
                label: 'Received By',
                value: recipient,
                onLongPress: () =>
                    _copyToClipboard(recipient, 'Recipient Name'),
              ),
            if (authRep.isNotEmpty)
              DSInfoTile(
                label: 'Authorized Rep',
                value: authRep,
                onLongPress: () =>
                    _copyToClipboard(authRep, 'Authorized Rep Name'),
              ),
            if (relationship.isNotEmpty)
              DSInfoTile(label: 'Relationship', value: relationship),
            // Do not expose auth-rep contact number after delivery is complete.
            if (contactRep.isNotEmpty &&
                _str('delivery_status').toUpperCase() != 'DELIVERED')
              DSInfoTile(
                label: 'Contact',
                value: contactRep.cleanContactNumber(),
                icon: Icons.phone_rounded,
                accentColor: DSColors.primary,
                onTap: () => _onPhoneTap(
                  contactRep.cleanContactNumber(),
                  targetName: authRep,
                ),
                onLongPress: () => _copyToClipboard(
                  contactRep.cleanContactNumber(),
                  'Rep Contact',
                ),
              ),
            if (placementType.isNotEmpty && relationship.isEmpty)
              DSInfoTile(label: 'Placement', value: placementType),
            if (note.isNotEmpty) DSInfoTile(label: 'Note', value: note),
            if (transactionDateToShow.isNotEmpty)
              DSInfoTile(label: 'Transaction', value: transactionDateToShow),
            if (deliveredDateToShow.isNotEmpty)
              DSInfoTile(
                label: 'Delivered',
                value: deliveredDateToShow,
                showDivider: false,
              ),
          ],
        ),
      ),
    );
  }

  // ─── Failed Delivery attempts (all conditions preserved) ─────────────────

  Widget _buildFailedDeliveryAttempts(bool isDark) {
    final attempts =
        _delivery['failed_delivery_attempts'] ?? _delivery['rts_attempts'];
    if (attempts is! List || attempts.isEmpty) return const SizedBox.shrink();

    final typedAttempts = attempts.whereType<Map>().toList();
    if (typedAttempts.isEmpty) return const SizedBox.shrink();

    final failedDeliveryVerifStatus =
        _delivery['rts_verification_status']?.toString() ??
        _delivery['failed_delivery_verification_status']?.toString() ??
        'unvalidated';
    final isWithPay = failedDeliveryVerifStatus == 'verified_with_pay';
    final isValidated =
        isWithPay || failedDeliveryVerifStatus == 'verified_no_pay';

    return Padding(
      padding: const EdgeInsets.only(top: DSSpacing.base),
      child: DSCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with pay-status badge
            DSSectionHeader(
              title: 'Delivery Attempts',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: (isDark ? DSColors.white : DSColors.labelPrimary)
                          .withValues(alpha: DSStyles.alphaSoft),
                      borderRadius: BorderRadius.circular(DSStyles.radiusBadge),
                    ),
                    child: Text(
                      '${typedAttempts.length}',
                      style:
                          DSTypography.caption(
                            fontSize: DSTypography.sizeSm,
                            fontWeight: FontWeight.w700,
                          ).copyWith(
                            color: isDark
                                ? DSColors.labelPrimaryDark
                                : DSColors.labelPrimary,
                          ),
                    ),
                  ),
                  DSSpacing.wSm,
                  if (isValidated) _PayBadge(isWithPay: isWithPay),
                ],
              ),
            ),

            ...typedAttempts.asMap().entries.map((entry) {
              final idx = entry.key;
              final attempt = Map<String, dynamic>.from(entry.value);
              final attemptNum =
                  (attempt['attempt'] as num?)?.toInt() ?? (idx + 1);
              final label = _ordinal(attemptNum);
              final reason = attempt['reason']?.toString() ?? '';
              final timestamp =
                  (attempt['timestamp'] ?? attempt['attempted_at'])
                      ?.toString() ??
                  '';

              return DSInfoTile(
                label: label,
                value: reason.isNotEmpty ? reason : 'No reason provided',
                padding: const EdgeInsets.symmetric(
                  horizontal: DSSpacing.base,
                  vertical: DSSpacing.md,
                ),
                icon: Icons.access_time_rounded,
                accentColor: DSColors.warning,
                onTap: () {}, // Make it feel interactive
                showDivider: idx < typedAttempts.length - 1,
              );
            }),
          ],
        ),
      ),
    );
  }

  static String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th Attempt';
    switch (n % 10) {
      case 1:
        return '${n}st Attempt';
      case 2:
        return '${n}nd Attempt';
      case 3:
        return '${n}rd Attempt';
      default:
        return '${n}th Attempt';
    }
  }

  // ─── Delivery details card ────────────────────────────────────────────────

  Widget _buildDeliveryDetailsCard(bool isDark) {
    final rows = <Widget>[];

    void addRow(String label, String raw, {bool isLast = false}) {
      final v = raw.isNotEmpty
          ? (label == 'Product' || label == 'Transmittal' || label == 'TAT'
                ? formatDate(raw)
                : raw)
          : '';
      if (v.isEmpty) return;
      rows.add(DSInfoTile(label: label, value: v, showDivider: !isLast));
    }

    if (_str('product').isNotEmpty) addRow('Product', _str('product'));
    if (_str('special_instruction').isNotEmpty) {
      addRow('Instructions', _str('special_instruction'));
    }
    if (_str('remarks').isNotEmpty) {
      addRow('Remarks', _str('remarks'));
    }
    if (_str('transmittal_date').isNotEmpty) {
      addRow('Transmittal', _str('transmittal_date'));
    }
    if (_str('tat').isNotEmpty) addRow('TAT', _str('tat'));

    // Ensure the last row doesn't have a divider
    if (rows.isNotEmpty) {
      final last = rows.last;
      if (last is DSInfoTile) {
        rows[rows.length - 1] = DSInfoTile(
          label: last.label,
          value: last.value,
          icon: last.icon,
          onTap: last.onTap,
          onLongPress: last.onLongPress,
          accentColor: last.accentColor,
          padding: last.padding,
          showDivider: false,
        );
      }
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: DSSpacing.base),
      child: DSCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DSSectionHeader(title: 'Delivery Details'),
            ...rows,
          ],
        ),
      ),
    );
  }

  // ─── History timeline ─────────────────────────────────────────────────────

  Widget _buildTimeline(bool isDark) {
    if (!kAppDebugMode) return const SizedBox.shrink();

    final history = _delivery['delivery_trans_history'];
    if (history is! List || history.isEmpty) return const SizedBox.shrink();

    final items = List<Map<String, dynamic>>.from(
      history.whereType<Map<String, dynamic>>(),
    ).reversed.toList();

    return Padding(
      padding: const EdgeInsets.only(top: DSSpacing.base),
      child: DSCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DSSectionHeader(title: 'History (Debug)'),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                final isLast = i == items.length - 1;
                return _TimelineItem(
                  item: item,
                  isFirst: i == 0,
                  isLast: isLast,
                  isDark: isDark,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pay badge (shared)
// ─────────────────────────────────────────────────────────────────────────────

class _PayBadge extends StatelessWidget {
  const _PayBadge({required this.isWithPay});
  final bool isWithPay;

  @override
  Widget build(BuildContext context) {
    final bgColor = (isWithPay ? DSColors.success : DSColors.error).withValues(
      alpha: DSStyles.alphaSoft,
    );
    final borderColor = (isWithPay ? DSColors.success : DSColors.error)
        .withValues(alpha: DSStyles.alphaBorder);
    final dotColor = isWithPay ? DSColors.success : DSColors.error;
    final textColor = isWithPay ? DSColors.success : DSColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DSSpacing.sm,
        vertical: DSSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(DSStyles.radiusBadge),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            isWithPay ? 'WITH PAY' : 'NO PAY',
            style: DSTypography.labelCaps.copyWith(
              color: textColor,
              fontSize: 9,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// Legacy row components removed. Used DSInfoTile and DSCard instead.

// ─────────────────────────────────────────────────────────────────────────────
// Timeline item — redesigned
// ─────────────────────────────────────────────────────────────────────────────

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.item,
    required this.isFirst,
    required this.isLast,
    required this.isDark,
  });

  final Map<String, dynamic> item;
  final bool isFirst;
  final bool isLast;
  final bool isDark;

  IconData _iconFor(String action) {
    return switch (action.toLowerCase()) {
      'dispatched' => Icons.near_me_rounded,
      'received_by_courier' || 'received' => Icons.move_to_inbox_rounded,
      'delivered' => Icons.check_circle_rounded,
      'attempted' => Icons.redo_rounded,
      'failed_delivery' => Icons.keyboard_return_rounded,
      'osa' => Icons.inventory_2_rounded,
      _ => Icons.radio_button_unchecked_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final action = item['action']?.toString() ?? '';
    final timestamp = item['timestamp']?.toString() ?? '';
    final note = item['note']?.toString() ?? '';
    final status = item['status']?.toString() ?? '';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Spine
          SizedBox(
            width: 52,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(
                    top: DSSpacing.md,
                    left: DSSpacing.base,
                  ),
                  decoration: BoxDecoration(
                    color: isFirst
                        ? DSColors.primary
                        : (isDark
                              ? DSColors.white.withValues(
                                  alpha: DSStyles.alphaSoft,
                                )
                              : DSColors.secondarySurfaceLight),
                    shape: BoxShape.circle,
                    boxShadow: isFirst
                        ? [
                            BoxShadow(
                              color: DSColors.primary.withValues(
                                alpha: DSStyles.alphaDarkShadow,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    _iconFor(action),
                    size: DSIconSize.sm,
                    color: isFirst
                        ? DSColors.white
                        : (isDark
                              ? DSColors.labelSecondaryDark
                              : DSColors.labelSecondary),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.only(left: DSSpacing.base),
                      color: isDark
                          ? DSColors.separatorDark
                          : DSColors.separatorLight,
                    ),
                  ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                DSSpacing.sm,
                DSSpacing.md,
                DSSpacing.base,
                DSSpacing.base,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          action.toDisplayStatus(),
                          style: DSTypography.body(
                            color: isFirst
                                ? DSColors.primary
                                : (isDark
                                      ? DSColors.labelPrimaryDark
                                      : DSColors.labelPrimary),
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (status.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DSSpacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: (isDark ? DSColors.white : DSColors.black)
                                .withValues(alpha: DSStyles.alphaSoft),
                            borderRadius: BorderRadius.circular(
                              DSStyles.radiusBadge,
                            ),
                          ),
                          child: Text(
                            status.toDisplayStatus(),
                            style:
                                DSTypography.caption(
                                  color: isDark
                                      ? DSColors.labelSecondaryDark
                                      : DSColors.labelSecondary,
                                ).copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: DSTypography.lsExtraLoose,
                                ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatDate(timestamp, includeTime: true),
                    style:
                        DSTypography.caption(
                          fontSize: DSTypography.sizeSm,
                          fontWeight: FontWeight.w500,
                        ).copyWith(
                          color: isDark
                              ? DSColors.labelSecondaryDark
                              : DSColors.labelSecondary,
                        ),
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      note,
                      style: DSTypography.body(
                        color: isDark
                            ? DSColors.labelPrimaryDark.withValues(
                                alpha: DSStyles.alphaGlass,
                              )
                            : DSColors.labelPrimary.withValues(
                                alpha: DSStyles.alphaGlass,
                              ),
                      ).copyWith(fontSize: DSTypography.sizeMd),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Offline banner
// ─────────────────────────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: DSSpacing.base,
        vertical: 9,
      ),
      color: DSColors.pending,
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: DSIconSize.xs, color: DSColors.white),
          DSSpacing.wSm,
          Text(
            'Offline — showing locally saved data',
            style: DSTypography.caption(
              fontSize: DSTypography.sizeSm,
              fontWeight: FontWeight.w600,
            ).copyWith(color: DSColors.white),
          ),
        ],
      ),
    );
  }
}
