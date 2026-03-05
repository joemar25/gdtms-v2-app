import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/api/api_result.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';
import 'package:fsi_courier_app/shared/widgets/status_badge.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';

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

  Future<void> _launchCall(String? phone) async {
    final cleaned = phone?.trim() ?? '';
    if (cleaned.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchMaps(String? address) async {
    final query = Uri.encodeComponent(address?.trim() ?? '');
    if (query.isEmpty) return;
    final uri = Uri.parse('geo:0,0?q=$query');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Fall back to Google Maps web
      await launchUrl(
        Uri.parse('https://maps.google.com/?q=$query'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  String _str(String key) => _delivery[key]?.toString().trim() ?? '';

  @override
  Widget build(BuildContext context) {
    final status = _str('delivery_status').toLowerCase();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F7);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          widget.barcode,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (status == 'pending' || status == 'rts' || status == 'osa')
            TextButton(
              onPressed: () =>
                  context.push('/deliveries/${widget.barcode}/update'),
              child: const Text('Update'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                // ─ Status badge ─────────────────────────────────────────
                Row(
                  children: [
                    StatusBadge(status: status.isEmpty ? 'pending' : status),
                    const SizedBox(width: 8),
                    if (_str('mail_type').isNotEmpty)
                      _Chip(_str('mail_type')),
                  ],
                ),
                const SizedBox(height: 16),

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
                      icon: Icons.map_outlined,
                      label: 'Address',
                      value: _str('address'),
                      onTap: () => _launchMaps(_str('address')),
                    ),
                    _TappableRow(
                      icon: Icons.phone_outlined,
                      label: 'Contact',
                      value: _str('contact'),
                      onTap: () => _launchCall(_str('contact')),
                    ),
                    // Authorized reps ─────────────────────────────────
                    for (int i = 1; i <= 3; i++) ..._buildRepRow(i),
                  ],
                ),
                const SizedBox(height: 12),

                // ─ Delivery details ──────────────────────────────────────
                _DetailCard(
                  children: [
                    _DetailHeader(
                      icon: Icons.local_shipping_outlined,
                      title: 'Delivery Details',
                    ),
                    if (_str('barcode_value').isNotEmpty)
                      _DetailRow(label: 'Barcode', value: _str('barcode_value')),
                    if (_str('dispatch_code').isNotEmpty)
                      _DetailRow(label: 'Dispatch', value: _str('dispatch_code')),
                    if (_str('product').isNotEmpty)
                      _DetailRow(label: 'Product', value: _str('product')),
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
                      _DetailRow(
                        label: 'TAT',
                        value: formatDate(_str('tat')),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // ─ Media (when delivered) ─────────────────────────────
                if (status == 'delivered') ...[
                  _buildMediaSection(),
                  const SizedBox(height: 12),
                ],

                // ─ History timeline ──────────────────────────────────
                _buildTimeline(),
              ],
            ),
    );
  }

  List<Widget> _buildRepRow(int index) {
    final name = _str('authorized_rep_$index');
    final phone = _str('contact_rep_$index');
    if (name.isEmpty && phone.isEmpty) return [];
    return [
      _TappableRow(
        icon: Icons.person_pin_outlined,
        label: 'Auth. Rep $index',
        value: name.isNotEmpty
            ? '$name${phone.isNotEmpty ? ' · $phone' : ''}'
            : phone,
        onTap: phone.isNotEmpty ? () => _launchCall(phone) : null,
        showCallIcon: phone.isNotEmpty,
      ),
    ];
  }

  Widget _buildMediaSection() {
    final media = _delivery['media'];
    if (media is! List || media.isEmpty) {
      return const SizedBox.shrink();
    }

    return _DetailCard(
      children: [
        _DetailHeader(icon: Icons.photo_library_outlined, title: 'Media'),
        SizedBox(
          height: 100,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            scrollDirection: Axis.horizontal,
            itemCount: media.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final url = media[i]?.toString() ?? '';
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: url.isNotEmpty
                    ? Image.network(url, width: 100, height: 100, fit: BoxFit.cover)
                    : const SizedBox(width: 100, height: 100),
              );
            },
          ),
        ),
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
            return _TimelineItem(
              item: item,
              isFirst: i == 0,
              isLast: isLast,
            );
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
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
  const _DetailRow({required this.label, required this.value, this.bold = false});
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
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
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
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.showCallIcon = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool showCallIcon;

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
            if (showCallIcon)
              Icon(Icons.call_outlined, size: 16, color: ColorStyles.grabGreen)
            else if (onTap != null)
              Icon(Icons.open_in_new_rounded, size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

// ─── Status chip ─────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
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

