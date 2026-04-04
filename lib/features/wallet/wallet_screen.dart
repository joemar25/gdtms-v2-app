// =============================================================================
// wallet_screen.dart
// =============================================================================
//
// Purpose:
//   Displays the courier's earnings wallet — their current balance, payout
//   history, and the list of delivered items that are eligible for payout.
//
// Key behaviours:
//   • Balance card — shows current available balance fetched from the server.
//   • Delivered items list — paginated list of delivered parcels with their
//     individual fees. Only deliveries that pass visibility rules (e.g. within
//     the payout window, not already paid out) are shown. Locked items that
//     fail visibility show a grey lock icon on the trailing edge.
//   • REQUEST PAYOUT button — navigates to PayoutRequestScreen when the
//     balance meets the minimum payout threshold.
//   • Payout history — list of past payout requests with status (pending,
//     approved, released) and amounts.
//   • Offline guard — balance and history require connectivity; cached data is
//     shown with a stale indicator when offline.
//
// Data:
//   GET /wallet — balance and payout history (requires connectivity).
//   Delivered items sourced from local SQLite via [LocalDeliveryDao].
//
// Navigation:
//   Route: /wallet
//   Pushed from: DashboardScreen WALLET card
//   Pushes to: PayoutRequestScreen
// =============================================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/widgets/date_strip_with_deliveries.dart';
import 'package:fsi_courier_app/shared/widgets/floating_bottom_nav_bar.dart';
import 'package:fsi_courier_app/shared/widgets/offline_banner.dart';
import 'package:fsi_courier_app/shared/widgets/payment_method_card.dart';
// confirmation_dialog not used in this file
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
  Map<String, dynamic>? _paymentMethod;
  String? _initialHistoryDate;
  int _stripKey = 0;
  double _horizontalDrag = 0.0;

  static const _earningsCacheKey = 'wallet_summary_cache';
  static const _paymentMethodCacheKey = 'wallet_payment_method_cache';

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

    // Load cached payment method
    final cachedPm = prefs.getString(_paymentMethodCacheKey);
    Map<String, dynamic>? cachedPaymentMethod;
    if (cachedPm != null && cachedPm.isNotEmpty) {
      try {
        cachedPaymentMethod = jsonDecode(cachedPm) as Map<String, dynamic>;
      } catch (_) {}
    }

    if (!ref.read(isOnlineProvider)) {
      if (mounted) {
        _data = cachedData;
        _eligible = cachedEligible;
        _paymentMethod = cachedPaymentMethod;
        setState(() => _loading = false);
      }
      return;
    }

    // Online: fetch summary + payment method in parallel
    final api = ref.read(apiClientProvider);
    final futures = await Future.wait([
      api.get<Map<String, dynamic>>('/wallet-summary', parser: parseApiMap),
      api.get<Map<String, dynamic>>('/me/payment-method', parser: parseApiMap),
    ]);
    final result = futures[0];
    final pmResult = futures[1];

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
          final parsedDate = parseServerDate(requestedAt);
          if (parsedDate != null) {
            final reqDate = parsedDate.toLocal();
            final now = DateTime.now();
            isToday =
                reqDate.year == now.year &&
                reqDate.month == now.month &&
                reqDate.day == now.day;
          }
        } catch (_) {}
      }
      newData['has_existing_request_today'] =
          latestRequest != null &&
          latestRequest['status']?.toString().toUpperCase() == 'PENDING' &&
          isToday;
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
        final raw =
            dateField ??
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

    // Parse payment method result
    Map<String, dynamic>? newPaymentMethod = cachedPaymentMethod;
    if (pmResult case ApiSuccess<Map<String, dynamic>>(:final data)) {
      newPaymentMethod = mapFromKey(data, 'data');
    }

    // Persist both snapshots
    await Future.wait([
      prefs.setString(
        _earningsCacheKey,
        jsonEncode({'summary': newData, 'eligible': newEligible}),
      ),
      if (newPaymentMethod != null)
        prefs.setString(_paymentMethodCacheKey, jsonEncode(newPaymentMethod))
      else
        Future<void>.value(),
    ]);

    if (!mounted) return;

    _data = newData;
    _eligible = newEligible;
    _historyBreakdown = historyBreakdown;
    _paymentMethod = newPaymentMethod;
    _stripKey++;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);

    final tentativePayout = _data['tentative_pending_payout'] ?? 0;
    final latest = _data['latest_request'] ?? {};
    final latestStatus = latest['status']?.toString().toUpperCase() ?? '';
    final isLatestPending =
        latestStatus == 'PENDING' ||
        latestStatus == 'PROCESSING' ||
        latestStatus == 'OPS_APPROVED' ||
        latestStatus == 'HR_APPROVED' ||
        latestStatus == 'APPROVED';

    final pendingRequestAmt = isLatestPending ? (latest['amount'] ?? 0) : 0;

    // Use has_existing_request_today from the latest API preview if available
    final hasExistingRequestToday = _data['has_existing_request_today'] == true;
    final canRequestPayout = !isLatestPending && !hasExistingRequestToday;

    ref.listen<int>(walletRefreshProvider, (_, _) => _load());

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // When on Wallet, prefer navigating back to Dashboard (home)
        // so that the ultimate back on Dashboard triggers the exit dialog.
        context.go('/dashboard');
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) =>
            _horizontalDrag += details.delta.dx,
        onHorizontalDragEnd: (details) {
          final dx = _horizontalDrag;
          _horizontalDrag = 0.0;
          final velocity = details.primaryVelocity ?? 0.0;
          if (dx.abs() > 60 || velocity.abs() > 300) {
            if (dx < 0 || velocity < 0) {
              // swipe left → Profile
              context.go('/profile', extra: {'_swipe': 'left'});
            } else {
              // swipe right → Dashboard
              context.go('/dashboard', extra: {'_swipe': 'right'});
            }
          }
        },
        child: Scaffold(
          extendBody: true,
          appBar: const AppHeaderBar(
            title: 'Wallet',
            pageIcon: Icons.account_balance_wallet_rounded,
          ),
          bottomNavigationBar: const FloatingBottomNavBar(
            currentPath: '/wallet',
          ),
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

                      // ── Earnings card (show when there's something actionable) ─
                      if (tentativePayout > 0 || isLatestPending)
                        _EarningsCard(
                          tentativePayout: tentativePayout,
                          pendingRequestAmt: pendingRequestAmt,
                          isLatestPending: isLatestPending,
                          showPending: isOnline,
                        ),

                      const SizedBox(height: 20),

                      // ── Online-only section ──────────────────────────────
                      if (isOnline) ...[
                        // Payment method card
                        if (_paymentMethod != null) ...[
                          PaymentMethodCard(data: _paymentMethod),
                          const SizedBox(height: 16),
                        ],

                        // Request payout / consolidate / pending notice
                        if (canRequestPayout)
                          FilledButton.icon(
                            onPressed: () => context.push('/wallet/request'),
                            // FIX: Icons.currency_peso not available in older Flutter SDK.
                            // Replaced with Icons.payments_rounded which is universally available.
                            icon: const Icon(Icons.payments_rounded),
                            label: const Text('Request Payout'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          )
                        else if (isLatestPending &&
                            _eligible > 0 &&
                            !hasExistingRequestToday)
                          FilledButton.icon(
                            onPressed: () => context.push(
                              '/wallet/request',
                              extra: {'consolidate': true},
                            ),
                            // FIX: Icons.currency_peso not available in older Flutter SDK.
                            // Replaced with Icons.payments_rounded which is universally available.
                            icon: const Icon(Icons.payments_rounded),
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
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  // _showEarningsDetail removed — unused helper
}

// ─── Earnings card ────────────────────────────────────────────────────────────

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({
    required this.tentativePayout,
    this.pendingRequestAmt = 0.0,
    this.isLatestPending = false,
    this.showPending = true,
  });

  final dynamic tentativePayout;
  final dynamic pendingRequestAmt;
  final bool isLatestPending;
  final bool showPending;

  @override
  Widget build(BuildContext context) {
    final tentativeAmt = double.tryParse('$tentativePayout') ?? 0.0;
    final pendingAmt = double.tryParse('$pendingRequestAmt') ?? 0.0;
    final displayAmt = isLatestPending ? pendingAmt : tentativeAmt;
    final displayLabel = isLatestPending
        ? 'Pending Payment Request'
        : 'Available for Request';
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
              Icon(
                isLatestPending
                    ? Icons.schedule_rounded
                    : Icons.account_balance_wallet_rounded,
                color: Colors.white70,
                size: 18,
              ),
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

          // ── If pending: also show accumulated available for next request ──
          if (showPending && isLatestPending && tentativeAmt > 0) ...[
            const SizedBox(height: 14),
            _payoutRow(
              icon: Icons.arrow_circle_up_rounded,
              label: 'Accumulated for next request',
              amount: _fmt(tentativeAmt),
            ),
          ],
        ],
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
                    Flexible(
                      child: _InfoChip(
                        icon: Icons.calendar_today_outlined,
                        label: dateLabel,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (totalItems != null) ...[
                    Flexible(
                      child: _InfoChip(
                        icon: Icons.inventory_2_outlined,
                        label: '$totalItems items',
                      ),
                    ),
                  ] else if (paidAt != '—') ...[
                    Flexible(
                      child: _InfoChip(
                        icon: Icons.payments_outlined,
                        label: paidAt,
                      ),
                    ),
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
    final (bg, fg) = switch (status.toUpperCase()) {
      'PAID' => (const Color(0xFFE6F9EE), ColorStyles.grabGreen),
      'APPROVED' ||
      'OPS_APPROVED' ||
      'HR_APPROVED' => (const Color(0xFFE6F2FF), Colors.blue.shade700),
      'REJECTED' => (const Color(0xFFFFEBEB), Colors.red.shade600),
      'PENDING' ||
      'PROCESSING' => (const Color(0xFFFFF4E0), Colors.orange.shade700),
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
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
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

// Earnings detail row removed — it was unused and triggered analyzer warnings.
