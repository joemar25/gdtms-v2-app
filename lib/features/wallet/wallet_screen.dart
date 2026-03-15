import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/core/api/api_result.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/widgets/date_strip_with_deliveries.dart';
import 'package:fsi_courier_app/shared/widgets/floating_bottom_nav_bar.dart';
import 'package:fsi_courier_app/shared/widgets/offline_banner.dart';
import 'package:fsi_courier_app/shared/widgets/confirmation_dialog.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  bool _loading = true;
  Map<String, dynamic> _data = {};
  double _eligible = 0.0;
  List<Map<String, dynamic>> _historyBreakdown = [];
  String? _initialHistoryDate;
  int _stripKey = 0;

  static const _earningsCacheKey = 'wallet_summary_cache';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    // Load the full cached wallet snapshot first (offline-first fallback).
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(_earningsCacheKey);
    Map<String, dynamic> cachedData = {};
    double cachedEligible = 0.0;
    if (cachedJson != null && cachedJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
        cachedData = Map<String, dynamic>.from(
          decoded['summary'] as Map? ?? {},
        );
        cachedEligible = (decoded['eligible'] as num?)?.toDouble() ?? 0.0;
      } catch (_) {}
    }

    if (!ref.read(isOnlineProvider)) {
      if (mounted) {
        _data = cachedData;
        _eligible = cachedEligible;
        setState(() => _loading = false);
      }
      return;
    }

    // Online: fetch summary 
    final api = ref.read(apiClientProvider);
    final result = await api.get<Map<String, dynamic>>('/wallet-summary', parser: parseApiMap);

    // Parse results and persist the full snapshot before the mounted check
    // so the cache is always written even if the user navigated away.
    Map<String, dynamic> newData = cachedData;
    double newEligible = cachedEligible;

    if (result case ApiSuccess<Map<String, dynamic>>(:final data)) {
      final summary = mapFromKey(data, 'data');
      newData = summary;
      
      // Handle tentative_pending_payout
      final pendingAmount = summary['tentative_pending_payout'];
      if (pendingAmount != null) {
        newEligible = double.tryParse('$pendingAmount') ?? 0.0;
      }
      
      // Check if there is already a pending request to prevent duplicate requests
      final latestRequest = summary['latest_request'];
      final requestedAt = latestRequest?['requested_at']?.toString() ?? '';
      bool isToday = false;
      if (requestedAt.isNotEmpty) {
        try {
          final reqDate = DateTime.parse(requestedAt).toLocal();
          final now = DateTime.now();
          isToday = reqDate.year == now.year && 
                    reqDate.month == now.month && 
                    reqDate.day == now.day;
        } catch (_) {}
      }
      newData['has_existing_request_today'] = 
          latestRequest != null && latestRequest['status'] == 'pending' && isToday;
    }

    // ── Payout request history (from wallet-summary.payout_history.data) ────
    List<Map<String, dynamic>> historyBreakdown = [];
    {
      final historyWrapper = newData['payout_history'] as Map<String, dynamic>?;
      final rawList =
          (historyWrapper?['data'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];

      // Group requests by date so DateStrip can show a single tile for multiple requests/day.
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final req in rawList) {
        final dateField = req['date']?.toString();
        final raw = dateField ??
            req['from_date']?.toString() ??
            req['created_at']?.toString() ??
            req['requested_at']?.toString() ??
            '';
        
        String dateStr;
        if (raw.isNotEmpty) {
          dateStr = raw.contains('T')
              ? raw.split('T').first
              : (raw.contains(' ') ? raw.split(' ').first : raw);
        } else {
          dateStr = req['reference']?.toString() ?? 'Recent';
        }
        
        grouped.putIfAbsent(dateStr, () => []).add(req);
      }

      historyBreakdown = grouped.entries.map((e) {
        final dateStr = e.key;
        final requests = e.value;
        
        double dayTotal = 0;
        for (final r in requests) {
          dayTotal += double.tryParse('${r['amount'] ?? 0}') ?? 0.0;
        }
        
        return <String, dynamic>{
          'date': dateStr,
          'deliveries': requests,
          'day_total': dayTotal,
          'delivery_count': requests.length,
        };
      }).toList();
    }

    // Persist the full snapshot as JSON — same pattern as courier data.
    await prefs.setString(
      _earningsCacheKey,
      jsonEncode({'summary': newData, 'eligible': newEligible}),
    );

    if (!mounted) return;

    _data = newData;
    _eligible = newEligible;
    _historyBreakdown = historyBreakdown;
    _stripKey++;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);
    final earnings = _data['total_earnings'] ?? 0;
    final tentativePayout = _data['tentative_pending_payout'] ?? 0;
    final latest = _data['latest_request'] ?? {};
    final latestStatus = latest['status']?.toString().toLowerCase() ?? '';
    final isLatestPending = latestStatus == 'pending' ||
        latestStatus == 'processing' ||
        latestStatus == 'ops_approved' ||
        latestStatus == 'hr_approved' ||
        latestStatus == 'approved';

    final pendingRequestAmt = isLatestPending ? (latest['amount'] ?? 0) : 0;

    // Use has_existing_request_today from the latest API preview if available
    final hasExistingRequestToday = _data['has_existing_request_today'] == true;
    final canRequestPayout = !isLatestPending && !hasExistingRequestToday;

    ref.listen<int>(walletRefreshProvider, (_, __) => _load());

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await ConfirmationDialog.show(
          context,
          title: 'Exit App',
          subtitle: 'Are you sure you want to exit?',
          confirmLabel: 'Exit',
          cancelLabel: 'Stay',
          isDestructive: true,
        );
        if (shouldExit == true && mounted) SystemNavigator.pop();
      },
      child: Scaffold(
        extendBody: true,
        appBar: const AppHeaderBar(
          title: 'Wallet',
          pageIcon: Icons.account_balance_wallet_rounded,
        ),
        bottomNavigationBar: const FloatingBottomNavBar(currentPath: '/wallet'),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    // ── Offline banner ─────────────────────────────────────
                    if (!isOnline)
                      const OfflineBanner(
                        isMinimal: true,
                        customMessage:
                            'You\'re offline — only total earnings are shown.',
                        margin: EdgeInsets.only(bottom: 14),
                      ),



                    // ── Earnings card (always shown, pending hidden offline) ─
                    _EarningsCard(
                      earnings: earnings,
                      tentativePayout: tentativePayout,
                      pendingRequestAmt: pendingRequestAmt,
                      isLatestPending: isLatestPending,
                      showPending: isOnline,
                      onTap: () =>
                          _showEarningsDetail(context, earnings, tentativePayout, pendingRequestAmt, isLatestPending),
                    ),

                    const SizedBox(height: 20),

                    // ── Online-only section ──────────────────────────────
                    if (isOnline) ...[
                      // Request payout / consolidate / pending notice
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
                      else if (isLatestPending && _eligible > 0 && !hasExistingRequestToday)
                        FilledButton.icon(
                          onPressed: () => context.push(
                            '/wallet/request',
                            extra: {'consolidate': true},
                          ),
                          icon: const Icon(Icons.merge_rounded),
                          label: const Text('Consolidate Payout Request'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
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
                                  hasExistingRequestToday
                                      ? 'You have already submitted a request today. You can consolidate your deliveries tomorrow.'
                                      : 'You have a pending payout request',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.amber.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 20),

                      // ── Payout history strip ─────────────────────────────
                      if (_historyBreakdown.isNotEmpty) ...[
                        _SectionLabel('Payout History'),
                        const SizedBox(height: 8),
                        DateStripWithDeliveries(
                          key: ValueKey('history_$_stripKey'),
                          dailyBreakdown: _historyBreakdown,
                          initialSelectedDate: _initialHistoryDate,
                          showDayTotal: false,
                          itemCountLabelBuilder: (n) =>
                              n == 1 ? '1 request' : '$n requests',
                          itemBuilder: (ctx, req) => _PayoutRequestHistoryRow(
                            data: req,
                            onTap: () {
                              final ref =
                                  '${req['reference'] ?? req['payment_reference'] ?? ''}';
                              if (ref.isNotEmpty) ctx.push('/wallet/$ref');
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // ── Daily deliveries strip ───────────────────────────
                      // (deliveries are shown inside payout detail, not here)
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  void _showEarningsDetail(
    BuildContext context,
    dynamic earnings,
    dynamic tentativePayout,
    dynamic pendingRequestAmt,
    bool isLatestPending,
  ) {
    final earningsAmt = double.tryParse('$earnings') ?? 0.0;
    final tentativeAmt = double.tryParse('$tentativePayout') ?? 0.0;
    final pendingAmt = double.tryParse('$pendingRequestAmt') ?? 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? ColorStyles.grabCardDark : ColorStyles.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          MediaQuery.paddingOf(ctx).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Earnings Overview',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isDark ? ColorStyles.white : ColorStyles.black,
              ),
            ),
            const SizedBox(height: 20),
            _EarningsDetailRow(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Total Earnings',
              amount: earningsAmt,
              color: ColorStyles.grabGreen,
              large: true,
            ),
            const SizedBox(height: 12),
            Container(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : ColorStyles.tertiary,
            ),
            const SizedBox(height: 12),
            if (isLatestPending && pendingAmt > 0) ...[
              _EarningsDetailRow(
                icon: Icons.schedule_rounded,
                label: 'Pending Payment Request',
                sublabel: 'Submitted, awaiting approval',
                amount: pendingAmt,
                color: Colors.orange.shade600,
              ),
              const SizedBox(height: 10),
            ],
            if (tentativeAmt > 0) ...[
              _EarningsDetailRow(
                icon: Icons.arrow_circle_up_rounded,
                label: 'Available for Request',
                sublabel: 'Eligible deliveries this period',
                amount: tentativeAmt,
                color: ColorStyles.grabGreen,
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 4),
            Text(
              'Amounts update each time you sync or open this page.',
              style: TextStyle(fontSize: 11, color: ColorStyles.subSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Earnings card ────────────────────────────────────────────────────────────

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({
    required this.earnings,
    required this.tentativePayout,
    this.pendingRequestAmt = 0.0,
    this.isLatestPending = false,
    this.showPending = true,
    this.onTap,
  });

  final dynamic earnings;
  final dynamic tentativePayout;
  final dynamic pendingRequestAmt;
  final bool isLatestPending;
  final bool showPending;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tentativeAmt = double.tryParse('$tentativePayout') ?? 0.0;
    final pendingAmt = double.tryParse('$pendingRequestAmt') ?? 0.0;
    final displayAmt = isLatestPending ? pendingAmt : tentativeAmt;
    final displayLabel = isLatestPending ? 'Pending Payment Request' : 'Available for Request';
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
            // AFTER
Row(
  children: [
    Icon(isLatestPending ? Icons.schedule_rounded : Icons.account_balance_wallet_rounded, color: Colors.white70, size: 18),
    const SizedBox(width: 6),
    Text(
      displayLabel,
      style: const TextStyle(color: Colors.white70, fontSize: 13),
    ),
  ],
),
const SizedBox(height: 6),
Text(
  '₱ ${_fmt(displayAmt)}',
  style: const TextStyle(
    color: Colors.white,
    fontSize: 34,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
  ),
),
// Total earnings demoted to a subtle secondary line
const SizedBox(height: 4),
Text(
  'Total earned: ₱ ${_fmt(earnings)}',
  style: const TextStyle(color: Colors.white54, fontSize: 12),
),

            // ── Pending payout rows — online only ─────────────────────────
            if (showPending && isLatestPending && tentativeAmt > 0) ...[
  const SizedBox(height: 14),
  _payoutRow(
    icon: Icons.arrow_circle_up_rounded,
    label: 'Accumulated for next request',
    amount: _fmt(tentativeAmt),
  ),
],

            if (onTap != null) ...[
              const SizedBox(height: 14),
              Center(
                child: Text(
                  'Tap for details',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(dynamic val) {
    final n = double.tryParse('$val') ?? 0.0;
    return n.toStringAsFixed(2);
  }

  Widget _payoutRow({
    required IconData icon,
    required String label,
    required String amount,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const Spacer(),
          Text(
            '₱ $amount',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Payout request history row (used in the history date strip) ─────────────

class _PayoutRequestHistoryRow extends StatelessWidget {
  const _PayoutRequestHistoryRow({required this.data, required this.onTap});

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
    // Compact payment_requests items may omit from/to – fall back to requested_at.
    final dateLabel = (from != '—')
        ? ((from == to || to == '—') ? from : '$from \u2013 $to')
        : formatDate('${data['requested_at'] ?? data['created_at'] ?? ''}');
    final paidAt = formatDate('${data['paid_at'] ?? ''}');
    final totalItems = data['total_items'] ?? data['delivery_count'];

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
                  if (dateLabel != '—') ...[
                    _InfoChip(
                      icon: Icons.calendar_today_outlined,
                      label: dateLabel,
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (totalItems != null) ...[
                    _InfoChip(
                      icon: Icons.inventory_2_outlined,
                      label: '$totalItems items',
                    ),
                  ] else if (paidAt != '—') ...[
                    _InfoChip(icon: Icons.payments_outlined, label: paidAt),
                  ],
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '₱ ${amount.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: ColorStyles.grabGreen,
                            ),
                      ),
                    ],
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
      'paid' => (const Color(0xFFE6F9EE), ColorStyles.grabGreen),
      'approved' || 'ops_approved' || 'hr_approved' => (
        const Color(0xFFE6F2FF),
        Colors.blue.shade700,
      ),
      'rejected' => (const Color(0xFFFFEBEB), Colors.red.shade600),
      'pending' || 'processing' => (
        const Color(0xFFFFF4E0),
        Colors.orange.shade700,
      ),
      _ => (Colors.grey.shade100, Colors.grey.shade600),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.isEmpty ? '—' : status.replaceAll('_', ' ').toUpperCase(),
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

// ─── Earnings detail row (used in bottom sheet) ─────────────────────────────────
class _EarningsDetailRow extends StatelessWidget {
  const _EarningsDetailRow({
    required this.icon,
    required this.label,
    required this.amount,
    required this.color,
    this.sublabel,
    this.large = false,
  });

  final IconData icon;
  final String label;
  final String? sublabel;
  final double amount;
  final Color color;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: large ? 14 : 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? ColorStyles.white : ColorStyles.black,
                ),
              ),
              if (sublabel != null)
                Text(
                  sublabel!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: ColorStyles.subSecondary,
                  ),
                ),
            ],
          ),
        ),
        Text(
          '₱ ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: large ? 18 : 15,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}
