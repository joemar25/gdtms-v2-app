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
import 'package:fsi_courier_app/design_system/design_system.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Local design tokens for DeliveryDetailScreen.
// Typography, spacing, and radii are screen-local.
// Background/surface constants delegate to ColorStyles — do NOT duplicate.
// ─────────────────────────────────────────────────────────────────────────────

class _DS {
  // Radii
  static const double radiusSheet = 28;
  static const double radiusCard = 20;
  static const double radiusBadge = 10;
  // Spacing
  static const double spacingSM = 8;
  static const double spacingMD = 16;
  static const double spacingLG = 24;
  static const double spacingXL = 32;

  // Typography
  static const TextStyle labelCaps = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
  );

  static const TextStyle micro = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle headline = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
  );

  // ── Colors ────────────────────────────────────────────────────────────────
  // Background: use [ColorStyles] tokens — do NOT hardcode raw Color() values.
  // These aliases keep existing references compiling while pointing to the
  // single source of truth.
  static const Color surface = DSColors.white; // light card surface
  static const Color surfaceDark = DSColors.cardDark; // dark card surface

  // Dividers / separators
  static const Color separator = Color(0xFFE5E5EA);
  static const Color separatorDark = Color(0xFF38383A);

  // Text labels — these are intentional iOS-style greys, kept local.
  static const Color labelPrimary = Color(0xFF1C1C1E);
  static const Color labelSecondary = Color(0xFF8E8E93);
  static const Color labelPrimaryDark = Color(0xFFFFFFFF);
  static const Color labelSecondaryDark = Color(0xFF8E8E93);

  // FSI brand accent (green CTA) and action blue — local aliases.
  static const Color accent = DSColors.primary;
  static const Color accentBlue = DSColors.systemBlue;
}

// ─────────────────────────────────────────────────────────────────────────────
// Contact App Sheet — premium redesign (logic unchanged)
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showContactAppSheet(
  BuildContext context,
  String phone, {
  String? messageTemplate,
}) async {
  final cleaned = phone.trim();
  if (cleaned.isEmpty) return;
  final noPlus = cleaned.replaceAll('+', '');

  final encodedMsg = messageTemplate != null
      ? Uri.encodeComponent(messageTemplate)
      : null;

  final apps = <_CommApp>[
    _CommApp(
      label: 'SMS',
      icon: Icons.message_rounded,
      color: const Color(0xFF34C759),
      uri: encodedMsg != null
          ? Uri.parse('sms:$cleaned?body=$encodedMsg')
          : Uri(scheme: 'sms', path: cleaned),
    ),
    _CommApp(
      label: 'Call',
      icon: Icons.phone_rounded,
      color: const Color(0xFF007AFF),
      uri: Uri(scheme: 'tel', path: cleaned),
    ),
    _CommApp(
      label: 'Viber',
      icon: Icons.chat_bubble_rounded,
      color: const Color(0xFF7360F2),
      uri: Uri.parse(
        encodedMsg != null
            ? 'viber://chat?number=$noPlus&text=$encodedMsg'
            : 'viber://chat?number=$noPlus',
      ),
    ),
  ];

  final optionalCandidates = [
    _CommApp(
      label: 'WhatsApp',
      icon: Icons.chat_bubble_rounded,
      color: const Color(0xFF25D366),
      uri: Uri.parse(
        encodedMsg != null
            ? 'whatsapp://send?phone=$noPlus&text=$encodedMsg'
            : 'whatsapp://send?phone=$noPlus',
      ),
    ),
    _CommApp(
      label: 'Telegram',
      icon: Icons.near_me_rounded,
      color: const Color(0xFF229ED9),
      uri: Uri.parse('tg://resolve?phone=$cleaned'),
    ),
  ];

  for (final app in optionalCandidates) {
    if (await canLaunchUrl(app.uri)) {
      apps.add(app);
    }
  }

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _ContactAppSheet(phone: cleaned, apps: apps),
  );
}

class _CommApp {
  const _CommApp({
    required this.label,
    required this.icon,
    required this.color,
    required this.uri,
  });
  final String label;
  final IconData icon;
  final Color color;
  final Uri uri;
}

class _ContactAppSheet extends StatelessWidget {
  const _ContactAppSheet({required this.phone, required this.apps});
  final String phone;
  final List<_CommApp> apps;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? _DS.surfaceDark : _DS.surface;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(_DS.radiusSheet),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        _DS.spacingLG,
        12,
        _DS.spacingLG,
        _DS.spacingLG + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: _DS.spacingMD),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: DSStyles.pillRadius,
              ),
            ),
          ),

          // Label + number
          Text(
            'Contact',
            style: _DS.labelCaps.copyWith(
              color: isDark ? _DS.labelSecondaryDark : _DS.labelSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            phone,
            style: _DS.headline.copyWith(
              color: isDark ? _DS.labelPrimaryDark : _DS.labelPrimary,
            ),
          ),
          const SizedBox(height: _DS.spacingLG),

          // App grid
          Wrap(
            spacing: _DS.spacingMD,
            runSpacing: _DS.spacingMD,
            children: apps
                .map(
                  (app) => _AppTile(
                    app: app,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      HapticFeedback.lightImpact();
                      launchUrl(app.uri, mode: LaunchMode.externalApplication);
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({
    required this.app,
    required this.onTap,
    required this.isDark,
  });
  final _CommApp app;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: app.color,
                borderRadius: DSStyles.cardRadius,
                boxShadow: [
                  BoxShadow(
                    color: app.color.withValues(
                      alpha: DSStyles.alphaDarkShadow,
                    ),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(app.icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              app.label,
              textAlign: TextAlign.center,
              style: _DS.micro.copyWith(
                color: isDark ? _DS.labelPrimaryDark : _DS.labelPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
          SnackBar(
            content: Text(reason),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
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
        backgroundColor: Colors.transparent,
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
                  ? _DS.labelSecondary
                  : _DS.accent,
              elevation: _hasPendingSync ? 0 : 6,
              icon: _hasPendingSync
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    )
                  : const Icon(Icons.edit_rounded, color: Colors.white),
              label: Text(
                _hasPendingSync ? 'SYNC PENDING…' : 'UPDATE STATUS',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.6,
                ),
              ),
            )
          : null,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _DS.accent,
              ),
            )
          : Column(
              children: [
                if (_isOfflineMode) const _OfflineBanner(),
                Expanded(
                  child: RefreshIndicator(
                    color: _DS.accent,
                    onRefresh: _load,
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        _DS.spacingMD,
                        _DS.spacingSM,
                        _DS.spacingMD,
                        showFab
                            ? _DS.spacingXL +
                                  88.0 +
                                  MediaQuery.of(context).padding.bottom
                            : _DS.spacingXL,
                      ),
                      children: [
                        // ── Account details card ──────────────────────────
                        if (!checkIsLockedFromMap(_delivery))
                          _IosCard(
                            isDark: isDark,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _CardSectionHeader(
                                  label: 'Account Details',
                                  isDark: isDark,
                                ),
                                _IosRow(
                                  label: 'Name',
                                  value: _str('name'),
                                  bold: true,
                                  isDark: isDark,
                                  onLongPress: () =>
                                      _copyToClipboard(_str('name'), 'Name'),
                                ),
                                // ── Piece count badge (barcode with "/") ─────
                                if (_pieceCountFromBarcode > 0) ...[
                                  _IosRowDivider(isDark: isDark),
                                  _IosRow(
                                    label: 'Pieces',
                                    value:
                                        '$_pieceCountFromBarcode piece${_pieceCountFromBarcode > 1 ? 's' : ''} in this bundle',
                                    isDark: isDark,
                                  ),
                                ],
                                // Address and contact are only shown when delivery
                                // is still actionable (PENDING or unverified FAILED_DELIVERY).
                                if (_canShowContactInfo) ...[
                                  _IosRowDivider(isDark: isDark),
                                  _IosTappableRow(
                                    label: 'Address',
                                    value: _str('address'),
                                    icon: Icons.map_rounded,
                                    accentColor: _DS.accentBlue,
                                    onTap: () => _launchMaps(_str('address')),
                                    onLongPress: () => _copyToClipboard(
                                      _str('address'),
                                      'Address',
                                    ),
                                    isDark: isDark,
                                  ),
                                  _IosRowDivider(isDark: isDark),
                                  _IosTappableRow(
                                    label: 'Contact',
                                    value: _str('contact').cleanContactNumber(),
                                    icon: Icons.phone_rounded,
                                    accentColor: _DS.accent,
                                    onTap: () => _onPhoneTap(
                                      _str('contact').cleanContactNumber(),
                                    ),
                                    onLongPress: () => _copyToClipboard(
                                      _str('contact').cleanContactNumber(),
                                      'Contact',
                                    ),
                                    isDark: isDark,
                                  ),
                                  // _IosRowDivider(isDark: isDark),
                                  // _IosTappableRow(
                                  //   label: 'Viber',
                                  //   value: _str('contact').cleanContactNumber(),
                                  //   icon: Icons.chat_bubble_rounded,
                                  //   accentColor: const Color(0xFF7360F2),
                                  //   onTap: () => _onViberTap(
                                  //     _str('contact').cleanContactNumber(),
                                  //   ),
                                  //   isDark: isDark,
                                  // ),
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
          )
        : Text(
            widget.barcode,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
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
      padding: const EdgeInsets.only(top: _DS.spacingMD),
      child: _IosCard(
        isDark: isDark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardSectionHeader(label: 'Proof of Delivery', isDark: isDark),
            if (recipient.isNotEmpty) ...[
              _IosRow(
                label: 'Received By',
                value: recipient,
                bold: true,
                isDark: isDark,
                onLongPress: () =>
                    _copyToClipboard(recipient, 'Recipient Name'),
              ),
            ],
            if (authRep.isNotEmpty) ...[
              _IosRowDivider(isDark: isDark),
              _IosRow(
                label: 'Authorized Rep',
                value: authRep,
                isDark: isDark,
                onLongPress: () =>
                    _copyToClipboard(authRep, 'Authorized Rep Name'),
              ),
            ],
            if (relationship.isNotEmpty) ...[
              _IosRowDivider(isDark: isDark),
              _IosRow(
                label: 'Relationship',
                value: relationship,
                isDark: isDark,
              ),
            ],
            // Do not expose auth-rep contact number after delivery is complete.
            if (contactRep.isNotEmpty &&
                _str('delivery_status').toUpperCase() != 'DELIVERED') ...[
              _IosRowDivider(isDark: isDark),
              _IosTappableRow(
                label: 'Contact',
                value: contactRep.cleanContactNumber(),
                icon: Icons.phone_rounded,
                accentColor: _DS.accent,
                onTap: () => _onPhoneTap(
                  contactRep.cleanContactNumber(),
                  targetName: authRep,
                ),
                onLongPress: () => _copyToClipboard(
                  contactRep.cleanContactNumber(),
                  'Rep Contact',
                ),
                isDark: isDark,
              ),
            ],
            if (placementType.isNotEmpty && relationship.isEmpty) ...[
              _IosRowDivider(isDark: isDark),
              _IosRow(label: 'Placement', value: placementType, isDark: isDark),
            ],
            if (note.isNotEmpty) ...[
              _IosRowDivider(isDark: isDark),
              _IosRow(label: 'Note', value: note, isDark: isDark),
            ],
            if (transactionDateToShow.isNotEmpty) ...[
              _IosRowDivider(isDark: isDark),
              _IosRow(
                label: 'Transaction',
                value: transactionDateToShow,
                isDark: isDark,
              ),
            ],
            if (deliveredDateToShow.isNotEmpty) ...[
              _IosRowDivider(isDark: isDark),
              _IosRow(
                label: 'Delivered',
                value: deliveredDateToShow,
                isDark: isDark,
              ),
            ],
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
      padding: const EdgeInsets.only(top: _DS.spacingMD),
      child: _IosCard(
        isDark: isDark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with pay-status badge
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _DS.spacingMD,
                _DS.spacingMD,
                _DS.spacingMD,
                _DS.spacingSM,
              ),
              child: Row(
                children: [
                  Text(
                    'DELIVERY ATTEMPTS',
                    style: _DS.labelCaps.copyWith(
                      color: isDark
                          ? _DS.labelSecondaryDark
                          : _DS.labelSecondary,
                    ),
                  ),
                  const SizedBox(width: _DS.spacingSM),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : _DS.labelPrimary)
                          .withValues(alpha: DSStyles.alphaSoft),
                      borderRadius: BorderRadius.circular(_DS.radiusBadge),
                    ),
                    child: Text(
                      '${typedAttempts.length}',
                      style: _DS.micro.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? _DS.labelPrimaryDark : _DS.labelPrimary,
                      ),
                    ),
                  ),
                  const Spacer(),
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

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IosRowDivider(isDark: isDark),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _DS.spacingMD,
                      10,
                      _DS.spacingMD,
                      10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(
                              alpha: DSStyles.alphaActiveAccent,
                            ),
                            borderRadius: BorderRadius.circular(
                              _DS.radiusBadge,
                            ),
                          ),
                          child: Text(
                            label,
                            style: _DS.micro.copyWith(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: _DS.spacingSM),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (timestamp.isNotEmpty)
                                Text(
                                  formatDate(timestamp, includeTime: true),
                                  style: _DS.micro.copyWith(
                                    color: isDark
                                        ? _DS.labelSecondaryDark
                                        : _DS.labelSecondary,
                                  ),
                                ),
                              if (reason.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  reason,
                                  style: _DS.bodyMedium.copyWith(
                                    color: isDark
                                        ? _DS.labelPrimaryDark
                                        : _DS.labelPrimary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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

    void addRow(String label, String raw, {bool includeTime = false}) {
      final v = raw.isNotEmpty
          ? (label == 'Product' || label == 'Transmittal' || label == 'TAT'
                ? formatDate(raw)
                : raw)
          : '';
      if (v.isEmpty) return;
      if (rows.isNotEmpty) rows.add(_IosRowDivider(isDark: isDark));
      rows.add(_IosRow(label: label, value: v, isDark: isDark));
    }

    if (_str('product').isNotEmpty) addRow('Product', _str('product'));
    // dispatch_code intentionally hidden from delivery views (ENH-005)
    if (_str('special_instruction').isNotEmpty) {
      if (rows.isNotEmpty) rows.add(_IosRowDivider(isDark: isDark));
      rows.add(
        _IosRow(
          label: 'Instructions',
          value: _str('special_instruction'),
          isDark: isDark,
        ),
      );
    }
    if (_str('remarks').isNotEmpty) {
      if (rows.isNotEmpty) rows.add(_IosRowDivider(isDark: isDark));
      rows.add(
        _IosRow(label: 'Remarks', value: _str('remarks'), isDark: isDark),
      );
    }
    if (_str('transmittal_date').isNotEmpty) {
      addRow('Transmittal', _str('transmittal_date'));
    }
    if (_str('tat').isNotEmpty) addRow('TAT', _str('tat'));

    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: _DS.spacingMD),
      child: _IosCard(
        isDark: isDark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardSectionHeader(label: 'Delivery Details', isDark: isDark),
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
      padding: const EdgeInsets.only(top: _DS.spacingMD),
      child: _IosCard(
        isDark: isDark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardSectionHeader(label: 'History (Debug)', isDark: isDark),
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
    final bgColor = isWithPay ? Colors.teal.shade50 : Colors.red.shade50;
    final borderColor = isWithPay ? Colors.teal.shade200 : Colors.red.shade200;
    final dotColor = isWithPay ? Colors.green.shade500 : Colors.red.shade400;
    final textColor = isWithPay ? Colors.teal.shade700 : Colors.red.shade600;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(_DS.radiusBadge),
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
            style: _DS.labelCaps.copyWith(
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

// ─────────────────────────────────────────────────────────────────────────────
// iOS-style grouped card
// ─────────────────────────────────────────────────────────────────────────────

class _IosCard extends StatelessWidget {
  const _IosCard({required this.child, required this.isDark});
  final Widget child;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? _DS.surfaceDark : _DS.surface,
        borderRadius: BorderRadius.circular(_DS.radiusCard),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_DS.radiusCard),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card section header
// ─────────────────────────────────────────────────────────────────────────────

class _CardSectionHeader extends StatelessWidget {
  const _CardSectionHeader({required this.label, required this.isDark});
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _DS.spacingMD,
        _DS.spacingMD,
        _DS.spacingMD,
        _DS.spacingSM,
      ),
      child: Text(
        label.toUpperCase(),
        style: _DS.labelCaps.copyWith(
          color: isDark ? _DS.labelSecondaryDark : _DS.labelSecondary,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// iOS-style row components
// ─────────────────────────────────────────────────────────────────────────────

class _IosRowDivider extends StatelessWidget {
  const _IosRowDivider({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: _DS.spacingMD),
      child: Divider(
        height: 0.5,
        thickness: 0.5,
        color: isDark ? _DS.separatorDark : _DS.separator,
      ),
    );
  }
}

class _IosRow extends StatefulWidget {
  const _IosRow({
    required this.label,
    required this.value,
    required this.isDark,
    this.bold = false,
    this.onLongPress,
  });

  final String label;
  final String value;
  final bool isDark;
  final bool bold;
  final VoidCallback? onLongPress;

  @override
  State<_IosRow> createState() => _IosRowState();
}

class _IosRowState extends State<_IosRow> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.value.isEmpty) return const SizedBox.shrink();

    return AnimatedScale(
      scale: _isPressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onLongPress: widget.onLongPress != null
              ? () {
                  HapticFeedback.lightImpact();
                  widget.onLongPress?.call();
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _DS.spacingMD,
              vertical: 11,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    widget.label,
                    style: _DS.bodyMedium.copyWith(
                      color: widget.isDark
                          ? _DS.labelSecondaryDark
                          : _DS.labelSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    widget.value,
                    style: _DS.bodyMedium.copyWith(
                      fontSize: 14,
                      fontWeight: widget.bold
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: widget.isDark
                          ? _DS.labelPrimaryDark
                          : _DS.labelPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IosTappableRow extends StatefulWidget {
  const _IosTappableRow({
    required this.label,
    required this.value,
    required this.isDark,
    required this.icon,
    required this.accentColor,
    this.onTap,
    this.onLongPress,
  });

  final String label;
  final String value;
  final bool isDark;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<_IosTappableRow> createState() => _IosTappableRowState();
}

class _IosTappableRowState extends State<_IosTappableRow> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.value.isEmpty) return const SizedBox.shrink();

    return AnimatedScale(
      scale: _isPressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onTap?.call();
          },
          onLongPress: widget.onLongPress != null
              ? () {
                  HapticFeedback.lightImpact();
                  widget.onLongPress?.call();
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _DS.spacingMD,
              vertical: 11,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    widget.label,
                    style: _DS.bodyMedium.copyWith(
                      color: widget.isDark
                          ? _DS.labelSecondaryDark
                          : _DS.labelSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    widget.value,
                    style: _DS.bodyMedium.copyWith(
                      fontSize: 14,
                      color: widget.accentColor,
                    ),
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(
                      alpha: DSStyles.alphaSoft,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, size: 13, color: widget.accentColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
                  margin: const EdgeInsets.only(top: 12, left: _DS.spacingMD),
                  decoration: BoxDecoration(
                    color: isFirst
                        ? _DS.accent
                        : (isDark
                              ? Colors.white.withValues(
                                  alpha: DSStyles.alphaSoft,
                                )
                              : Colors.grey.shade100),
                    shape: BoxShape.circle,
                    boxShadow: isFirst
                        ? [
                            BoxShadow(
                              color: _DS.accent.withValues(
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
                    size: 15,
                    color: isFirst
                        ? Colors.white
                        : (isDark ? Colors.white38 : Colors.grey.shade400),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.only(left: _DS.spacingMD),
                      color: isDark ? Colors.white12 : Colors.grey.shade200,
                    ),
                  ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                _DS.spacingSM,
                12,
                _DS.spacingMD,
                16,
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
                          style: _DS.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isFirst
                                ? _DS.accent
                                : (isDark
                                      ? _DS.labelPrimaryDark
                                      : _DS.labelPrimary),
                          ),
                        ),
                      ),
                      if (status.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: DSStyles.alphaSoft),
                            borderRadius: BorderRadius.circular(
                              _DS.radiusBadge,
                            ),
                          ),
                          child: Text(
                            status.toDisplayStatus(),
                            style: _DS.labelCaps.copyWith(
                              color: isDark
                                  ? _DS.labelSecondaryDark
                                  : _DS.labelSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatDate(timestamp, includeTime: true),
                    style: _DS.micro.copyWith(
                      color: isDark
                          ? _DS.labelSecondaryDark
                          : _DS.labelSecondary,
                    ),
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      note,
                      style: _DS.body.copyWith(
                        fontSize: 13,
                        color: isDark
                            ? _DS.labelPrimaryDark.withValues(
                                alpha: DSStyles.alphaGlass,
                              )
                            : _DS.labelPrimary.withValues(
                                alpha: DSStyles.alphaGlass,
                              ),
                      ),
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
        horizontal: _DS.spacingMD,
        vertical: 9,
      ),
      color: Colors.orange.shade700,
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 13, color: Colors.white),
          const SizedBox(width: _DS.spacingSM),
          Text(
            'Offline — showing locally saved data',
            style: _DS.micro.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
