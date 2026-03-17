import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/models/local_delivery.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/core/settings/compact_mode_provider.dart';
import 'package:fsi_courier_app/core/sync/delivery_bootstrap_service.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_identifier.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/widgets/delivery_card.dart';
import 'package:fsi_courier_app/shared/widgets/pagination_bar.dart';
import 'package:fsi_courier_app/shared/widgets/search_bar.dart';
import 'package:fsi_courier_app/shared/widgets/status_notice_banner.dart';
import 'package:fsi_courier_app/shared/widgets/offline_banner.dart';

const int _kPageSize = 10;

/// A single list screen reused for every delivery status filter
/// (pending, delivered, rts, osa).
///
/// Data is always read from local SQLite — the app is offline-first.
/// The list refreshes whenever [deliveryRefreshProvider] increments (on
/// dispatch acceptance or after a successful sync).
class DeliveryStatusListScreen extends ConsumerStatefulWidget {
  const DeliveryStatusListScreen({
    super.key,
    required this.status,
    required this.title,
  });

  final String status;
  final String title;

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

  List<Map<String, dynamic>> get _displayed =>
      _searchQuery.trim().isNotEmpty ? _searchResults : _items;

  @override
  void initState() {
    super.initState();
    _load();
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
      'RTS' => await LocalDeliveryDao.instance.countVisibleRts(),
      'OSA' => await LocalDeliveryDao.instance.countVisibleOsa(),
      _ => await LocalDeliveryDao.instance.countByStatus(widget.status),
    };
    if (!mounted) return;
    // If page is out of range (e.g. after a refresh), clamp to last page.
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
    // Scroll back to top on every page change.
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
      'RTS' => LocalDeliveryDao.instance.getVisibleRtsPaged(
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
    // Always stamp from the model field — raw JSON may lag behind local updates.
    base['_rts_verification_status'] = row.rtsVerificationStatus;
    base['_sync_status'] = row.syncStatus;
    return base;
  }

  List<Widget> _buildActions(BuildContext context) {
    final searchBtn = IconButton(
      icon: Icon(_showSearch ? Icons.search_off_rounded : Icons.search_rounded),
      tooltip: 'Search',
      onPressed: () {
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
      'RTS' => [
        searchBtn,
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
    'DELIVERED' => "No delivered items today.",
    'RTS' => "No RTS mailpacks today.",
    'OSA' => "No OSA mailpacks today.",
    _ => 'No items found.',
  };

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(deliveryRefreshProvider, (_, __) {
      _currentPage = 0;
      _load();
    });

    final isCompact = ref.watch(compactModeProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final displayed = _displayed;
    final isSearching = _searchQuery.trim().isNotEmpty;

    return Scaffold(
      appBar: AppHeaderBar(
        title: widget.title,
        actions: _buildActions(context),
      ),
      body: Column(
        children: [
          // ── Search bar ─────────────────────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: _showSearch
                ? AppSearchBar(
                    controller: _searchController,
                    query: _searchQuery,
                    hintText: 'BARCODE OR NAME',
                    isLoading: _searchLoading,
                    resultCount: isSearching
                        ? (_searchLoading ? null : _searchResults.length)
                        : null,
                    totalCount:
                        (!isSearching && _searchQuery.isEmpty) ? _totalCount : null,
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
                : const SizedBox.shrink(),
          ),

          // ── List ───────────────────────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : (_searchLoading && displayed.isEmpty)
                  ? const Center(child: CircularProgressIndicator())
                  : displayed.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        if (!isOnline) const OfflineBanner(isMinimal: true),
                        SizedBox(
                          height: 400,
                          child: Center(
                            child: Text(
                              isSearching
                                  ? 'No results for "$_searchQuery".'
                                  : _emptyMessage(),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      itemCount: displayed.length + _bannerCount(isOnline),
                      itemBuilder: (context, index) {
                        final banners = _bannerCount(isOnline);
                        if (index < banners) {
                          return _buildBanner(index, isOnline);
                        }
                        final d = displayed[index - banners];
                        final identifier = resolveDeliveryIdentifier(d);
                        final status = widget.status.toUpperCase();
                        final isOsa = status == 'OSA';
                        final rtsVerifStatus =
                            (d['_rts_verification_status']?.toString() ??
                            d['rts_verification_status']?.toString() ??
                            'unvalidated').toLowerCase();
                        final isValidatedRts = status == 'RTS' &&
                            (rtsVerifStatus == 'verified_with_pay' ||
                                rtsVerifStatus == 'verified_no_pay');
                        final isLocked = isOsa || isValidatedRts;
                        return DeliveryCard(
                          delivery: d,
                          compact: isCompact,
                          showChevron: !isLocked,
                          onTap: (isLocked || identifier.isEmpty)
                              ? () {}
                              : () => context.push('/deliveries/$identifier'),
                        );
                      },
                    ),
            ),
          ),

          // ── Pagination bar (hidden in search mode) ─────────────────────────
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
    );
  }

  int _bannerCount(bool isOnline) {
    final status = widget.status.toUpperCase();
    int count = 0;
    if (!isOnline) count++;
    if (status == 'OSA') count++;
    if (status == 'RTS') count++;
    if (status == 'DELIVERED') count++;
    return count;
  }

  Widget _buildBanner(int index, bool isOnline) {
    final status = widget.status.toUpperCase();
    final widgets = <Widget>[
      if (!isOnline) const OfflineBanner(isMinimal: true),
      if (status == 'OSA')
        const StatusNoticeBanner(type: StatusNoticeType.osa),
      if (status == 'RTS')
        const StatusNoticeBanner(type: StatusNoticeType.rts),
      if (status == 'DELIVERED')
        const StatusNoticeBanner(type: StatusNoticeType.deliveredToday),
    ];
    return widgets[index];
  }
}

