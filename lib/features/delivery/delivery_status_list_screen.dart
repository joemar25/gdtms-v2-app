import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInputFormatter, TextEditingValue;
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
import 'package:fsi_courier_app/shared/widgets/empty_state.dart';
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
    final total = widget.status == 'delivered'
        ? await LocalDeliveryDao.instance.countVisibleDelivered()
        : await LocalDeliveryDao.instance.countByStatus(widget.status);
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
    if (widget.status == 'delivered') {
      return LocalDeliveryDao.instance.getVisibleDeliveredPaged(
        limit: _kPageSize,
        offset: offset,
      );
    }
    return LocalDeliveryDao.instance.getByStatusPaged(
      widget.status,
      limit: _kPageSize,
      offset: offset,
    );
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
    return switch (widget.status) {
      'pending' => [
        searchBtn,
        IconButton(
          icon: const Icon(Icons.qr_code_scanner_rounded),
          tooltip: 'Scan POD',
          onPressed: () => context.push('/scan', extra: {'mode': 'pod'}),
        ),
      ],
      'rts' => [
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

  String _emptyMessage() => switch (widget.status) {
    'pending' => 'No active deliveries.',
    'delivered' => 'No delivered items today.',
    'rts' => 'No RTS mailpacks.',
    'osa' => 'No OSA mailpacks.',
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
                ? _SearchBar(
                    controller: _searchController,
                    query: _searchQuery,
                    resultCount: isSearching
                        ? (_searchLoading ? null : _searchResults.length)
                        : null,
                    totalCount: !isSearching ? _totalCount : null,
                    isLoading: _searchLoading,
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
                          child: EmptyState(
                            message: isSearching
                                ? 'No results for "$_searchQuery".'
                                : _emptyMessage(),
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
                        final isOsa = widget.status == 'osa';
                        return DeliveryCard(
                          delivery: d,
                          compact: isCompact,
                          showChevron: !isOsa,
                          onTap: (isOsa || identifier.isEmpty)
                              ? () {}
                              : () => context.push('/deliveries/$identifier'),
                        );
                      },
                    ),
            ),
          ),

          // ── Pagination bar (hidden in search mode) ─────────────────────────
          if (!isSearching && !_loading && _totalCount > 0)
            _PaginationBar(
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
    int count = 0;
    if (!isOnline) count++;
    if (widget.status == 'osa') count++;
    if (widget.status == 'delivered') count++;
    return count;
  }

  Widget _buildBanner(int index, bool isOnline) {
    final widgets = <Widget>[
      if (!isOnline) const OfflineBanner(isMinimal: true),
      if (widget.status == 'osa') const _OsaNoticeBanner(),
      if (widget.status == 'delivered') const _DeliveredTodayNoticeBanner(),
    ];
    return widgets[index];
  }
}

// ─── Pagination bar ───────────────────────────────────────────────────────────

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.firstItem,
    required this.lastItem,
    required this.totalCount,
    required this.onPageChanged,
  });

  final int currentPage;
  final int totalPages;
  final int firstItem;
  final int lastItem;
  final int totalCount;
  final ValueChanged<int> onPageChanged;

  /// Returns up to 5 page numbers centred around [currentPage].
  List<int> get _pageNumbers {
    if (totalPages <= 7) return List.generate(totalPages, (i) => i);
    final start = (currentPage - 2).clamp(0, totalPages - 5);
    return List.generate(5, (i) => start + i);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : cs.surface,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Range label ─────────────────────────────────────────────────
          Text(
            '$firstItem–$lastItem of $totalCount',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          // ── Page controls ───────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // First page
              _NavButton(
                icon: Icons.first_page_rounded,
                enabled: currentPage > 0,
                onTap: () => onPageChanged(0),
              ),
              // Previous
              _NavButton(
                icon: Icons.chevron_left_rounded,
                enabled: currentPage > 0,
                onTap: () => onPageChanged(currentPage - 1),
              ),
              const SizedBox(width: 4),
              // Page number chips
              ..._pageNumbers.map(
                (page) => _PageChip(
                  page: page,
                  isSelected: page == currentPage,
                  onTap: () => onPageChanged(page),
                ),
              ),
              const SizedBox(width: 4),
              // Next
              _NavButton(
                icon: Icons.chevron_right_rounded,
                enabled: currentPage < totalPages - 1,
                onTap: () => onPageChanged(currentPage + 1),
              ),
              // Last page
              _NavButton(
                icon: Icons.last_page_rounded,
                enabled: currentPage < totalPages - 1,
                onTap: () => onPageChanged(totalPages - 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 22,
          color: enabled
              ? cs.onSurface
              : cs.onSurface.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}

class _PageChip extends StatelessWidget {
  const _PageChip({
    required this.page,
    required this.isSelected,
    required this.onTap,
  });

  final int page;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: isSelected ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: isSelected ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? null
              : Border.all(color: cs.outline.withValues(alpha: 0.3)),
        ),
        alignment: Alignment.center,
        child: Text(
          '${page + 1}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? cs.onPrimary : cs.onSurface,
          ),
        ),
      ),
    );
  }
}

// ─── Uppercase formatter ──────────────────────────────────────────────────────

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

// ─── Search bar ───────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
    this.resultCount,
    this.totalCount,
    this.isLoading = false,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final int? resultCount;
  final int? totalCount;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : cs.surface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF2A2A3E)
                  : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [_UpperCaseFormatter()],
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
              decoration: InputDecoration(
                hintText: 'BARCODE OR NAME',
                hintStyle: TextStyle(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  letterSpacing: 0.4,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: cs.primary,
                  size: 22,
                ),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: cs.onSurfaceVariant,
                        onPressed: onClear,
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 4,
                ),
              ),
              onChanged: onChanged,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 4),
              if (isLoading) ...[
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'SEARCHING…',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                    letterSpacing: 0.8,
                  ),
                ),
              ] else if (resultCount != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$resultCount RESULT${resultCount == 1 ? '' : 'S'}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ] else if (totalCount != null) ...[
                Text(
                  '$totalCount ITEM${totalCount == 1 ? '' : 'S'} TOTAL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─── OSA read-only notice ─────────────────────────────────────────────────────

class _OsaNoticeBanner extends StatelessWidget {
  const _OsaNoticeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: Colors.amber.shade800),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'PENDING ADMIN REVIEW — NO ACTION REQUIRED',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.amber.shade900,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Delivered today notice ───────────────────────────────────────────────────

class _DeliveredTodayNoticeBanner extends StatelessWidget {
  const _DeliveredTodayNoticeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade300, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 18,
            color: Colors.green.shade800,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Showing your delivered items',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.green.shade900,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
