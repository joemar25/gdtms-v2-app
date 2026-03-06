import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/api/api_result.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';

/// Shows a bottom action sheet listing available communication apps for a phone number.
Future<void> showContactAppSheet(BuildContext context, String phone) async {
  final cleaned = phone.trim();
  if (cleaned.isEmpty) return;

  // SMS and Call are always shown first (no canLaunchUrl gating).
  // Optional apps (WhatsApp, Viber, Telegram) are added only if available.
  final apps = <_CommApp>[
    _CommApp(
      label: 'SMS',
      icon: Icons.sms_rounded,
      color: Colors.blueGrey,
      uri: Uri(scheme: 'sms', path: cleaned),
    ),
    _CommApp(
      label: 'Call',
      icon: Icons.call_rounded,
      color: Colors.green,
      uri: Uri(scheme: 'tel', path: cleaned),
    ),
  ];

  final optionalCandidates = [
    _CommApp(
      label: 'WhatsApp',
      icon: Icons.chat_rounded,
      color: const Color(0xFF25D366),
      uri: Uri.parse('whatsapp://send?phone=${cleaned.replaceAll('+', '')}'),
    ),
    _CommApp(
      label: 'Viber',
      icon: Icons.video_call_rounded,
      color: const Color(0xFF7360F2),
      uri: Uri.parse('viber://chat?number=${cleaned.replaceAll('+', '')}'),
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await ref
        .read(apiClientProvider)
        .get<Map<String, dynamic>>(
          '/deliveries/${widget.barcode}',
          parser: parseApiMap,
        );

    if (!mounted) return;

    if (result case ApiSuccess<Map<String, dynamic>>(:final data)) {
      _delivery = mapFromKey(data, 'data');
    }

    setState(() => _loading = false);
  }

  Future<void> _onPhoneTap(String? phone) async {
    if (!mounted) return;
    await showContactAppSheet(context, phone ?? '');
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
                      color: Colors.grey.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status.isEmpty
                          ? 'Pending'
                          : status[0].toUpperCase() + status.substring(1),
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
                      color: Colors.blueGrey.withOpacity(0.08),
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
                  label: const Text('UPDATE STATUS'),
                  style: FilledButton.styleFrom(
                    backgroundColor: ColorStyles.grabGreen,
                    minimumSize: const Size.fromHeight(32),
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
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                // ─ Recipient ────────────────────────────────────────────
                _DetailCard(
                  children: [
                    _DetailHeader(
                      icon: Icons.person_outline,
                      title: 'Recipient',
                    ),
                    _DetailRow(label: 'Name', value: _str('name'), bold: true),
                    _TappableRow(
                      label: 'Address',
                      value: _str('address'),
                      onTap: () => _launchMaps(_str('address')),
                      trailingIcon: Icons.map_outlined,
                    ),
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
                      _DetailRow(label: 'Remarks', value: _str('remarks')),
                    if (_str('transmittal_date').isNotEmpty)
                      _DetailRow(
                        label: 'Transmittal',
                        value: formatDate(_str('transmittal_date')),
                      ),
                    if (_str('tat').isNotEmpty)
                      _DetailRow(label: 'TAT', value: formatDate(_str('tat'))),
                  ],
                ),

                // ─ History timeline (debug only) ─────────────────────
                if (kDebugMode) ...[
                  const SizedBox(height: 12),
                  _buildTimeline(),
                ],
              ],
            ),
    );
  }

  Widget _buildDeliveredDetails() {
    final authRep = _str('authorized_rep');
    final contactRep = _str('contact_rep');
    final media = _delivery['media'];
    final hasMedia = media is List && (media).isNotEmpty;

    if (authRep.isEmpty && contactRep.isEmpty && !hasMedia) {
      return const SizedBox.shrink();
    }

    return _DetailCard(
      children: [
        _DetailHeader(
          icon: Icons.verified_outlined,
          title: 'Authorized Representative',
        ),
        if (authRep.isNotEmpty)
          _DetailRow(label: 'Received By', value: authRep),
        if (contactRep.isNotEmpty)
          _TappableRow(
            label: 'Contact',
            value: contactRep,
            onTap: () => _onPhoneTap(contactRep),
            trailingIcon: Icons.call_outlined,
          ),
        if (hasMedia) ...[
          _DetailHeader(icon: Icons.photo_library_outlined, title: 'Media'),
          SizedBox(
            height: 100,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              scrollDirection: Axis.horizontal,
              itemCount: (media).length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final url = media[i]?.toString() ?? '';
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: url.isNotEmpty
                      ? Image.network(
                          url,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        )
                      : const SizedBox(width: 100, height: 100),
                );
              },
            ),
          ),
        ],
      ],
    );
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
                          action.replaceAll('_', ' ').toUpperCase(),
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
                            status,
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
