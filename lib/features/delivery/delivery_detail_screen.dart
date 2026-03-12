import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/api/api_result.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';
import 'package:fsi_courier_app/shared/helpers/string_helper.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';
import 'package:fsi_courier_app/core/config.dart';

/// Shows a bottom action sheet listing available communication apps for a phone number.
/// When [messageTemplate] is provided it is pre-filled as the message body
/// for SMS, WhatsApp, and Viber (Telegram and Call do not support pre-fill).
Future<void> showContactAppSheet(
  BuildContext context,
  String phone, {
  String? messageTemplate,
}) async {
  final cleaned = phone.trim();
  if (cleaned.isEmpty) return;

  final encodedMsg = messageTemplate != null
      ? Uri.encodeComponent(messageTemplate)
      : null;

  // SMS and Call are always shown first (no canLaunchUrl gating).
  // Optional apps (WhatsApp, Viber, Telegram) are added only if available.
  final apps = <_CommApp>[
    _CommApp(
      label: 'SMS',
      icon: Icons.sms_rounded,
      color: Colors.blueGrey,
      uri: encodedMsg != null
          ? Uri.parse('sms:$cleaned?body=$encodedMsg')
          : Uri(scheme: 'sms', path: cleaned),
    ),
    _CommApp(
      label: 'Call',
      icon: Icons.call_rounded,
      color: Colors.green,
      uri: Uri(scheme: 'tel', path: cleaned),
    ),
  ];

  final noPlus = cleaned.replaceAll('+', '');
  final optionalCandidates = [
    _CommApp(
      label: 'WhatsApp',
      icon: Icons.chat_rounded,
      color: const Color(0xFF25D366),
      uri: Uri.parse(
        encodedMsg != null
            ? 'whatsapp://send?phone=$noPlus&text=$encodedMsg'
            : 'whatsapp://send?phone=$noPlus',
      ),
    ),
    _CommApp(
      label: 'Viber',
      icon: Icons.video_call_rounded,
      color: const Color(0xFF7360F2),
      uri: Uri.parse(
        encodedMsg != null
            ? 'viber://chat?number=$noPlus&text=$encodedMsg'
            : 'viber://chat?number=$noPlus',
      ),
    ),
    _CommApp(
      label: 'Telegram',
      icon: Icons.send_rounded,
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

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
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
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'CONTACT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            phone,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: apps
                .map(
                  (app) => _AppTile(
                    app: app,
                    onTap: () {
                      Navigator.pop(context);
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
  const _AppTile({required this.app, required this.onTap});
  final _CommApp app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: app.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(app.icon, color: app.color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            app.label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    _load();
  }

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
        
        // Keep local SQLite in sync with the freshest server data.
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

    // Offline — or API call failed — fall back to local storage.
    final local = await LocalDeliveryDao.instance.getByBarcode(widget.barcode);
    if (!mounted) return;
    if (local != null) {
      _delivery = local.toDeliveryMap();
      _isOfflineMode = true;
    }
    setState(() => _loading = false);
  }

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

  String _str(String key) => _delivery[key]?.toString().trim() ?? '';

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(deliveryRefreshProvider, (_, __) => _load());
    final status = _str('delivery_status').toLowerCase();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F7);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status.isEmpty ? 'PENDING' : status.toDisplayStatus(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: status == 'delivered'
                            ? ColorStyles.grabGreen
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
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
      ),
      // RULE: If status is 'osa', do not ever show update status button here
      bottomNavigationBar: (status == 'pending' || status == 'rts')
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text(
                    'UPDATE STATUS',
                    style: TextStyle(
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
                  onPressed: () =>
                      context.push('/deliveries/${widget.barcode}/update'),
                ),
              ),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_isOfflineMode) const _OfflineBanner(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      children: [
                        // ─ Recipient ────────────────────────────────────────────
                        _DetailCard(
                          children: [
                            _DetailHeader(
                              icon: Icons.person_outline,
                              title: 'Recipient',
                            ),
                            _DetailRow(
                              label: 'Name',
                              value: _str('name'),
                              bold: true,
                            ),
                            _TappableRow(
                              label: 'Address',
                              value: _str('address'),
                              onTap: status == 'delivered'
                                  ? null
                                  : () => _launchMaps(_str('address')),
                              trailingIcon: status == 'delivered'
                                  ? null
                                  : Icons.map_outlined,
                            ),
                            // Contact number hidden once delivered — no reason
                            // to expose personal info after the parcel is done.
                            if (status != 'delivered')
                              _TappableRow(
                                label: 'Contact',
                                value: _str('contact'),
                                onTap: () => _onPhoneTap(_str('contact')),
                                trailingIcon: Icons.call_outlined,
                              ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // ─ Proof of delivery ─────────────────────────────────
                        _buildDeliveredDetails(),

                        // ─ RTS / OSA attempts ────────────────────────────────
                        _buildRtsAttempts(),

                        const SizedBox(height: 12),

                        // ─ Delivery details ──────────────────────────────────────
                        _DetailCard(
                          children: [
                            _DetailHeader(
                              icon: Icons.local_shipping_outlined,
                              title: 'Delivery Details',
                            ),
                            if (_str('job_order').isNotEmpty)
                              _DetailRow(
                                label: 'Job Order',
                                value: formatDate(_str('job_order')),
                              ),
                            // dispatch_code intentionally hidden from delivery views (ENH-005)
                            if (_str('special_instruction').isNotEmpty)
                              _DetailRow(
                                label: 'Instructions',
                                value: _str('special_instruction'),
                              ),
                            if (_str('remarks').isNotEmpty)
                              _DetailRow(
                                label: 'Remarks',
                                value: _str('remarks'),
                              ),
                            if (_str('transmittal_date').isNotEmpty)
                              _DetailRow(
                                label: 'Transmittal',
                                value: formatDate(_str('transmittal_date')),
                              ),
                            if (_str('tat').isNotEmpty)
                              _DetailRow(
                                label: 'TAT',
                                value: formatDate(_str('tat')),
                              ),
                          ],
                        ),

                        // ─ History timeline ──────────────────────────────────
                        const SizedBox(height: 12),
                        _buildTimeline(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _showFullscreenImage(String url, {String? mediaType}) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Center(
                    child: Text(
                      mediaType ?? 'Image',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Top overlay for media type and Online only
            Positioned(
              top: 24,
              left: 24,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (mediaType != null && mediaType.isNotEmpty) ...[
                        Text(
                          mediaType,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      const Text(
                        'Online only',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveredDetails() {
    final authRep = _str('authorized_rep');
    final contactRep = _str('contact_rep');
    final recipient = _str('recipient');
    var relationship = _str('relationship');
    final placementType = _str('placement_type');
    final note = _str('note');
    final transactionAt = _str('transaction_at');
    final deliveredDate = _str('delivered_date');
    final signature = _str('signature');
    final media = _delivery['media'];
    final hasMedia = media is List && (media).isNotEmpty;
    final hasSignature = signature.isNotEmpty;
    final isOffline = _isOfflineMode;
    // Privacy: Hide images if delivered and not in debug mode
    final isDelivered = _str('delivery_status').toLowerCase() == 'delivered';
    final showMedia = !isDelivered || kAppDebugMode;

    // Relationship transformation
    if (relationship.isNotEmpty) {
      // If self, transform to Owner
      if (relationship.toLowerCase() == 'self') {
        relationship = 'Owner';
      } else {
        // Capitalize first letter
        relationship =
            relationship[0].toUpperCase() + relationship.substring(1);
      }
      // Append placement type if available
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
        deliveredDateToShow.isNotEmpty ||
        hasMedia ||
        hasSignature;

    if (!hasAny) return const SizedBox.shrink();

    return _DetailCard(
      children: [
        _DetailHeader(
          icon: Icons.verified_outlined,
          title: 'Proof of Delivery',
        ),
        if (recipient.isNotEmpty)
          _DetailRow(label: 'Received By', value: recipient, bold: true),
        if (authRep.isNotEmpty)
          _DetailRow(label: 'Authorized Rep', value: authRep),
        if (relationship.isNotEmpty)
          _DetailRow(label: 'Relationship', value: relationship),
        // Do not expose the auth-rep contact number after delivery is complete.
        if (contactRep.isNotEmpty &&
            _str('delivery_status').toLowerCase() != 'delivered')
          _TappableRow(
            label: 'Contact',
            value: contactRep,
            onTap: () => _onPhoneTap(contactRep),
            trailingIcon: Icons.call_outlined,
          ),
        if (placementType.isNotEmpty && relationship.isEmpty)
          _DetailRow(label: 'Placement', value: placementType),
        if (note.isNotEmpty) _DetailRow(label: 'Note', value: note),
        if (transactionDateToShow.isNotEmpty)
          _DetailRow(label: 'Transaction', value: transactionDateToShow),
        if (deliveredDateToShow.isNotEmpty)
          _DetailRow(label: 'Delivered', value: deliveredDateToShow),
        if (hasMedia && showMedia) ...[
          _DetailHeader(icon: Icons.photo_library_outlined, title: 'Photos'),
          if (isDelivered && kAppDebugMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'DEBUG MODE: Images are visible for privacy review.',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          SizedBox(
            height: 108,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              scrollDirection: Axis.horizontal,
              itemCount: (media).length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final item = media[i];
                final String url;
                final String label;
                if (item is Map) {
                  final signedUrl = item['signed_url']?.toString() ?? '';
                  final rawUrl = item['url']?.toString() ?? '';
                  url = signedUrl.isNotEmpty ? signedUrl : rawUrl;
                  label = item['type']?.toString().toUpperCase() ?? 'Photo';
                } else {
                  url = item?.toString() ?? '';
                  label = 'Photo';
                }
                if (url.isEmpty) return const SizedBox(width: 100, height: 100);
                return GestureDetector(
                  onTap: isOffline
                      ? null
                      : () => _showFullscreenImage(url, mediaType: label),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: isOffline
                        ? Container(
                            width: 100,
                            height: 100,
                            color: Colors.grey.shade200,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.wifi_off_rounded,
                                  color: Colors.grey.shade400,
                                  size: 22,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Image.network(
                            url,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 100,
                              height: 100,
                              color: Colors.grey.shade200,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.cloud_off_rounded,
                                    color: Colors.grey.shade400,
                                    size: 22,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: Text(
                                      'Online only',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
        ],
        if (hasMedia && !showMedia)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Images are hidden for privacy after delivery.',
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (hasSignature && showMedia) ...[
          _DetailHeader(icon: Icons.draw_outlined, title: 'Signature'),
          if (isDelivered && kAppDebugMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'DEBUG MODE: Images are visible for privacy review.',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: GestureDetector(
              onTap: isOffline ? null : () => _showFullscreenImage(signature),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: isOffline
                    ? Container(
                        height: 100,
                        color: Colors.grey.shade200,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.wifi_off_rounded,
                                color: Colors.grey.shade400,
                                size: 22,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Signature',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Image.network(
                        signature,
                        height: 100,
                        fit: BoxFit.contain,
                        alignment: Alignment.centerLeft,
                        errorBuilder: (_, __, ___) => GestureDetector(
                          onTap: () => _showFullscreenImage(signature),
                          child: Container(
                            height: 100,
                            color: Colors.grey.shade200,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image_outlined,
                                    color: Colors.grey.shade400,
                                    size: 22,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Signature',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRtsAttempts() {
    final attempts = _delivery['rts_attempts'];
    if (attempts is! List || attempts.isEmpty) return const SizedBox.shrink();

    final typedAttempts = attempts.whereType<Map>().toList();
    if (typedAttempts.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOffline = _isOfflineMode;

    return Column(
      children: [
        const SizedBox(height: 12),
        _DetailCard(
          children: [
            _DetailHeader(
              icon: Icons.keyboard_return_rounded,
              title: 'Return Attempts (${typedAttempts.length})',
            ),
            ...typedAttempts.asMap().entries.map((entry) {
              final idx = entry.key;
              final attempt = Map<String, dynamic>.from(entry.value);
              final attemptNum =
                  (attempt['attempt_number'] as num?)?.toInt() ?? (idx + 1);
              final label = _ordinal(attemptNum);
              final reason = attempt['reason']?.toString() ?? '';
              final attemptedAt = attempt['attempted_at']?.toString() ?? '';
              final images = attempt['images'];
              final hasImages = images is List && images.isNotEmpty;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (idx > 0)
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.orange,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        if (attemptedAt.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            formatDate(attemptedAt, includeTime: true),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (reason.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                      child: Text(
                        reason,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  if (hasImages) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 0, 8),
                      child: SizedBox(
                        height: 90,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: (images).length,
                          separatorBuilder: (_, __) => const SizedBox(width: 6),
                          itemBuilder: (context, i) {
                            final img = images[i];
                            final String url;
                            if (img is Map) {
                              final signed =
                                  img['signed_url']?.toString() ?? '';
                              final raw =
                                  img['url']?.toString() ??
                                  img['file']?.toString() ??
                                  '';
                              url = signed.isNotEmpty ? signed : raw;
                            } else {
                              url = img?.toString() ?? '';
                            }
                            if (url.isEmpty) {
                              return const SizedBox(width: 90, height: 90);
                            }
                            return GestureDetector(
                              onTap: isOffline
                                  ? null
                                  : () => _showFullscreenImage(
                                      url,
                                      mediaType: 'SELFIE',
                                    ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: isOffline
                                    ? Container(
                                        width: 90,
                                        height: 90,
                                        color: Colors.grey.shade200,
                                        child: Icon(
                                          Icons.wifi_off_rounded,
                                          color: Colors.grey.shade400,
                                        ),
                                      )
                                    : Image.network(
                                        url,
                                        width: 90,
                                        height: 90,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 90,
                                          height: 90,
                                          color: Colors.grey.shade200,
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  /// Returns '1st', '2nd', '3rd', '4th', '11th', '21st', etc.
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

  Widget _buildTimeline() {
    final history = _delivery['delivery_trans_history'];
    if (history is! List || history.isEmpty) return const SizedBox.shrink();

    // Most recent first
    final items = List<Map<String, dynamic>>.from(
      history.whereType<Map<String, dynamic>>(),
    ).reversed.toList();

    return _DetailCard(
      children: [
        _DetailHeader(icon: Icons.history_rounded, title: 'History'),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            final isLast = i == items.length - 1;
            return _TimelineItem(item: item, isFirst: i == 0, isLast: isLast);
          },
        ),
      ],
    );
  }
}

// ─── Shared card wrapper ─────────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

// ─── Section header ──────────────────────────────────────────────────────────

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: ColorStyles.grabGreen),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ─── Plain detail row ────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.bold = false,
  });
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tappable row (address / phone) ─────────────────────────────────────────

class _TappableRow extends StatelessWidget {
  const _TappableRow({
    required this.label,
    required this.value,
    this.onTap,
    this.trailingIcon,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 100,
              child: Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: onTap != null ? ColorStyles.grabGreen : null,
                ),
              ),
            ),
            if (trailingIcon != null)
              Icon(trailingIcon, size: 16, color: ColorStyles.grabGreen)
            else if (onTap != null)
              Icon(
                Icons.open_in_new_rounded,
                size: 14,
                color: Colors.grey.shade400,
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Timeline item ───────────────────────────────────────────────────────────

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.item,
    required this.isFirst,
    required this.isLast,
  });

  final Map<String, dynamic> item;
  final bool isFirst;
  final bool isLast;

  IconData _iconFor(String action) {
    return switch (action.toLowerCase()) {
      'dispatched' => Icons.send_rounded,
      'received_by_courier' || 'received' => Icons.move_to_inbox_rounded,
      'delivered' => Icons.check_circle_outline_rounded,
      'attempted' => Icons.redo_rounded,
      'rts' => Icons.keyboard_return_rounded,
      'osa' => Icons.inventory_2_outlined,
      _ => Icons.circle_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final action = item['action']?.toString() ?? '';
    final timestamp = item['timestamp']?.toString() ?? '';
    final note = item['note']?.toString() ?? '';
    final status = item['status']?.toString() ?? '';
    final color = isFirst ? ColorStyles.grabGreen : Colors.grey.shade400;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline spine
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isFirst ? 1.0 : 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _iconFor(action),
                    size: 14,
                    color: isFirst ? Colors.white : Colors.grey.shade400,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          action.toDisplayStatus(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isFirst ? ColorStyles.grabGreen : null,
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
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status.toDisplayStatus(),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatDate(timestamp, includeTime: true),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(note, style: const TextStyle(fontSize: 12)),
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

// ─── Offline mode banner ─────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange.shade700,
      child: const Row(
        children: [
          Icon(Icons.wifi_off_rounded, size: 14, color: Colors.white),
          SizedBox(width: 8),
          Text(
            'Offline — showing locally saved data',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
