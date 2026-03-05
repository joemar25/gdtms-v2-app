import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/api/api_result.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_identifier.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/widgets/empty_state.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';

const int _kMaxRtsAttempts = 3;

class RtsListScreen extends ConsumerStatefulWidget {
  const RtsListScreen({super.key});

  @override
  ConsumerState<RtsListScreen> createState() => _RtsListScreenState();
}

class _RtsListScreenState extends ConsumerState<RtsListScreen> {
  bool _loading = true;
  int _page = 1;
  int _lastPage = 1;
  final List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      _page = 1;
      _lastPage = 1;
      _items.clear();
    }
    setState(() => _loading = true);

    final result = await ref
        .read(apiClientProvider)
        .get<Map<String, dynamic>>(
          '/deliveries',
          queryParameters: {
            'status': 'rts',
            'per_page': kDeliveriesPerPage,
            'page': _page,
          },
          parser: parseApiMap,
        );

    if (!mounted) return;

    if (result case ApiSuccess<Map<String, dynamic>>(:final data)) {
      _items.addAll(listOfMapsFromKey(data, 'data'));
      final pagination = mapFromKey(data, 'pagination');
      _page = pagination['current_page'] as int? ?? _page;
      _lastPage = pagination['last_page'] as int? ?? _lastPage;
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeaderBar(
        title: 'RTS',
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scan Dispatch',
            onPressed: () => context.push('/scan', extra: {'mode': 'dispatch'}),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: _loading && _items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
            ? ListView(
                children: const [
                  SizedBox(
                    height: 400,
                    child: EmptyState(message: 'No RTS mailpacks.'),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ..._items.map((d) {
                    final identifier = resolveDeliveryIdentifier(d);
                    final attempts = d['rts_attempt_count'] as int? ?? 0;
                    final locked = attempts >= _kMaxRtsAttempts;
                    return _RtsCard(
                      delivery: d,
                      identifier: identifier,
                      attempts: attempts,
                      locked: locked,
                      onTap: () => context.push('/deliveries/$identifier'),
                    );
                  }),
                  if (_page < _lastPage)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: OutlinedButton(
                        onPressed: () {
                          _page += 1;
                          _load(reset: false);
                        },
                        child: const Text('LOAD MORE'),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

// ─── RTS Card ────────────────────────────────────────────────────────────────

class _RtsCard extends StatelessWidget {
  const _RtsCard({
    required this.delivery,
    required this.identifier,
    required this.attempts,
    required this.locked,
    required this.onTap,
  });

  final Map<String, dynamic> delivery;
  final String identifier;
  final int attempts;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final address = delivery['address']?.toString() ?? '';
    final name = (delivery['name'] ?? delivery['recipient'] ?? '').toString();

    final attemptColor = locked
        ? Colors.red.shade700
        : attempts == _kMaxRtsAttempts - 1
        ? Colors.orange
        : Colors.purple;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(
            color: locked ? Colors.red.shade700 : Colors.purple,
            width: 4,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Row 1: barcode + attempt badge ──
              Row(
                children: [
                  Expanded(
                    child: Text(
                      identifier.isEmpty ? 'Unknown' : identifier,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  // Attempt counter badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: attemptColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: attemptColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      'ATTEMPT $attempts OF $_kMaxRtsAttempts',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: attemptColor,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
              if (name.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  name,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
              if (address.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
              // ── Locked warning ──
              if (locked) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        size: 13,
                        color: Colors.red.shade700,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'MAX ATTEMPTS REACHED — UPDATES DISABLED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.red.shade700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // ── Update CTA (only when not locked) ──
              if (!locked) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: const Text(
                      'UPDATE STATUS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: ColorStyles.grabGreen,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () =>
                        context.push('/deliveries/$identifier/update'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
