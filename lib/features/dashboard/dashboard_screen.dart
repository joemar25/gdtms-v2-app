import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_result.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/auth_storage.dart';
import '../../core/constants.dart';
import '../../shared/helpers/api_payload_helper.dart';
import '../../shared/helpers/delivery_identifier.dart';
import '../../shared/helpers/snackbar_helper.dart';
import '../../shared/widgets/bottom_nav_bar.dart';
import '../../shared/widgets/delivery_card.dart';
import '../../shared/widgets/empty_state.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _loading = true;
  int _page = 1;
  int _lastPage = 1;
  Map<String, dynamic> _summary = {};
  final List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final api = ref.read(apiClientProvider);

    final summaryFuture = api.get<Map<String, dynamic>>(
      '/dashboard-summary',
      parser: parseApiMap,
    );

    final deliveriesFuture = api.get<Map<String, dynamic>>(
      '/deliveries',
      queryParameters: {
        'status': 'pending',
        'per_page': kDashboardPerPage,
        'page': 1,
      },
      parser: parseApiMap,
    );

    final responses = await Future.wait([summaryFuture, deliveriesFuture]);
    final summary = responses[0];
    final deliveries = responses[1];

    if (!mounted) return;

    if (summary case ApiSuccess<Map<String, dynamic>>(:final data)) {
      _summary = mapFromKey(data, 'data');
    }

    if (deliveries case ApiSuccess<Map<String, dynamic>>(:final data)) {
      _items
        ..clear()
        ..addAll(listOfMapsFromKey(data, 'data'));
      final pagination = mapFromKey(data, 'pagination');
      _page = pagination['current_page'] as int? ?? 1;
      _lastPage = pagination['last_page'] as int? ?? 1;
    } else if (deliveries is ApiNetworkError<Map<String, dynamic>>) {
      await ref.read(authStorageProvider).clearAll();
      await ref.read(authProvider.notifier).initialize();
      if (mounted) {
        context.go('/login');
        showAppSnackbar(
          context,
          'Could not reach the server. Please check your connection and log in again.',
          type: SnackbarType.error,
        );
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMore() async {
    if (_page >= _lastPage || _loading) return;
    setState(() => _loading = true);
    final nextPage = _page + 1;

    final api = ref.read(apiClientProvider);
    final result = await api.get<Map<String, dynamic>>(
      '/deliveries',
      queryParameters: {
        'status': 'pending',
        'per_page': kDashboardPerPage,
        'page': nextPage,
      },
      parser: parseApiMap,
    );

    if (!mounted) return;

    if (result case ApiSuccess<Map<String, dynamic>>(:final data)) {
      _items.addAll(listOfMapsFromKey(data, 'data'));
      final pagination = mapFromKey(data, 'pagination');
      _page = pagination['current_page'] as int? ?? nextPage;
      _lastPage = pagination['last_page'] as int? ?? _lastPage;
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final courierName = auth.courier?['name']?.toString() ?? 'Courier';
    final courierCode = auth.courier?['courier_code']?.toString() ?? '-';

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      bottomNavigationBar: const AppBottomNavBar(currentPath: '/dashboard'),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/dispatches/scan'),
        child: const Icon(Icons.qr_code_scanner),
      ),
      body: _loading && _items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInitial,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    courierName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(courierCode),
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      title: const Text('Pending Deliveries'),
                      trailing: Text('${_summary['pending_count'] ?? 0}'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_items.isEmpty)
                    const SizedBox(
                      height: 320,
                      child: EmptyState(message: 'No pending deliveries.'),
                    ),
                  ..._items.map((d) {
                    final identifier = resolveDeliveryIdentifier(d);
                    return DeliveryCard(
                      delivery: d,
                      onTap: identifier.isEmpty
                          ? () {}
                          : () => context.push('/deliveries/$identifier'),
                    );
                  }),
                  if (_page < _lastPage)
                    OutlinedButton(
                      onPressed: _loadMore,
                      child: const Text('Load More'),
                    ),
                ],
              ),
            ),
    );
  }
}
