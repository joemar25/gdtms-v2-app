import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/api/api_result.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/widgets/floating_bottom_nav_bar.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _loading = true;
  Map<String, dynamic> _summary = {};

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

    final isOnline = ref.read(isOnlineProvider);

    if (isOnline) {
      final api = ref.read(apiClientProvider);
      final summaryResult = await api.get<Map<String, dynamic>>(
        '/dashboard-summary',
        parser: parseApiMap,
      );

      if (!mounted) return;

      if (summaryResult case ApiSuccess<Map<String, dynamic>>(:final data)) {
        _summary = mapFromKey(data, 'data');
        setState(() => _loading = false);
        return;
      }
      // On any API failure fall through to the SQLite count fallback below.
    }

    if (!mounted) return;

    // Offline fallback: derive counts from local SQLite so the dashboard
    // remains informative without a network connection.
    final dao = LocalDeliveryDao.instance;
    final pending = await dao.countByStatus('pending');
    final delivered = await dao.countByStatus('delivered');
    final rts = await dao.countByStatus('rts');
    final osa = await dao.countByStatus('osa');

    if (!mounted) return;

    _summary = {
      'pending_dispatches': 0, // cannot be derived locally
      'pending_deliveries': pending,
      'delivered_today': delivered,
      'rts': rts,
      'osa': osa,
    };

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(deliveryRefreshProvider, (_, __) => _loadInitial());
    final auth = ref.watch(authProvider);
    final fullName = auth.courier?['name']?.toString() ?? 'Courier';
    final firstName = _extractFirstName(fullName);
    final courierCode = auth.courier?['courier_code']?.toString() ?? '-';
    final greeting = _getGreeting();

    final pendingDispatchCount = _summary['pending_dispatches'] ?? 0;
    final deliveriesCount = _summary['pending_deliveries'] ?? 0;
    final rtsCount = _summary['rts'] ?? 0;
    final osaCount = _summary['osa'] ?? 0;
    final deliveredCount = _summary['delivered_today'] ?? 0;

    return Scaffold(
      appBar: AppHeaderBar(title: ''),
      bottomNavigationBar: const FloatingBottomNavBar(
        currentPath: '/dashboard',
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInitial,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  // ── Greeting ─────────────────────────────────────────────
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

                  // ── 4 Summary Boxes ───────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'DISPATCH',
                          count: '$pendingDispatchCount',
                          icon: Icons.qr_code_rounded,
                          color: ColorStyles.grabOrange,
                          onTap: pendingDispatchCount == 0
                              ? null
                              : () => context.push('/dispatches'),
                          details: 'Waiting for acceptance.',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          label: 'DELIVERIES',
                          count: '$deliveriesCount',
                          icon: Icons.local_shipping_outlined,
                          color: ColorStyles.grabGreen,
                          onTap: deliveriesCount == 0
                              ? null
                              : () => context.push('/deliveries'),
                          details: "Today's for deliveries.",
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'DELIVERED',
                          count: '$deliveredCount',
                          icon: Icons.check_circle_outline_rounded,
                          color: ColorStyles.grabGreen,
                          onTap: deliveredCount == 0
                              ? null
                              : () => context.push('/delivered'),
                          details: "Today's delivered.",
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          label: 'RTS',
                          count: '$rtsCount',
                          icon: Icons.assignment_return_outlined,
                          color: Colors.red,
                          onTap: rtsCount == 0
                              ? null
                              : () => context.push('/rts'),
                          subdued: true,
                          details: "Today's return to sender items.",
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'OSA',
                          count: '$osaCount',
                          icon: Icons.lock_outline_rounded,
                          color: Colors.grey,
                          onTap: osaCount == 0
                              ? null
                              : () => context.push('/osa'),
                          subdued: true,
                          details: "Today's out of service area.",
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          label: 'SYNC',
                          count: '',
                          icon: Icons.sync_rounded,
                          color: Colors.blueGrey,
                          onTap: () => context.push('/sync'),
                          subdued: true,
                        details: 'Offline to online sync.',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Scan Action Buttons ────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _ScanButton(
                          label: 'SCAN DISPATCH',
                          icon: Icons.qr_code_scanner_rounded,
                          color: ColorStyles.grabOrange,
                          onTap: () => context.push(
                            '/scan',
                            extra: {'mode': 'dispatch'},
                          ),
                          details:
                              'Scan a dispatch barcode to check eligibility.',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ScanButton(
                          label: 'SCAN POD',
                          icon: Icons.qr_code_scanner_rounded,
                          color: ColorStyles.grabGreen,
                          onTap: () =>
                              context.push('/scan', extra: {'mode': 'pod'}),
                          details:
                              'Scan a delivery barcode to find and update POD.',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
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
    this.subdued = false,
    this.details,
  });

  final String label;
  final String count;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool subdued;
  final String? details;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final effectiveColor = subdued ? color.withValues(alpha: 0.6) : color;
    final isDisabled = onTap == null;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.withValues(alpha: 0.2),
              width: 1,
            ),
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
              Row(
                children: [
                  Icon(icon, color: effectiveColor, size: 18),
                  const SizedBox(width: 4),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                count,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: effectiveColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: subdued ? Colors.grey.shade400 : Colors.grey.shade500,
                  letterSpacing: 0.3,
                ),
              ),
              if (details != null) ...[
                const SizedBox(height: 6),
                Text(
                  details!,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Scan Button ──────────────────────────────────────────────────────────────

class _ScanButton extends StatelessWidget {
  const _ScanButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.details,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? details;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.30), width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
            if (details != null) ...[
              const SizedBox(height: 6),
              Text(
                details!,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
