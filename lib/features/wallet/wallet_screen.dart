// DOCS: docs/development-standards.md
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
//   • Balance card — shows current available balance for request fetched from the server.
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
import 'package:easy_localization/easy_localization.dart';

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

import 'package:fsi_courier_app/shared/widgets/offline_banner.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/features/wallet/widgets/payout_history_row.dart';
import 'package:fsi_courier_app/features/wallet/widgets/wallet_flip_card.dart';
import 'package:fsi_courier_app/features/wallet/widgets/payout_window_banner.dart';
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
  List<Map<String, dynamic>> _historyList = [];
  Map<String, dynamic>? _paymentMethod;
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
        _applyDynamicFlags(cachedData);
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
    }

    // Recalculate flags (like has_existing_request_today) based on the latest available data
    // (either fresh from API or from cache) to ensure they are never "stuck" in a stale state.
    _applyDynamicFlags(newData);

    // ── Payout request history (from wallet-summary.payout_history.data) ────
    List<Map<String, dynamic>> historyList = [];
    {
      final historyWrapper = newData['payout_history'] as Map<String, dynamic>?;
      final rawList =
          (historyWrapper?['data'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];

      // Limit payout history to the last 7 days (today + 6 days back).
      // This prevents couriers from browsing arbitrarily old payout requests.
      final now = DateTime.now();
      final cutoff = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 7));

      historyList = rawList.where((req) {
        final status = req['status']?.toString().toUpperCase() ?? '';
        // Always show pending/processing requests so the courier can track them.
        if (status == 'PENDING' || status == 'PROCESSING') return true;

        final raw = (req['requested_at'] ?? req['date'])?.toString() ?? '';

        String dateStr = '';
        if (raw.isNotEmpty) {
          dateStr = raw.contains('T')
              ? raw.split('T').first
              : (raw.contains(' ') ? raw.split(' ').first : raw);
        }

        if (dateStr.isEmpty) return true;

        try {
          final d = DateTime.parse(dateStr);
          final normalized = DateTime(d.year, d.month, d.day);
          return !normalized.isBefore(cutoff);
        } catch (_) {
          return true;
        }
      }).toList();
    }

    // Sort history by date descending (latest first)
    historyList.sort((a, b) {
      final dateA =
          DateTime.tryParse('${a['requested_at'] ?? a['date'] ?? ''}') ??
          DateTime(0);
      final dateB =
          DateTime.tryParse('${b['requested_at'] ?? b['date'] ?? ''}') ??
          DateTime(0);
      return dateB.compareTo(dateA);
    });

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
    _historyList = historyList;
    _paymentMethod = newPaymentMethod;
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
    ref.listen<int>(deliveryRefreshProvider, (_, _) => _load());

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
        child: SecureView(
          child: Scaffold(
            extendBody: true,
            appBar: AppHeaderBar(
              title: 'wallet.screen.title'.tr(),
              pageIcon: Icons.account_balance_wallet_rounded,
            ),
            bottomNavigationBar: null,
            body: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        DSSpacing.md,
                        DSSpacing.md,
                        DSSpacing.md,
                        DSSpacing.xl,
                      ),
                      children: [
                        // ── Offline banner ─────────────────────────────────────
                        if (!isOnline)
                          OfflineBanner(
                            isMinimal: true,
                            customMessage: 'wallet.screen.offline_message'.tr(),
                            margin: const EdgeInsets.only(bottom: DSSpacing.md),
                          ),

                        // ── Already Submitted Notice ───────────────────────────
                        if (isOnline && hasExistingRequestToday)
                          Container(
                            margin: const EdgeInsets.only(bottom: DSSpacing.md),
                            padding: const EdgeInsets.all(DSSpacing.md),
                            decoration: BoxDecoration(
                              color: DSColors.warning.withValues(
                                alpha: DSStyles.alphaSoft,
                              ),
                              borderRadius: DSStyles.cardRadius,
                              border: Border.all(
                                color: DSColors.warning.withValues(
                                  alpha: DSStyles.alphaMuted,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  color: DSColors.warning,
                                  size: DSIconSize.md,
                                ),
                                DSSpacing.wSm,
                                Expanded(
                                  child: Text(
                                    'wallet.screen.existing_request_notice'
                                        .tr(),
                                    style: DSTypography.caption(
                                      color: DSColors.warning,
                                    ).copyWith(fontSize: DSTypography.sizeSm),
                                  ),
                                ),
                              ],
                            ),
                          ).dsFadeEntry(),

                        // ── Earnings / Payout Flip Card ────────────────────────
                        WalletFlipCard(
                          tentativePayout: tentativePayout,
                          pendingRequestAmt: pendingRequestAmt,
                          isLatestPending: isLatestPending,
                          showPending: isOnline,
                          paymentMethod: _paymentMethod,
                          canConsolidate:
                              isOnline &&
                              isLatestPending &&
                              _eligible > 0 &&
                              !hasExistingRequestToday &&
                              isInRequestWindow,
                          canRequest: canRequestPayout && isOnline,
                          onConsolidate: () =>
                              context.push('/wallet/request?consolidate=1'),
                          onRequest: () => context.push('/wallet/request'),
                        ).dsCardEntry(duration: DSAnimations.dNormal),

                        DSSpacing.hLg,

                        // ── Online-only section ──────────────────────────────
                        if (isOnline && !isInRequestWindow) ...[
                          const PayoutWindowBanner(),
                          DSSpacing.hMd,
                        ],

                        if (isOnline) DSSpacing.hLg,

                        if (isOnline && _historyList.isNotEmpty) ...[
                          DSSectionHeader(
                            title: 'wallet.screen.payout_history'.tr(),
                            padding: EdgeInsets.zero,
                          ).dsFadeEntry(delay: DSAnimations.stagger(3)),
                          DSSpacing.hSm,
                          ..._historyList.asMap().entries.map(
                            (entry) =>
                                PayoutHistoryRow(
                                  data: entry.value,
                                  onTap: () {
                                    final refVal =
                                        '${entry.value['reference'] ?? entry.value['payment_reference'] ?? ''}';
                                    if (refVal.isNotEmpty) {
                                      context.push('/wallet/$refVal');
                                    }
                                  },
                                ).dsCardEntry(
                                  delay: DSAnimations.stagger(
                                    entry.key + 1,
                                    step: DSAnimations.staggerNormal,
                                  ),
                                ),
                          ),
                          DSSpacing.hLg,
                        ],
                        DSSpacing.hXl,
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  void _applyDynamicFlags(Map<String, dynamic> data) {
    final latestRequest = data['latest_request'] as Map<String, dynamic>?;
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

    // A request is considered "existing today" only if it was made today AND it is still PENDING.
    // If it was already PAID or REJECTED today, the courier should be allowed to submit a new
    // request for any subsequent earnings.
    data['has_existing_request_today'] =
        latestRequest != null &&
        latestRequest['status']?.toString().toUpperCase() == 'PENDING' &&
        isToday;
  }
}
