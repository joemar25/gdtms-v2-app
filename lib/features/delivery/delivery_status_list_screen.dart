// DOCS: docs/development-standards.md
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
import 'package:fsi_courier_app/shared/widgets/ds_segmented_selector.dart';
import 'package:fsi_courier_app/features/delivery/delivery_status_list_components.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

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
  // ─── MARK: State ───────────────────────────────────────────────────────────

  // ── Page state ─────────────────────────────────────────────────────────────
  bool _loading = true;
  int _currentPage = 0;
  int _totalCount = 0;
  List<Map<String, dynamic>> _items = [];

  int get _kPageSize => ref.read(compactModeProvider)
      ? kCompactDeliveriesPerPage
      : kDeliveriesPerPage;

  bool get _isFailedDelivery =>
      widget.status.toUpperCase() == 'FAILED_DELIVERY';

  int get _effectiveTotal => _isFailedDelivery
      ? (_failedSubFilter == 'rts' ? _totalRtsCount : _totalRedeliveryCount)
      : _totalCount;

  int get _totalPages => (_effectiveTotal / _kPageSize).ceil().clamp(1, 999999);

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
  /// 'redelivery' = attempts < 3 and not Failed Delivery-verified
  /// 'rts'        = attempts >= 3 or Failed Delivery-verified
  String _failedSubFilter = 'redelivery';

  /// Total counts across ALL pages — not just the current page.
  /// Populated in [_load] so the chip badges are always accurate.
  int _totalRedeliveryCount = 0;
  int _totalRtsCount = 0;

  List<Map<String, dynamic>> get _displayed =>
      _searchQuery.trim().isNotEmpty ? _searchResults : _items;

  /// Full (unsliced) list for the active FAILED_DELIVERY sub-group.
  List<Map<String, dynamic>> get _failedFiltered {
    final base = _displayed;
    if (!_isFailedDelivery) return base;
    return base.where((d) {
      final attempts = getAttemptsCountFromMap(d);
      final vStr = (d['_rts_verification_status'] ?? 'unvalidated')
          .toString()
          .toLowerCase();
      final rv = FailedDeliveryVerificationStatus.fromString(vStr);
      final isRts = attempts >= 3 || rv.isVerified;
      return _failedSubFilter == 'rts' ? isRts : !isRts;
    }).toList();
  }

  /// Paginated slice of [_failedFiltered] for the current page.
  /// For non-FAILED_DELIVERY screens this is identical to [_failedFiltered].
  List<Map<String, dynamic>> get _pageSlice {
    final full = _failedFiltered;
    if (!_isFailedDelivery) return full;
    final start = _currentPage * _kPageSize;
    if (start >= full.length) return [];
    final end = (start + _kPageSize).clamp(0, full.length);
    return full.sublist(start, end);
  }

  /// Returns the accurate total count for each sub-group across all pages.
  int _countFailedSubGroup(String group) {
    if (!_isFailedDelivery) return 0;
    return group == 'rts' ? _totalRtsCount : _totalRedeliveryCount;
  }

  // ─── MARK: Lifecycle ───────────────────────────────────────────────────────

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

  // ─── MARK: Data Loading ───────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() => _loading = true);
    final status = widget.status.toUpperCase();

    // 1. Get total count
    final total = switch (status) {
      'DELIVERED' => await LocalDeliveryDao.instance.countVisibleDelivered(),
      'FAILED_DELIVERY' =>
        await LocalDeliveryDao.instance.countVisibleFailedDelivery(),
      'OSA' => await LocalDeliveryDao.instance.countVisibleOsa(),
      _ => await LocalDeliveryDao.instance.countByStatus(widget.status),
    };

    // 2. Classify for FAILED_DELIVERY or fetch page for others
    int redeliveryCount = 0;
    int rtsCount = 0;
    List<LocalDelivery>? allFailedRows;
    List<LocalDelivery> rows = [];

    if (_isFailedDelivery && total > 0) {
      // Pagination is incompatible with client-side sub-filtering (redelivery vs
      // RTS) because items from both groups are interleaved in the DB — a single
      // page may contain zero items of the selected group. Loading all rows
      // upfront (typical count: low tens) is fine for this screen.
      allFailedRows = await LocalDeliveryDao.instance
          .getVisibleFailedDeliveryPaged(limit: total, offset: 0);
      for (final row in allFailedRows) {
        final attempts = getAttemptsCountFromMap(row.toDeliveryMap());
        final vStr = (row.rtsVerificationStatus).toLowerCase();
        final rv = FailedDeliveryVerificationStatus.fromString(vStr);
        final isRts = attempts >= 3 || rv.isVerified;
        if (isRts) {
          rtsCount++;
        } else {
          redeliveryCount++;
        }
      }
    } else if (!_isFailedDelivery) {
      rows = await _fetchPage(offset: _currentPage * _kPageSize);
    }

    if (!mounted) return;

    // 3. Determine effective total and check bounds
    final effectiveTotal = _isFailedDelivery
        ? (_failedSubFilter == 'rts' ? rtsCount : redeliveryCount)
        : total;

    final totalPages = (effectiveTotal / _kPageSize).ceil().clamp(1, 999999);
    if (_currentPage > 0 && _currentPage >= totalPages) {
      _currentPage = totalPages - 1;
      // If we are NOT in FAILED_DELIVERY mode, we need to re-fetch the correct page.
      // For FAILED_DELIVERY, allFailedRows already contains everything, so we
      // just continue.
      if (!_isFailedDelivery) {
        return _load();
      }
    }

    // 4. Sync-lock check
    final courierId = ref.read(authProvider).courier?['id']?.toString() ?? '';
    _queuedBarcodes = await SyncOperationsDao.instance.getSyncQueuedBarcodes(
      courierId,
    );
    if (!mounted) return;

    setState(() {
      _items = (allFailedRows ?? rows).map(_toCardMap).toList();
      _totalCount = total;
      _totalRedeliveryCount = redeliveryCount;
      _totalRtsCount = rtsCount;
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

  // ─── MARK: Handlers ────────────────────────────────────────────────────────

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

  // ─── MARK: Search Logic ────────────────────────────────────────────────────

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
    final secureBadge = const Padding(
      padding: EdgeInsets.only(right: DSSpacing.sm),
      child: Center(child: SecureBadge()),
    );

    return switch (status) {
      'FOR_DELIVERY' => [
        secureBadge,
        searchBtn,
        IconButton(
          icon: const Icon(Icons.qr_code_scanner_rounded),
          tooltip: 'Scan POD',
          onPressed: () => context.push('/scan', extra: {'mode': 'pod'}),
        ),
      ],
      'FAILED_DELIVERY' => [
        secureBadge,
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
      _ => [secureBadge, searchBtn],
    };
  }

  String _emptyMessage() => switch (widget.status.toUpperCase()) {
    'FOR_DELIVERY' => 'No active deliveries.',
    'DELIVERED' => 'No delivered items today.',
    'DISPATCHED' => 'No dispatched items.',
    'FAILED_DELIVERY' =>
      _failedSubFilter == 'rts'
          ? 'No items for return today.'
          : 'No items available for redelivery.',
    'OSA' => 'No OSA mailpacks today.',
    _ => 'No items found.',
  };

  // ─── MARK: UI Building ─────────────────────────────────────────────────────

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
    final displayed = _pageSlice;
    final effectiveTotal = _effectiveTotal;
    final effectiveFirstItem = effectiveTotal == 0
        ? 0
        : _currentPage * _kPageSize + 1;
    final effectiveLastItem = (effectiveFirstItem + displayed.length - 1).clamp(
      0,
      effectiveTotal,
    );
    final isSearching = _searchQuery.trim().isNotEmpty;
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
        body: SecureView(
          child: GestureDetector(
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
                                ? (_searchLoading
                                      ? null
                                      : _searchResults.length)
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
                if (_isFailedDelivery)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      DSSpacing.md,
                      DSSpacing.sm,
                      DSSpacing.md,
                      0,
                    ),
                    child: DSSegmentedSelector<String>(
                      selected: _failedSubFilter,
                      onChanged: (v) => setState(() {
                        _failedSubFilter = v;
                        _currentPage = 0;
                      }),
                      options: [
                        DSSegmentOption(
                          value: 'redelivery',
                          label: 'For Redelivery',
                          icon: Icons.local_shipping_rounded,
                          color: DSColors.error,
                          badge: _countFailedSubGroup('redelivery'),
                        ),
                        DSSegmentOption(
                          value: 'rts',
                          label: 'For Return',
                          icon: Icons.assignment_return_rounded,
                          color: DeliveryCard.statusColor('FAILED_DELIVERY'),
                          badge: _countFailedSubGroup('rts'),
                        ),
                      ],
                    ),
                  ),

                // ── List ───────────────────────────────────────────────────────────
                Expanded(
                  child: RefreshIndicator(
                    color: DSColors.error,
                    onRefresh: _onRefresh,
                    child: _loading
                        ? const Center(child: DSLoading(color: DSColors.error))
                        : (_searchLoading && displayed.isEmpty)
                        ? const Center(child: DSLoading(color: DSColors.error))
                        : displayed.isEmpty
                        ? DeliveryListEmptyState(
                            message: isSearching
                                ? 'No results for "$_searchQuery".'
                                : _emptyMessage(),
                            status: widget.status,
                            isSearching: isSearching,
                            isDark: isDark,
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              DSSpacing.md,
                              DSSpacing.sm,
                              DSSpacing.md,
                              DSSpacing.sm,
                            ),
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
                                  d['delivery_status']?.toString() ??
                                  'FOR_DELIVERY';
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
                                        '/deliveries/$identifier/update',
                                      ),
                              );
                            },
                          ),
                  ),
                ),

                // ── Pagination bar ─────────────────────────────────────────────────
                if (!isSearching && !_loading && effectiveTotal > _kPageSize)
                  PaginationBar(
                    currentPage: _currentPage,
                    totalPages: _totalPages,
                    firstItem: effectiveFirstItem,
                    lastItem: effectiveLastItem,
                    totalCount: effectiveTotal,
                    onPageChanged: _goToPage,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFailedDeliveryHelpBottomSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: DSColors.transparent,
      isScrollControlled: true,
      builder: (_) => const FailedDeliveryHelpSheet(),
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
          padding: EdgeInsets.only(bottom: DSSpacing.sm),
          child: OfflineBanner(isMinimal: true),
        );
      }
      slot++;
    }

    if (ds == DeliveryStatus.osa && index == slot) {
      return DeliveryStatusInfoBanner(
        icon: Icons.inventory_2_rounded,
        message: 'OSA items can\'t be opened. Return to FSI for verification.',
        statusColor: DeliveryCard.statusColor('OSA'),
        isDark: isDark,
      );
    }
    if (ds == DeliveryStatus.delivered && index == slot) {
      return DeliveryStatusInfoBanner(
        icon: Icons.check_circle_rounded,
        message: 'Delivered items are final and can\'t be reopened.',
        statusColor: DeliveryCard.statusColor('DELIVERED'),
        isDark: isDark,
      );
    }

    return const SizedBox.shrink();
  }
}
