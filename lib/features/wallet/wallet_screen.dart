import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/api/api_result.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/widgets/floating_bottom_nav_bar.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  bool _loading = true;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await ref
        .read(apiClientProvider)
        .get<Map<String, dynamic>>('/wallet-summary', parser: parseApiMap);

    if (!mounted) return;
    if (result case ApiSuccess<Map<String, dynamic>>(:final data)) {
      _data = mapFromKey(data, 'data');
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final latest = asStringDynamicMap(_data['latest_request']);
    final earnings = _data['total_earnings'] ?? 0;
    final pending = _data['tentative_pending_payout'] ?? 0;

    // 1-week rolling window label (data cap — reflects what payout request covers)
    final today = DateTime.now();
    final weekStart = today.subtract(const Duration(days: 6));
    final weekLabel =
        '${DateFormat('MMM d').format(weekStart)} – ${DateFormat('MMM d').format(today)}';

    // Check if latest request is pending/active (hide request button)
    final latestStatus = latest['status']?.toString().toLowerCase() ?? '';
    final latestDate = latest['created_at']?.toString() ?? '';
    final isLatestPending =
        latestStatus == 'pending' ||
        latestStatus == 'processing' ||
        latestStatus == 'approved';
    bool requestedToday = false;
    if (latestDate.isNotEmpty) {
      try {
        final requestDate = DateTime.parse(latestDate);
        requestedToday =
            requestDate.year == today.year &&
            requestDate.month == today.month &&
            requestDate.day == today.day;
      } catch (_) {}
    }

    // Only show "Request Payout" if no pending request and not requested today
    final canRequestPayout = !isLatestPending && !requestedToday;

    return Scaffold(
      appBar: const AppHeaderBar(title: 'Wallet'),
      bottomNavigationBar: const FloatingBottomNavBar(currentPath: '/wallet'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  // ── Active 1-week window label ─────────────────────────
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: ColorStyles.grabGreen.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                          color: ColorStyles.grabGreen,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ACTIVE PERIOD: $weekLabel',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: ColorStyles.grabGreen,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Earnings card ──────────────────────────────────────
                  _EarningsCard(earnings: earnings, pending: pending),
                  const SizedBox(height: 20),

                  // ── Latest request ─────────────────────────────────────
                  if (latest.isNotEmpty && latest['reference'] != null) ...[
                    _SectionLabel('Latest Request'),
                    const SizedBox(height: 8),
                    _LatestRequestCard(
                      data: latest,
                      // Only use reference for navigation, not id
                      onTap: () => context.push('/wallet/${latest['reference']}'),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Action ─────────────────────────────────────────────
                  if (canRequestPayout)
                    FilledButton.icon(
                      onPressed: () => context.push('/wallet/request'),
                      icon: const Icon(Icons.add),
                      label: const Text('Request Payout'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: Colors.amber.shade700,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isLatestPending
                                  ? 'You have a pending payout request'
                                  : 'One request per day. Try again tomorrow',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

// ─── Earnings card ────────────────────────────────────────────────────────────

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({required this.earnings, required this.pending});

  final dynamic earnings;
  final dynamic pending;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF007A36), Color(0xFF00B14F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ColorStyles.grabGreen.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white70,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'Total Earnings',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '₱ ${_fmt(earnings)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  color: Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Pending payout',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const Spacer(),
                Text(
                  '₱ ${_fmt(pending)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(dynamic val) {
    final n = double.tryParse('$val') ?? 0.0;
    return n.toStringAsFixed(2);
  }
}

// ─── Latest request card ──────────────────────────────────────────────────────

class _LatestRequestCard extends StatelessWidget {
  const _LatestRequestCard({required this.data, required this.onTap});

  final Map<String, dynamic> data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = '${data['status'] ?? ''}';
    final reference =
        '${data['reference'] ?? data['payment_reference'] ?? '—'}';
    final amount = double.tryParse('${data['amount'] ?? 0}') ?? 0.0;
    final from = formatDate('${data['from_date'] ?? ''}');
    final to = formatDate('${data['to_date'] ?? ''}');
    final totalItems = data['total_items'];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      reference,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  _StatusBadge(status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.calendar_today_outlined,
                    label: '$from – $to',
                  ),
                  if (totalItems != null) ...[
                    const SizedBox(width: 10),
                    _InfoChip(
                      icon: Icons.inventory_2_outlined,
                      label: '$totalItems items',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Amount',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade500,
                    ),
                  ),
                  Text(
                    '₱ ${amount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: ColorStyles.grabGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status.toLowerCase()) {
      'approved' => (const Color(0xFFE6F9EE), ColorStyles.grabGreen),
      'rejected' => (const Color(0xFFFFEBEB), Colors.red.shade600),
      'processing' => (const Color(0xFFFFF4E0), Colors.orange.shade700),
      _ => (Colors.grey.shade100, Colors.grey.shade600),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.isEmpty
            ? '—'
            : '${status[0].toUpperCase()}${status.substring(1)}',
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Colors.grey.shade500,
        letterSpacing: 0.6,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
