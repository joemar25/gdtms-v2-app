import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/api/api_result.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/database/sync_operations_dao.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';
import 'package:fsi_courier_app/shared/helpers/string_helper.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';
import 'package:fsi_courier_app/core/constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens
// ─────────────────────────────────────────────────────────────────────────────

class _DS {
  // Radii
  static const double radiusSheet = 28;
  static const double radiusCard = 20;
  static const double radiusBadge = 10;
  static const double radiusButton = 16;
  static const double radiusIcon = 14;

  // Spacing
  static const double spacingXS = 4;
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

  static const TextStyle bodyBold = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle title = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );

  static const TextStyle headline = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
  );

  // Colors (light)
  static const Color bg = Color(0xFFF2F2F7);
  static const Color surface = Colors.white;
  static const Color separator = Color(0xFFE5E5EA);
  static const Color labelPrimary = Color(0xFF1C1C1E);
  static const Color labelSecondary = Color(0xFF8E8E93);
  static const Color labelTertiary = Color(0xFFC7C7CC);
  static const Color accent = Color(0xFF00C853); // FSI green
  static const Color accentBlue = Color(0xFF007AFF);
  static const Color destructive = Color(0xFFFF3B30);

  // Colors (dark)
  static const Color bgDark = Color(0xFF000000);
  static const Color surfaceDark = Color(0xFF1C1C1E);
  static const Color surfaceDark2 = Color(0xFF2C2C2E);
  static const Color separatorDark = Color(0xFF38383A);
  static const Color labelPrimaryDark = Color(0xFFFFFFFF);
  static const Color labelSecondaryDark = Color(0xFF8E8E93);
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

  final encodedMsg =
      messageTemplate != null ? Uri.encodeComponent(messageTemplate) : null;

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
  ];

  final noPlus = cleaned.replaceAll('+', '');
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
      label: 'Viber',
      icon: Icons.videocam_rounded,
      color: const Color(0xFF7360F2),
      uri: Uri.parse(
        encodedMsg != null
            ? 'viber://chat?number=$noPlus&text=$encodedMsg'
            : 'viber://chat?number=$noPlus',
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
                borderRadius: BorderRadius.circular(2),
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
                borderRadius: BorderRadius.circular(17),
                boxShadow: [
                  BoxShadow(
                    color: app.color.withValues(alpha: 0.35),
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

    final local =
        await LocalDeliveryDao.instance.getByBarcode(widget.barcode);
    final pendingSync =
        await SyncOperationsDao.instance.hasPendingSync(widget.barcode);

    if (!mounted) return;
    if (local != null) {
      _delivery = local.toDeliveryMap();
      _isOfflineMode = true;
    }
    setState(() {
      _hasPendingSync = pendingSync;
      _loading = false;
    });
  }

  // ─── Actions (logic unchanged) ────────────────────────────────────────────

  Future<void> _onPhoneTap(String? phone) async {
    if (!mounted) return;
    final barcode = widget.barcode;
    final name = _str('name');
    final template =
        'Hi${name.isNotEmpty ? ' ${name.split(' ').first}' : ''}! '
        "I'm your FSI courier "
        '${barcode.isNotEmpty ? 'with tracking number $barcode' : 'with your delivery'}. '
        'Please be ready or contact me for re-scheduling. Thank you!';
    await showContactAppSheet(context, phone ?? '', messageTemplate: template);
  }

  Future<void> _launchMaps(String? address) async {
    final destination = address?.trim() ?? '';
    if (destination.isEmpty) return;
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(destination)}';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  // ─── Helpers (unchanged) ──────────────────────────────────────────────────

  String _str(String key) => _delivery[key]?.toString().trim() ?? '';

  bool get _isRtsLocked {
    final status = _str('delivery_status').toUpperCase();
    if (status != 'RTS') return false;
    final rtsStatus =
        _delivery['rts_verification_status']?.toString() ?? 'unvalidated';
    return rtsStatus == 'verified_with_pay' || rtsStatus == 'verified_no_pay';
  }

  String get _rtsVerifStatus =>
      _delivery['rts_verification_status']?.toString() ?? 'unvalidated';

  bool get _canShowContactInfo {
    final s = _str('delivery_status').toUpperCase();
    if (s == 'PENDING') return true;
    if (s == 'RTS' && !_isRtsLocked) return true;
    return false;
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(deliveryRefreshProvider, (_, __) => _load());

    final status = _str('delivery_status').toUpperCase();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? _DS.bgDark : _DS.bg;

    // RULE: If status is 'OSA', do not ever show update status button here.
    // NEW RULE: If status is 'RTS' and already verified, hide the button.
    final showFab = (status == 'PENDING' || status == 'RTS') && !_isRtsLocked;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(context, status, isDark),
      floatingActionButton: showFab
          ? FloatingActionButton.extended(
              onPressed: _hasPendingSync
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      context.push('/deliveries/${widget.barcode}/update');
                    },
              backgroundColor:
                  _hasPendingSync ? _DS.labelSecondary : _DS.accent,
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
                      padding: const EdgeInsets.fromLTRB(
                        _DS.spacingMD,
                        _DS.spacingSM,
                        _DS.spacingMD,
                        _DS.spacingXL,
                      ),
                      children: [
                        // ── Account details card ──────────────────────────
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
                              ),
                              // Address and contact are only shown when delivery
                              // is still actionable (PENDING or unverified RTS).
                              if (_canShowContactInfo) ...[
                                _IosRowDivider(isDark: isDark),
                                _IosTappableRow(
                                  label: 'Address',
                                  value: _str('address'),
                                  icon: Icons.map_rounded,
                                  accentColor: _DS.accentBlue,
                                  onTap: () => _launchMaps(_str('address')),
                                  isDark: isDark,
                                ),
                                _IosRowDivider(isDark: isDark),
                                _IosTappableRow(
                                  label: 'Contact',
                                  value: _str('contact'),
                                  icon: Icons.phone_rounded,
                                  accentColor: _DS.accent,
                                  onTap: () => _onPhoneTap(_str('contact')),
                                  isDark: isDark,
                                ),
                              ],
                            ],
                          ),
                        ),

                        // ── Delivery details (most important, always on top) ──
                        _buildDeliveryDetailsCard(isDark),

                        // ── Proof of delivery ─────────────────────────────
                        _buildDeliveredDetails(isDark),

                        // ── RTS attempts ──────────────────────────────────
                        _buildRtsAttempts(isDark),

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

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    String status,
    bool isDark,
  ) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: !_loading
          ? Row(
              children: [
                Text(
                  widget.barcode,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 10),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pay-status dot for validated RTS
                      if (status == 'RTS' && _isRtsLocked) ...[
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _rtsVerifStatus == 'verified_with_pay'
                                ? Colors.green.shade500
                                : Colors.red.shade400,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        status.isEmpty ? 'PENDING' : status.toDisplayStatus(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: status == 'DELIVERED'
                              ? ColorStyles.grabGreen
                              : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Mail type badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _str('mail_type'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey,
                    ),
                  ),
                ),
              ],
            )
          : Text(
              widget.barcode,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
    );
  }


  // ─── Proof of delivery (all conditions preserved) ─────────────────────────

  Widget _buildDeliveredDetails(bool isDark) {
    // Proof of Delivery is only meaningful for delivered items — RTS/OSA were
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

    final hasAny = authRep.isNotEmpty ||
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
            ),
          ],
          if (authRep.isNotEmpty) ...[
            _IosRowDivider(isDark: isDark),
            _IosRow(
              label: 'Authorized Rep',
              value: authRep,
              isDark: isDark,
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
              value: contactRep,
              icon: Icons.phone_rounded,
              accentColor: _DS.accent,
              onTap: () => _onPhoneTap(contactRep),
              isDark: isDark,
            ),
          ],
          if (placementType.isNotEmpty && relationship.isEmpty) ...[
            _IosRowDivider(isDark: isDark),
            _IosRow(
              label: 'Placement',
              value: placementType,
              isDark: isDark,
            ),
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

  // ─── RTS attempts (all conditions preserved) ──────────────────────────────

  Widget _buildRtsAttempts(bool isDark) {
    final attempts = _delivery['rts_attempts'];
    if (attempts is! List || attempts.isEmpty) return const SizedBox.shrink();

    final typedAttempts = attempts.whereType<Map>().toList();
    if (typedAttempts.isEmpty) return const SizedBox.shrink();

    final rtsVerifStatus =
        _delivery['rts_verification_status']?.toString() ?? 'unvalidated';
    final isWithPay = rtsVerifStatus == 'verified_with_pay';
    final isValidated = isWithPay || rtsVerifStatus == 'verified_no_pay';

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
                      'RETURN ATTEMPTS',
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
                            .withValues(alpha: 0.08),
                        borderRadius:
                            BorderRadius.circular(_DS.radiusBadge),
                      ),
                      child: Text(
                        '${typedAttempts.length}',
                        style: _DS.micro.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? _DS.labelPrimaryDark
                              : _DS.labelPrimary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (isValidated)
                      _PayBadge(isWithPay: isWithPay),
                  ],
                ),
              ),

              ...typedAttempts.asMap().entries.map((entry) {
                final idx = entry.key;
                final attempt =
                    Map<String, dynamic>.from(entry.value);
                final attemptNum =
                    (attempt['attempt'] as num?)?.toInt() ??
                        (idx + 1);
                final label = _ordinal(attemptNum);
                final reason =
                    attempt['reason']?.toString() ?? '';
                final timestamp =
                    (attempt['timestamp'] ?? attempt['attempted_at'])
                            ?.toString() ??
                        '';
                // Attempt images hidden for privacy (ENH-006)

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
                              color: Colors.orange
                                  .withValues(alpha: 0.12),
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
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                if (timestamp.isNotEmpty)
                                  Text(
                                    formatDate(
                                      timestamp,
                                      includeTime: true,
                                    ),
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
          ? (label == 'Job Order' ||
                  label == 'Transmittal' ||
                  label == 'TAT'
              ? formatDate(raw)
              : raw)
          : '';
      if (v.isEmpty) return;
      if (rows.isNotEmpty) rows.add(_IosRowDivider(isDark: isDark));
      rows.add(_IosRow(label: label, value: v, isDark: isDark));
    }

    if (_str('job_order').isNotEmpty) addRow('Job Order', _str('job_order'));
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
            _CardSectionHeader(label: 'History', isDark: isDark),
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
    final bgColor = isWithPay
        ? Colors.teal.shade50
        : Colors.red.shade50;
    final borderColor = isWithPay
        ? Colors.teal.shade200
        : Colors.red.shade200;
    final dotColor = isWithPay
        ? Colors.green.shade500
        : Colors.red.shade400;
    final textColor = isWithPay
        ? Colors.teal.shade700
        : Colors.red.shade600;

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
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
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
  const _IosCard({
    required this.child,
    required this.isDark,
  });
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
            color:
                Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
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

class _IosRow extends StatelessWidget {
  const _IosRow({
    required this.label,
    required this.value,
    required this.isDark,
    this.bold = false,
  });
  final String label;
  final String value;
  final bool isDark;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
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
              label,
              style: _DS.bodyMedium.copyWith(
                color:
                    isDark ? _DS.labelSecondaryDark : _DS.labelSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: _DS.bodyMedium.copyWith(
                fontSize: 14,
                fontWeight:
                    bold ? FontWeight.w700 : FontWeight.w500,
                color: isDark
                    ? _DS.labelPrimaryDark
                    : _DS.labelPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IosTappableRow extends StatelessWidget {
  const _IosTappableRow({
    required this.label,
    required this.value,
    required this.isDark,
    required this.icon,
    required this.accentColor,
    this.onTap,
  });

  final String label;
  final String value;
  final bool isDark;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap?.call();
        },
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
                  label,
                  style: _DS.bodyMedium.copyWith(
                    color: isDark
                        ? _DS.labelSecondaryDark
                        : _DS.labelSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: _DS.bodyMedium.copyWith(
                    fontSize: 14,
                    color: accentColor,
                  ),
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 13, color: accentColor),
              ),
            ],
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
      'rts' => Icons.keyboard_return_rounded,
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
                    top: 12,
                    left: _DS.spacingMD,
                  ),
                  decoration: BoxDecoration(
                    color: isFirst
                        ? _DS.accent
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.grey.shade100),
                    shape: BoxShape.circle,
                    boxShadow: isFirst
                        ? [
                            BoxShadow(
                              color: _DS.accent.withValues(alpha: 0.3),
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
                        : (isDark
                            ? Colors.white38
                            : Colors.grey.shade400),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.only(left: _DS.spacingMD),
                      color: isDark
                          ? Colors.white12
                          : Colors.grey.shade200,
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
                                .withValues(alpha: 0.06),
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
                            ? _DS.labelPrimaryDark.withValues(alpha: 0.75)
                            : _DS.labelPrimary.withValues(alpha: 0.75),
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
          const Icon(
            Icons.wifi_off_rounded,
            size: 13,
            color: Colors.white,
          ),
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