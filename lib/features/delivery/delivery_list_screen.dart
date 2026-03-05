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

class DeliveryListScreen extends ConsumerStatefulWidget {
  const DeliveryListScreen({super.key});

  @override
  ConsumerState<DeliveryListScreen> createState() => _DeliveryListScreenState();
}

class _DeliveryListScreenState extends ConsumerState<DeliveryListScreen> {
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
            'status': 'delivered',
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
      appBar: const AppHeaderBar(title: 'Deliveries'),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/scan', extra: {'mode': 'pod'}),
        child: const Icon(Icons.qr_code_scanner),
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
                    child: EmptyState(message: 'No completed deliveries.'),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ..._items.map((d) {
                    final identifier = resolveDeliveryIdentifier(d);
                    return DeliveryCard(
                      delivery: d,
                      compact: isCompact,
                      onTap: identifier.isEmpty
                          ? () {}
                          : () => context.push('/deliveries/$identifier'),
                    );
                  }),
                  if (_page < _lastPage)
                    OutlinedButton(
                      onPressed: () {
                        _page += 1;
                        _load(reset: false);
                      },
                      child: const Text('Load More'),
                    ),
                ],
              ),
      ),
    );
  }
}
