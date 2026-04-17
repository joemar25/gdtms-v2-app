// DOCS: docs/features/delivery.md — update that file when you edit this one.

// =============================================================================
// delivery_status_list_screen.dart
// =============================================================================
//
// Purpose:
//   A single reusable paginated list screen that displays deliveries filtered
//   by a specific status (PENDING, DELIVERED, FAILED_DELIVERY, OSA, DISPATCHED). It is
//   instantiated once per status tab on the dashboard.
//
// Key behaviours:
//   • Offline-first — all data is read from local SQLite, never directly from
//     the API during normal list render.
//   • Sync-lock badges — deliveries with an active sync-queue entry show a blue
//     "PENDING SYNC" badge and their UPDATE action is disabled on the detail
//     screen, preventing double-submission.
//   • Pagination — configurable page size (_kPageSize). Swipe left/right
//     to navigate pages with haptic feedback.
//   • Search — full-text search across barcode and recipient name, debounced.
//   • Status summary strip — shows total, unsynced, and in-queue counts at
//     the top of the list when results are present.
//   • Pull-to-refresh — triggers a bootstrap from the server when online.
//
// Data:
//   [LocalDeliveryDao] + [SyncOperationsDao] → SQLite (offline-first).
//   Refresh is triggered via [deliveryRefreshProvider].
//
// Navigation:
//   Route: /deliveries?status=<STATUS>
//   Pushed from: DashboardScreen stat cards
// =============================================================================

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/database/sync_operations_dao.dart';
import 'package:fsi_courier_app/core/models/delivery_status.dart';
import 'package:fsi_courier_app/core/models/local_delivery.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/core/settings/compact_mode_provider.dart';
import 'package:fsi_courier_app/core/sync/delivery_bootstrap_service.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_helper.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_identifier.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/widgets/delivery_card.dart';
import 'package:fsi_courier_app/shared/widgets/pagination_bar.dart';
import 'package:fsi_courier_app/shared/widgets/search_bar.dart';
import 'package:fsi_courier_app/shared/widgets/offline_banner.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

/// A single list screen reused for every delivery status filter
/// (pending, delivered, failed_delivery, osa, dispatched).
///
/// Data is always read from local SQLite — the app is offline-first.
/// The list refreshes whenever [deliveryRefreshProvider] increments (on
/// dispatch acceptance or after a successful sync).
class DeliveryStatusListScreen extends ConsumerStatefulWidget {
  const DeliveryStatusListScreen({
    super.key,
    required this.status,
    required this.title,
    this.initialSearch,
  });

  final String status;
  final String title;

  /// When set, the search bar is opened automatically with this query
  /// pre-populated. Used when navigating from the dashboard header search.
  final String? initialSearch;

  @override
  ConsumerState<DeliveryStatusListScreen> createState() =>
      _DeliveryStatusListScreenState();
}

class _DeliveryStatusListScreenState
    extends ConsumerState<DeliveryStatusListScreen> {
  // ── Page state ─────────────────────────────────────────────────────────────
  bool _loading = true;
  int _currentPage = 0;
  int _totalCount = 0;
  List<Map<String, dynamic>> _items = [];

  int get _kPageSize => ref.read(compactModeProvider)
      ? kCompactDeliveriesPerPage
      : kDeliveriesPerPage;

  int get _totalPages => (_totalCount / _kPageSize).ceil().clamp(1, 999999);
  int get _firstItem => _totalCount == 0 ? 0 : _currentPage * _kPageSize + 1;
  int get _lastItem => (_firstItem + _items.length - 1).clamp(0, _totalCount);

  // ── Search state ───────────────────────────────────────────────────────────
  bool _showSearch = false;
  String _searchQuery = '';
  bool _searchLoading = false;
  List<Map<String, dynamic>> _searchResults = [];
  final _searchController = TextEditingController();

  // ── Scroll ─────────────────────────────────────────────────────────────────
  final _scrollController = ScrollController();

  // ── Sync-lock ──────────────────────────────────────────────────────────────
  Set<String> _queuedBarcodes = {};

  // ── Failed-delivery sub-filter ─────────────────────────────────────────────
  /// 'redelivery' = attempts < 3 and not RTS-verified
  /// 'rts'        = attempts >= 3 or RTS-verified
  String _failedSubFilter = 'redelivery';

  List<Map<String, dynamic>> get _displayed =>
      _searchQuery.trim().isNotEmpty ? _searchResults : _items;

  List<Map<String, dynamic>> get _failedFiltered {
    final base = _displayed;
    if (widget.status.toUpperCase() != 'FAILED_DELIVERY') return base;
    return base.where((d) {
      final attempts = getAttemptsCountFromMap(d);
      final vStr =
          (d['_rts_verification_status'] ?? 'unvalidated')
              .toString()
              .toLowerCase();
      final rv = FailedDeliveryVerificationStatus.fromString(vStr);
      final isRts = attempts >= 3 || rv.isVerified;
      return _failedSubFilter == 'rts' ? isRts : !isRts;
    }).toList();
  }

  int _countFailedSubGroup(String group) {
    if (widget.status.toUpperCase() != 'FAILED_DELIVERY') return 0;
    return _items.where((d) {
      final attempts = getAttemptsCountFromMap(d);
      final vStr =
          (d['_rts_verification_status'] ?? 'unvalidated')
              .toString()
              .toLowerCase();
      final rv = FailedDeliveryVerificationStatus.fromString(vStr);
      final isRts = attempts >= 3 || rv.isVerified;
      return group == 'rts' ? isRts : !isRts;
    }).length;
  }

  @override
  void initState() {
    super.initState();
    final q = widget.initialSearch?.trim() ?? '';
    if (q.isNotEmpty) {
      _showSearch = true;
      _searchQuery = q;
      _searchController.text = q;
      _load().then((_) => _runSearch(q));
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final offset = _currentPage * _kPageSize;
    final rows = await _fetchPage(offset: offset);
    final total = switch (widget.status.toUpperCase()) {
      'DELIVERED' => await LocalDeliveryDao.instance.countVisibleDelivered(),
      'FAILED_DELIVERY' =>
        await LocalDeliveryDao.instance.countVisibleFailedDelivery(),
      'OSA' => await LocalDeliveryDao.instance.countVisibleOsa(),
      _ => await LocalDeliveryDao.instance.countByStatus(widget.status),
    };
    if (!mounted) return;
    final courierId = ref.read(authProvider).courier?['id']?.toString() ?? '';
    _queuedBarcodes = await SyncOperationsDao.instance.getSyncQueuedBarcodes(
      courierId,
    );
    if (!mounted) return;
    final totalPages = (total / _kPageSize).ceil().clamp(1, 999999);
    if (_currentPage > 0 && _currentPage >= totalPages) {
      _currentPage = totalPages - 1;
      return _load();
    }
    setState(() {
      _items = rows.map(_toCardMap).toList();
      _totalCount = total;
      _loading = false;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  Future<List<LocalDelivery>> _fetchPage({required int offset}) {
    final status = widget.status.toUpperCase();
    return switch (status) {
      'DELIVERED' => LocalDeliveryDao.instance.getVisibleDeliveredPaged(
        limit: _kPageSize,
        offset: offset,
      ),
      'FAILED_DELIVERY' =>
        LocalDeliveryDao.instance.getVisibleFailedDeliveryPaged(
          limit: _kPageSize,
          offset: offset,
        ),
      'OSA' => LocalDeliveryDao.instance.getVisibleOsaPaged(
        limit: _kPageSize,
        offset: offset,
      ),
      _ => LocalDeliveryDao.instance.getByStatusPaged(
        status,
        limit: _kPageSize,
        offset: offset,
      ),
    };
  }

  Future<void> _goToPage(int page) async {
    if (page < 0 || page >= _totalPages || page == _currentPage) return;
    _currentPage = page;
    await _load();
  }

  Future<void> _onRefresh() async {
    final isOnline = ref.read(isOnlineProvider);
    if (isOnline) {
      await DeliveryBootstrapService.instance.syncFromApi(
        ref.read(apiClientProvider),
      );
    }
    _currentPage = 0;
    await _load();
    if (_searchQuery.trim().isNotEmpty) await _runSearch(_searchQuery);
  }

  Future<void> _runSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchLoading = false;
      });
      return;
    }
    setState(() => _searchLoading = true);
    final rows = await LocalDeliveryDao.instance.searchByStatusAndQuery(
      widget.status,
      q,
    );
    if (!mounted) return;
    setState(() {
      _searchResults = rows.map(_toCardMap).toList();
      _searchLoading = false;
    });
  }

  Map<String, dynamic> _toCardMap(LocalDelivery row) {
    final base = row.toDeliveryMap();
    if (!base.containsKey('barcode_value') || base['barcode_value'] == null) {
      base['barcode_value'] = row.barcode;
    }
    if (row.paidAt != null) base['_paid_at'] = row.paidAt;
    base['_rts_verification_status'] = row.rtsVerificationStatus;
    base['_sync_status'] = row.syncStatus;
    base['_in_sync_queue'] = _queuedBarcodes.contains(row.barcode);
    return base;
  }

  List<Widget> _buildActions(BuildContext context) {
    final searchBtn = IconButton(
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        transitionBuilder: (child, anim) => ScaleTransition(
          scale: anim,
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: Icon(
          _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
          key: ValueKey(_showSearch),
        ),
      ),
      tooltip: 'Search',
      onPressed: () {
        HapticFeedback.lightImpact();
        setState(() {
          _showSearch = !_showSearch;
          if (!_showSearch) {
            _searchQuery = '';
            _searchResults = [];
            _searchController.clear();
          }
        });
      },
    );
    final status = widget.status.toUpperCase();
    return switch (status) {
      'PENDING' => [
        searchBtn,
        IconButton(
          icon: const Icon(Icons.qr_code_scanner_rounded),
          tooltip: 'Scan POD',
          onPressed: () => context.push('/scan', extra: {'mode': 'pod'}),
        ),
      ],
      'FAILED_DELIVERY' => [
        searchBtn,
        IconButton(
          icon: const Icon(Icons.help_outline_rounded),
          tooltip: 'Failed Delivery Logic',
          onPressed: () => _showFailedDeliveryHelpBottomSheet(context),
        ),
        IconButton(
          icon: const Icon(Icons.qr_code_scanner_rounded),
          tooltip: 'Scan Dispatch',
          onPressed: () => context.push('/scan', extra: {'mode': 'dispatch'}),
        ),
      ],
      _ => [searchBtn],
    };
  }

  String _emptyMessage() => switch (widget.status.toUpperCase()) {
    'PENDING' => 'No active deliveries.',
    'DELIVERED' => 'No delivered items today.',
    'DISPATCHED' => 'No dispatched items.',
    'FAILED_DELIVERY' => _failedSubFilter == 'rts'
        ? 'No items for return today.'
        : 'No items available for redelivery.',
    'OSA' => 'No OSA mailpacks today.',
    _ => 'No items found.',
  };

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(deliveryRefreshProvider, (_, _) {
      _currentPage = 0;
      _load();
    });

    ref.listen<bool>(compactModeProvider, (_, _) {
      _currentPage = 0;
      _load();
    });

    final isCompact = ref.watch(compactModeProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final displayed = _failedFiltered;
    final isSearching = _searchQuery.trim().isNotEmpty;
    final isFailedDelivery =
        widget.status.toUpperCase() == 'FAILED_DELIVERY';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) return;
        // 1. Instantly kill keyboard focus to avoid viewport jumps
        FocusManager.instance.primaryFocus?.unfocus();

        if (_showSearch) {
          // 2. We don't call setState here to avoid triggering layout animations
          // during a pop transition, but we clear the state so that if
          // the user navigates back to this status list, it's fresh.
          _showSearch = false;
          _searchQuery = '';
          _searchResults = [];
          _searchController.clear();
        }
      },
      child: Scaffold(
        backgroundColor: isDark
            ? DSColors.scaffoldDark
            : DSColors.scaffoldLight,
        appBar: AppHeaderBar(
          title: widget.title,
          actions: _buildActions(context),
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity < -200 && _currentPage < _totalPages - 1) {
              HapticFeedback.mediumImpact();
              _goToPage(_currentPage + 1);
            } else if (velocity > 200 && _currentPage > 0) {
              HapticFeedback.mediumImpact();
              _goToPage(_currentPage - 1);
            }
          },
          child: Column(
            children: [
              // ── Search bar ─────────────────────────────────────────────────────
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutQuart,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  reverseDuration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutQuart,
                  switchOutCurve: Curves.easeInQuad,
                  transitionBuilder: (child, anim) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0, -0.2),
                      end: Offset.zero,
                    ).animate(anim);
                    return FadeTransition(
                      opacity: anim,
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                  child: _showSearch
                      ? AppSearchBar(
                          key: const ValueKey('search_bar'),
                          autofocus: true,
                          controller: _searchController,
                          query: _searchQuery,
                          hintText: 'BARCODE OR NAME',
                          isLoading: _searchLoading,
                          resultCount: isSearching
                              ? (_searchLoading ? null : _searchResults.length)
                              : null,
                          totalCount: (!isSearching && _searchQuery.isEmpty)
                              ? _totalCount
                              : null,
                          onChanged: (v) {
                            setState(() => _searchQuery = v);
                            _runSearch(v);
                          },
                          onClear: () {
                            setState(() {
                              _searchQuery = '';
                              _searchResults = [];
                              _searchController.clear();
                            });
                          },
                        )
                      : const SizedBox.shrink(key: ValueKey('empty')),
                ),
              ),

              // ── Failed-delivery sub-filter chips ──────────────────────────────
              if (isFailedDelivery)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      _FailedFilterChip(
                        label: 'For Redelivery',
                        icon: Icons.local_shipping_rounded,
                        selected: _failedSubFilter == 'redelivery',
                        count: _countFailedSubGroup('redelivery'),
                        color: DSColors.red,
                        isDark: isDark,
                        onTap: () => setState(
                          () => _failedSubFilter = 'redelivery',
                        ),
                      ),
                      const SizedBox(width: 8),
                      _FailedFilterChip(
                        label: 'For Return',
                        icon: Icons.assignment_return_rounded,
                        selected: _failedSubFilter == 'rts',
                        count: _countFailedSubGroup('rts'),
                        color: DeliveryCard.statusColor('FAILED_DELIVERY'),
                        isDark: isDark,
                        onTap: () =>
                            setState(() => _failedSubFilter = 'rts'),
                      ),
                    ],
                  ),
                ),

              // ── List ───────────────────────────────────────────────────────────
              Expanded(
                child: RefreshIndicator(
                  color: DSColors.red,
                  onRefresh: _onRefresh,
                  child: _loading
                      ? Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(DSColors.red),
                          ),
                        )
                      : (_searchLoading && displayed.isEmpty)
                      ? Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(DSColors.red),
                          ),
                        )
                      : displayed.isEmpty
                      ? _EmptyState(
                          message: isSearching
                              ? 'No results for "$_searchQuery".'
                              : _emptyMessage(),
                          status: widget.status,
                          isSearching: isSearching,
                          isDark: isDark,
                        )
                      : SlidableAutoCloseBehavior(
                          // Ensure other Slidables close automatically when one opens
                          child: ListView.builder(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            itemCount:
                                displayed.length + _bannerCount(isOnline),
                            itemBuilder: (context, index) {
                              final banners = _bannerCount(isOnline);
                              if (index < banners) {
                                return _buildBanner(index, isOnline, isDark);
                              }
                              final d = displayed[index - banners];
                              final identifier = resolveDeliveryIdentifier(d);
                              final deliveryStatus =
                                  d['delivery_status']?.toString() ?? 'PENDING';
                              final isLocked = checkIsLockedFromMap(d);
                              final canUpdate =
                                  identifier.isNotEmpty &&
                                  !isLocked &&
                                  deliveryStatus.toUpperCase() != 'OSA';

                              return DeliveryCard(
                                delivery: d,
                                compact: isCompact,
                                showChevron: !isLocked,
                                onUpdateTap: canUpdate
                                    ? () => context.push(
                                        '/deliveries/$identifier/update',
                                      )
                                    : null,
                                onTap: (identifier.isEmpty)
                                    ? () {}
                                    : (isLocked)
                                    ? () {
                                        final s = deliveryStatus.toUpperCase();
                                        final v =
                                            (d['_rts_verification_status'] ??
                                                    d['_failed_delivery_verification_status'] ??
                                                    'unvalidated')
                                                .toString()
                                                .toLowerCase();
                                        final attemptsCount =
                                            getAttemptsCountFromMap(d);

                                        final ds = DeliveryStatus.fromString(s);
                                        final rv =
                                            FailedDeliveryVerificationStatus.fromString(
                                              v,
                                            );
                                        String msg =
                                            'This delivery is ${ds.displayName.toLowerCase()} and cannot be opened.';
                                        if (ds == DeliveryStatus.osa) {
                                          msg =
                                              'This item is marked OSA and cannot be opened.';
                                        } else if (ds ==
                                            DeliveryStatus.delivered) {
                                          msg =
                                              'This item has already been delivered and is sealed.';
                                        } else if (ds ==
                                                DeliveryStatus.failedDelivery &&
                                            attemptsCount >= 3) {
                                          msg =
                                              'This failed delivery has reached the maximum number of attempts and is locked.';
                                        } else if (ds ==
                                                DeliveryStatus.failedDelivery &&
                                            rv.isVerified) {
                                          msg =
                                              'This failed delivery has already been verified and is no longer actionable.';
                                        }
                                        showInfoNotification(context, msg);
                                      }
                                    : () => context.push(
                                        '/deliveries/$identifier',
                                      ),
                              );
                            },
                          ),
                        ),
                ),
              ),

              // ── Pagination bar ─────────────────────────────────────────────────
              if (!isSearching && !_loading && _totalCount > _kPageSize)
                PaginationBar(
                  currentPage: _currentPage,
                  totalPages: _totalPages,
                  firstItem: _firstItem,
                  lastItem: _lastItem,
                  totalCount: _totalCount,
                  onPageChanged: _goToPage,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFailedDeliveryHelpBottomSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final failedDeliveryColor = DeliveryCard.statusColor('FAILED_DELIVERY');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: DSStyles.alphaDarkShadow),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: DSStyles.pillRadius,
              ),
            ),
            const SizedBox(height: 24),

            // Header Icon & Title
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: failedDeliveryColor.withValues(
                        alpha: DSStyles.alphaSoft,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.assignment_return_rounded,
                      color: failedDeliveryColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Failed Delivery & Payments',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'How things work in the system',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white38 : Colors.black26,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Help Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: DSStyles.alphaSoft)
                      : const Color(0xFFF8FAFC),
                  borderRadius: DSStyles.cardRadius,
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: [
                    _HelpItem(
                      icon: Icons.inventory_2_outlined,
                      title: 'Delivery Back to FSI',
                      description:
                          'If a failed delivery is returned to FSI, it will be automatically validated for payment by the site team.',
                      isDark: isDark,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1),
                    ),
                    _HelpItem(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Automatic Consolidation',
                      description:
                          // 'If validated "With Pay", the item will be automatically consolidated into your existing old payment request, if one is available.',
                          'If validated, the item will be automatically consolidated into your existing payment request, if one is available.',
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Footer note
            Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      failedDeliveryColor.withValues(
                        alpha: DSStyles.alphaActiveAccent,
                      ),
                      failedDeliveryColor.withValues(alpha: DSStyles.alphaSoft),
                    ],
                  ),
                  borderRadius: DSStyles.cardRadius,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: failedDeliveryColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This ensures your payments are tracked accurately without manual intervention.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? failedDeliveryColor.withValues(
                                  alpha: DSStyles.alphaGlass,
                                )
                              : failedDeliveryColor.withValues(
                                  alpha: DSStyles.alphaGlass,
                                ),
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  int _bannerCount(bool isOnline) {
    final ds = DeliveryStatus.fromString(widget.status);
    int count = 0;
    if (!isOnline) count++;
    if (ds == DeliveryStatus.osa) count++;
    if (ds == DeliveryStatus.failedDelivery) count++;
    if (ds == DeliveryStatus.delivered) count++;
    return count;
  }

  Widget _buildBanner(int index, bool isOnline, bool isDark) {
    final ds = DeliveryStatus.fromString(widget.status);
    int slot = 0;

    if (!isOnline) {
      if (index == slot) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: OfflineBanner(isMinimal: true),
        );
      }
      slot++;
    }

    if (ds == DeliveryStatus.osa && index == slot) {
      return _StatusInfoBanner(
        icon: Icons.inventory_2_rounded,
        message: 'OSA items can\'t be opened. Return to FSI for verification.',
        statusColor: DeliveryCard.statusColor('OSA'),
        isDark: isDark,
      );
    }
    if (ds == DeliveryStatus.failedDelivery && index == slot) {
      return _StatusInfoBanner(
        icon: Icons.assignment_return_rounded,
        message:
            'Failed attempts can be re-delivered if still with you, unless already verified on-site.',
        statusColor: DeliveryCard.statusColor('FAILED_DELIVERY'),
        isDark: isDark,
      );
    }
    if (ds == DeliveryStatus.delivered && index == slot) {
      return _StatusInfoBanner(
        icon: Icons.check_circle_rounded,
        message: 'Delivered items are final and can\'t be reopened.',
        statusColor: DeliveryCard.statusColor('DELIVERED'),
        isDark: isDark,
      );
    }

    return const SizedBox.shrink();
  }
}

// ── Styled empty state ─────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.message,
    required this.status,
    required this.isSearching,
    required this.isDark,
  });

  final String message;
  final String status;
  final bool isSearching;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final statusColor = DeliveryCard.statusColor(status);
    final iconData = isSearching
        ? Icons.search_off_rounded
        : DeliveryCard.statusIcon(status);
    final subtextColor = isDark
        ? const Color(0xFF6B7280)
        : const Color(0xFF9CA3AF);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 400,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon circle
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: DSStyles.alphaSoft),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: statusColor.withValues(
                        alpha: DSStyles.alphaActiveAccent,
                      ),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    iconData,
                    size: 28,
                    color: statusColor.withValues(alpha: DSStyles.alphaBorder),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pull down to refresh',
                  style: TextStyle(fontSize: 11, color: subtextColor),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Status-aware info banner ───────────────────────────────────────────────────
class _StatusInfoBanner extends StatelessWidget {
  const _StatusInfoBanner({
    required this.icon,
    required this.message,
    required this.statusColor,
    required this.isDark,
  });

  final IconData icon;
  final String message;
  final Color statusColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? DSColors.cardDark
        : statusColor.withValues(alpha: DSStyles.alphaSoft);
    final border = isDark
        ? statusColor.withValues(alpha: DSStyles.alphaDarkShadow)
        : statusColor.withValues(alpha: 0.22);
    final textColor = isDark
        ? statusColor.withValues(alpha: DSStyles.alphaGlass)
        : statusColor.withValues(alpha: DSStyles.alphaGlass);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: DSStyles.cardRadius,
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: textColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: textColor,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Failed-delivery sub-filter chip ───────────────────────────────────────────
class _FailedFilterChip extends StatelessWidget {
  const _FailedFilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.count,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final int count;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? color.withValues(alpha: 0.14)
        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9));
    final border = selected
        ? color.withValues(alpha: 0.45)
        : (isDark ? Colors.white12 : const Color(0xFFE2E8F0));
    final fg = selected
        ? color
        : (isDark ? Colors.white54 : const Color(0xFF64748B));

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: DSStyles.cardRadius,
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? color.withValues(alpha: 0.18)
                        : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  const _HelpItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.isDark,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: isDark ? Colors.white70 : Colors.black87),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
