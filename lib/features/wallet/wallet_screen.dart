// DOCS: docs/features/wallet.md — update that file when you edit this one.

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

import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/config.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/widgets/date_strip_with_deliveries.dart';
import 'package:fsi_courier_app/shared/widgets/offline_banner.dart';
import 'package:fsi_courier_app/shared/widgets/payment_method_card.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
// confirmation_dialog not used in this file

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

      // Limit payout history to the last 7 days (today + 6 days back).
      // This prevents couriers from browsing arbitrarily old payout requests.
      final now = DateTime.now();
      final cutoff = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 6));
      historyBreakdown = historyBreakdown.where((day) {
        final dateStr = day['date'] as String? ?? '';
        try {
          final d = DateTime.parse(dateStr);
          final normalized = DateTime(d.year, d.month, d.day);
          return !normalized.isBefore(cutoff);
        } catch (_) {
          return true;
        }
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

    // ── Payout request time-window guard ────────────────────────────────────
    // In production, couriers may only request between 06:00 AM and 12:00 PM.
    // In debug builds the restriction is lifted (isWithinPayoutRequestWindow
    // always returns true) so developers can test at any hour.
    final isInRequestWindow = isWithinPayoutRequestWindow();

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
          // bottomNavigationBar: const FloatingBottomNavBar(
          //   currentPath: '/wallet',
          // ),
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

                      // ── Earnings / Payout Flip Card ────────────────────────
                      _WalletFlipCard(
                            tentativePayout: tentativePayout,
                            pendingRequestAmt: pendingRequestAmt,
                            isLatestPending: isLatestPending,
                            showPending: isOnline,
                            paymentMethod: _paymentMethod,
                          )
                          .animate()
                          .fadeIn(duration: 500.ms)
                          .slideY(begin: 0.1, end: 0),

                      const SizedBox(height: 20),

                      // ── Online-only section ──────────────────────────────
                      if (isOnline) ...[
                        // ── Time-window guard ─────────────────────────────────
                        if (!isInRequestWindow) ...[
                          _PayoutWindowBanner(),
                          const SizedBox(height: 12),
                        ],

                        // Request payout / consolidate / pending notice
                        if (canRequestPayout && isInRequestWindow)
                          FilledButton.icon(
                                onPressed: () =>
                                    context.push('/wallet/request'),
                                icon: const Icon(Icons.payments_rounded),
                                label: Text(
                                  kAppDebugMode
                                      ? 'Request Payout (DEBUG)'
                                      : 'Request Payout',
                                ),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: DSStyles.cardRadius,
                                  ),
                                ),
                              )
                              .animate()
                              .fadeIn(delay: 200.ms)
                              .scaleXY(begin: 0.95, end: 1)
                        else if (canRequestPayout && !isInRequestWindow)
                          // Show disabled button with a lock icon so the courier
                          // sees the action but understands it's time-locked.
                          Opacity(
                            opacity: 0.45,
                            child: FilledButton.icon(
                              onPressed: null,
                              icon: const Icon(Icons.lock_clock_rounded),
                              label: const Text('Request Payout'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: DSStyles.cardRadius,
                                ),
                              ),
                            ),
                          )
                        else if (isLatestPending &&
                            _eligible > 0 &&
                            !hasExistingRequestToday &&
                            isInRequestWindow)
                          FilledButton.icon(
                            onPressed: () => context.push(
                              '/wallet/request',
                              extra: {'consolidate': true},
                            ),
                            icon: const Icon(Icons.payments_rounded),
                            label: Text(
                              kAppDebugMode
                                  ? 'Consolidate Payout Request (DEBUG)'
                                  : 'Consolidate Payout Request',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.amber.shade700,
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: DSStyles.cardRadius,
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
                              color: Colors.amber.withValues(
                                alpha: DSStyles.alphaSoft,
                              ),
                              borderRadius: DSStyles.cardRadius,
                              border: Border.all(
                                color: Colors.amber.withValues(
                                  alpha: DSStyles.alphaDarkShadow,
                                ),
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
                          _SectionLabel(
                            'Payout History',
                          ).animate().fadeIn(delay: 300.ms),
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
                          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05, end: 0),
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

// ─── Payout Window Banner ──────────────────────────────────────────────────────
//
// Shown in WalletScreen when the courier is outside the 06:00–12:00 request
// window. Invisible in debug builds because the window check is bypassed.

class _PayoutWindowBanner extends StatelessWidget {
  const _PayoutWindowBanner();

  @override
  Widget build(BuildContext context) {
    // In debug mode the banner should never be shown (isWithinPayoutRequestWindow
    // returns true), but guard here defensively just in case.
    if (kAppDebugMode) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.deepPurple.withValues(alpha: DSStyles.alphaSoft),
          borderRadius: DSStyles.cardRadius,
          border: Border.all(
            color: Colors.deepPurple.withValues(
              alpha: DSStyles.alphaDarkShadow,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.bug_report_rounded,
              color: Colors.deepPurple.shade400,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '(DEBUG) Time restriction bypassed — requests allowed at any hour.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.deepPurple.shade400,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: DSColors.red.withValues(alpha: DSStyles.alphaSoft),
        borderRadius: DSStyles.cardRadius,
        border: Border.all(
          color: DSColors.red.withValues(alpha: DSStyles.alphaDarkShadow),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_clock_rounded, color: DSColors.red, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payout Requests: Morning Only',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: DSColors.red,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'You can request a payout between '
                  '${kPayoutWindowStartHour.toString().padLeft(2, '0')}:00 AM '
                  'and '
                  '${kPayoutWindowEndHour == 12 ? '12:00 PM (noon)' : '${kPayoutWindowEndHour.toString().padLeft(2, '0')}:00'}. '
                  'Please come back during that window.',
                  style: TextStyle(
                    fontSize: 12,
                    color: DSColors.red.withValues(alpha: DSStyles.alphaGlass),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Flip Card Component ──────────────────────────────────────────────────

class _WalletFlipCard extends StatefulWidget {
  const _WalletFlipCard({
    required this.tentativePayout,
    required this.pendingRequestAmt,
    required this.isLatestPending,
    required this.showPending,
    required this.paymentMethod,
  });

  final dynamic tentativePayout;
  final dynamic pendingRequestAmt;
  final bool isLatestPending;
  final bool showPending;
  final Map<String, dynamic>? paymentMethod;

  @override
  State<_WalletFlipCard> createState() => _WalletFlipCardState();
}

class _WalletFlipCardState extends State<_WalletFlipCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    if (!mounted) return;
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() => _isFront = !_isFront);
  }

  @override
  Widget build(BuildContext context) {
    // If not latest pending, only show the front (no flip needed)
    if (!widget.isLatestPending || widget.paymentMethod == null) {
      return _EarningsCard(
        tentativePayout: widget.tentativePayout,
        pendingRequestAmt: widget.pendingRequestAmt,
        isLatestPending: widget.isLatestPending,
        showPending: widget.showPending,
        onTap: null, // No flip possible without pending + method
      );
    }

    return GestureDetector(
      onTap: _flip,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final val = _controller.value;
          final isUnder = val > 0.5;

          // Standard flip transition logic — uses rotateX for vertical roll.
          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.0012) // Slightly more perspective
            ..rotateX(val * 3.141592653589793); // pi

          return Transform(
            transform: transform,
            alignment: Alignment.center,
            child: isUnder
                ? Transform(
                    transform: Matrix4.identity()
                      ..rotateX(3.141592653589793), // flipped back correctly
                    alignment: Alignment.center,
                    child: _buildBack(),
                  )
                : _EarningsCard(
                    tentativePayout: widget.tentativePayout,
                    pendingRequestAmt: widget.pendingRequestAmt,
                    isLatestPending: widget.isLatestPending,
                    showPending: widget.showPending,
                    // Pass a null callback because GestureDetector handles it.
                    onTap: null,
                    isFlipping: true,
                  ),
          );
        },
      ),
    );
  }

  Widget _buildBack() {
    return _EarningsCard(
      tentativePayout: widget.tentativePayout,
      pendingRequestAmt: widget.pendingRequestAmt,
      isLatestPending: widget.isLatestPending,
      showPending: widget.showPending,
      onTap: null,
      isFlipping: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PaymentMethodCard(data: widget.paymentMethod, isTransparent: true),
          const SizedBox(height: 12),
          Text(
            'Tap to flip back',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: DSStyles.alphaGlass),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Earnings card ────────────────────────────────────────────────────────────

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({
    required this.tentativePayout,
    this.pendingRequestAmt = 0.0,
    this.isLatestPending = false,
    this.showPending = true,
    this.onTap,
    this.isFlipping = false,
    this.child,
  });

  final dynamic tentativePayout;
  final dynamic pendingRequestAmt;
  final bool isLatestPending;
  final bool showPending;
  final VoidCallback? onTap;
  final bool isFlipping;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final tentativeAmt = double.tryParse('$tentativePayout') ?? 0.0;
    final pendingAmt = double.tryParse('$pendingRequestAmt') ?? 0.0;
    final displayAmt = tentativeAmt;
    final displayLabel = isLatestPending
        ? 'Accumulated Earnings'
        : 'Available for Payout';

    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF007A36), Color(0xFF00B14F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: DSStyles.cardRadius,
        boxShadow: [
          BoxShadow(
            color: DSColors.primary.withValues(alpha: DSStyles.alphaDarkShadow),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: DSStyles.cardRadius,
          highlightColor: Colors.white.withValues(alpha: DSStyles.alphaSoft),
          splashColor: Colors.white.withValues(alpha: DSStyles.alphaSoft),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child:
                child ??
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white.withValues(
                            alpha: DSStyles.alphaGlass,
                          ),
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          displayLabel,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        if (isLatestPending)
                          const Icon(
                            Icons.unfold_more_rounded,
                            color: Colors.white60,
                            size: 16,
                          ),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        // Currency symbol offset to align numbers with label text above
                        SizedBox(
                          width: 24,
                          child: Text(
                            '₱',
                            style: TextStyle(
                              color: Colors.white.withValues(
                                alpha: DSStyles.alphaGlass,
                              ),
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          _fmt(displayAmt),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),

                    // ── If flipping enabled: hint for tapping ──
                    if (isFlipping) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Tap to view payout account',
                        style: TextStyle(
                          color: Colors.white.withValues(
                            alpha: DSStyles.alphaBorder,
                          ),
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],

                    // ── If pending: show pending request as secondary info ──
                    if (showPending && isLatestPending && pendingAmt > 0) ...[
                      const SizedBox(height: 14),
                      _payoutRow(
                        icon: Icons.schedule_rounded,
                        label: 'Pending Payment Request',
                        amount: _fmt(pendingAmt),
                      ),
                    ],
                  ],
                ),
          ),
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
        color: Colors.transparent,
        borderRadius: DSStyles.cardRadius,
        border: Border.all(
          color: Colors.white.withValues(alpha: DSStyles.alphaBorder),
          width: 1,
        ),
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
      margin: const EdgeInsets.only(top: 8),
      shape: RoundedRectangleBorder(
        borderRadius: DSStyles.cardRadius,
        side: BorderSide(
          color: Theme.of(
            context,
          ).dividerColor.withValues(alpha: DSStyles.alphaBorder),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: DSStyles.cardRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Row (Reference + Status Badge) ─────────────────────
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
              const SizedBox(height: 14),

              // ── Values Row (Date/Items + Amount) ──────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (dateLabel != '—') ...[
                    _InfoChip(
                      icon: Icons.calendar_today_outlined,
                      label: dateLabel,
                    ),
                    const SizedBox(width: 8),
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
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '₱ ',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: DSColors.primary.withValues(
                              alpha: DSStyles.alphaGlass,
                            ),
                          ),
                        ),
                        TextSpan(
                          text: amount.toStringAsFixed(2),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: DSColors.primary,
                              ),
                        ),
                      ],
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
    final (bg, fg) = switch (status.toUpperCase()) {
      'PAID' => (const Color(0xFFE6F9EE), DSColors.primary),
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
      decoration: BoxDecoration(color: bg, borderRadius: DSStyles.cardRadius),
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
