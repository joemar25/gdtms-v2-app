import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/api/api_result.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/core/settings/compact_mode_provider.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_identifier.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/widgets/delivery_card.dart';
import 'package:fsi_courier_app/shared/widgets/empty_state.dart';

/// A single list screen reused for every delivery status filter
/// (pending, delivered, rts, osa).
class DeliveryStatusListScreen extends ConsumerStatefulWidget {
  const DeliveryStatusListScreen({
    super.key,
    required this.status,
    required this.title,
  });

  final String status;
  final String title;

  @override
  ConsumerState<DeliveryStatusListScreen> createState() =>
      _DeliveryStatusListScreenState();
}

class _DeliveryStatusListScreenState
    extends ConsumerState<DeliveryStatusListScreen> {
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
            'status': widget.status,
            if (widget.status == 'delivered') ...() {
              final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
              return {
                'active': 'true',
                'from_date': today,
                'to_date': today,
              };
            }(),
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

  List<Widget> _buildActions(BuildContext context) {
    // RULE: If status is 'osa', do not ever show update status button or actions here
    return switch (widget.status) {
      'pending' => [
        IconButton(
          icon: const Icon(Icons.qr_code_scanner_rounded),
          tooltip: 'Scan POD',
          onPressed: () => context.push('/scan', extra: {'mode': 'pod'}),
        ),
      ],
      'rts' => [
        IconButton(
          icon: const Icon(Icons.qr_code_scanner_rounded),
          tooltip: 'Scan Dispatch',
          onPressed: () => context.push('/scan', extra: {'mode': 'dispatch'}),
        ),
      ],
      'osa' => [],
      _ => [],
    };
  }

  String _emptyMessage() => switch (widget.status) {
    'pending' => 'No active deliveries.',
    'delivered' => 'No delivered items.',
    'rts' => 'No RTS mailpacks.',
    'osa' => 'No OSA mailpacks.',
    _ => 'No items found.',
  };

  @override
  Widget build(BuildContext context) {
    final isCompact = ref.watch(compactModeProvider);

    return Scaffold(
      appBar: AppHeaderBar(
        title: widget.title,
        actions: _buildActions(context),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: _loading && _items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
            ? ListView(
                children: [
                  SizedBox(
                    height: 400,
                    child: EmptyState(message: _emptyMessage()),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  if (widget.status == 'osa') ...[
                    const _OsaNoticeBanner(),
                    const SizedBox(height: 12),
                  ],
                  ..._items.map((d) {
                    final identifier = resolveDeliveryIdentifier(d);
                    // RULE: If status is 'osa', all delivery card navigation is disabled
                    // — no action required, pending admin review
                    return DeliveryCard(
                      delivery: d,
                      compact: isCompact,
                      onTap: (widget.status == 'osa' || identifier.isEmpty)
                          ? () {}
                          : () => context.push('/deliveries/$identifier'),
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

// ─── OSA read-only notice ─────────────────────────────────────────────────────

class _OsaNoticeBanner extends StatelessWidget {
  const _OsaNoticeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Colors.amber.shade800,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'PENDING ADMIN REVIEW — NO ACTION REQUIRED',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.amber.shade900,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
