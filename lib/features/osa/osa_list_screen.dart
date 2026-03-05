import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/api/api_result.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/core/settings/compact_mode_provider.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_identifier.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/widgets/delivery_card.dart';
import 'package:fsi_courier_app/shared/widgets/empty_state.dart';

class OsaListScreen extends ConsumerStatefulWidget {
  const OsaListScreen({super.key});

  @override
  ConsumerState<OsaListScreen> createState() => _OsaListScreenState();
}

class _OsaListScreenState extends ConsumerState<OsaListScreen> {
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
            'status': 'osa',
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
    final isCompact = ref.watch(compactModeProvider);
    return Scaffold(
      appBar: const AppHeaderBar(title: 'OSA'),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: _loading && _items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(
                        height: 400,
                        child: EmptyState(message: 'No OSA mailpacks.'),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      // ── Read-only notice banner ─────────────────────────
                      const _OsaNoticeBanner(),
                      const SizedBox(height: 12),
                      ..._items.map((d) {
                        final identifier = resolveDeliveryIdentifier(d);
                        return DeliveryCard(
                          delivery: d,
                          compact: isCompact,
                          // Navigate to detail (read-only — no UPDATE button
                          // shown for OSA in the detail screen header).
                          onTap: identifier.isEmpty
                              ? () {}
                              : () =>
                                  context.push('/deliveries/$identifier'),
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

// ─── Read-only notice banner ─────────────────────────────────────────────────

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
          Icon(Icons.info_outline_rounded,
              size: 18, color: Colors.amber.shade800),
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
