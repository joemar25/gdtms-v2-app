import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/api/api_result.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/auth/auth_storage.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/core/settings/compact_mode_provider.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_identifier.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/widgets/delivery_card.dart';
import 'package:fsi_courier_app/shared/widgets/empty_state.dart';
import 'package:fsi_courier_app/shared/widgets/floating_bottom_nav_bar.dart';
import 'package:fsi_courier_app/shared/widgets/scan_mode_sheet.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';

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

  String _extractFirstName(String fullName) {
    final parts = fullName.trim().split(' ');
    return parts.isNotEmpty ? parts.first : fullName;
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _loadInitial() async {
    if (!mounted) return;
    setState(() => _loading = true);

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
    final fullName = auth.courier?['name']?.toString() ?? 'Courier';
    final firstName = _extractFirstName(fullName);
    final courierCode = auth.courier?['courier_code']?.toString() ?? '-';
    final greeting = _getGreeting();

    final pendingCount = _summary['pending_count'] ?? 0;
    final deliveriesCount = _summary['active_deliveries_count'] ?? 0;
    final dispatchesCount = _summary['pending_dispatches_count'] ?? 0;
    final isCompact = ref.watch(compactModeProvider);

    return Scaffold(
      // mar-note: no need to put anything in the title
      appBar: AppHeaderBar(title: ''),
      bottomNavigationBar: const FloatingBottomNavBar(
        currentPath: '/dashboard',
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: ColorStyles.grabGreen,
        foregroundColor: Colors.white,
        onPressed: () => showScanModeSheet(context),
        child: const Icon(Icons.qr_code_scanner_rounded),
      ),
      body: _loading && _items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInitial,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  // ── Greeting ────────────────────────────────────────────
                  Text(
                    '$greeting, $firstName!',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    courierCode,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Stat Cards ──────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Pending',
                          count: '$pendingCount',
                          icon: Icons.local_shipping_outlined,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          label: 'Deliveries',
                          count: '$deliveriesCount',
                          icon: Icons.check_circle_outline_rounded,
                          color: ColorStyles.grabGreen,
                          onTap: () => context.push('/deliveries'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          label: 'Dispatches',
                          count: '$dispatchesCount',
                          icon: Icons.qr_code_rounded,
                          color: ColorStyles.grabOrange,
                          onTap: () => context.push('/dispatches'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Delivery Feed ────────────────────────────────────────
                  Text(
                    'Pending Deliveries',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_items.isEmpty)
                    const SizedBox(
                      height: 280,
                      child: EmptyState(message: 'No pending deliveries.'),
                    ),
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
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton(
                        onPressed: _loadMore,
                        child: const Text('Load More'),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final String count;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              count,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}
