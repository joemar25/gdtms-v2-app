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
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  bool _showSearch = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> get _filtered {
    // Normalize search input: always uppercase
    final q = _searchQuery.trim().toUpperCase();
    if (q.isEmpty) return _items;
    return _items.where((d) {
      final barcode =
          (d['barcode_value'] ?? d['barcode'] ?? '').toString().toUpperCase();
      final name =
          (d['name'] ?? d['recipient_name'] ?? '').toString().toUpperCase();
      return barcode.contains(q) || name.contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = widget.status == 'delivered'
        ? await LocalDeliveryDao.instance.getVisibleDelivered()
        : await LocalDeliveryDao.instance.getByStatus(widget.status);
    if (!mounted) return;
    setState(() {
      _items = rows.map(_toCardMap).toList();
      _loading = false;
    });
  }

  /// Pull-to-refresh: re-seeds SQLite from the API (if online) then reloads.
  Future<void> _onRefresh() async {
    final isOnline = ref.read(isOnlineProvider);
    if (isOnline) {
      await DeliveryBootstrapService.instance.syncFromApi(
        ref.read(apiClientProvider),
      );
    }
    await _load();
  }

  /// Merges the indexed fields with the raw JSON blob so that [DeliveryCard]
  /// and detail screens get a complete delivery map regardless of which API
  /// fields were present in the eligibility response.
  Map<String, dynamic> _toCardMap(LocalDelivery row) {
    final base = row.toDeliveryMap();
    // Ensure the primary barcode key is always present for routing.
    if (!base.containsKey('barcode_value') || base['barcode_value'] == null) {
      base['barcode_value'] = row.barcode;
    }
    // Pass payout timestamp so DeliveryCard can show a PAID badge.
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
            _searchController.clear();
          }
        });
      },
    );
    // RULE: If status is 'osa', do not ever show update status button here.
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
    // Reload whenever a dispatch is accepted or a sync completes.
    ref.listen<int>(deliveryRefreshProvider, (_, __) => _load());

    final isCompact = ref.watch(compactModeProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final filtered = _filtered;

    return Scaffold(
      appBar: AppHeaderBar(
        title: widget.title,
        actions: _buildActions(context),
      ),
      body: Column(
        children: [
          if (_showSearch) _SearchBar(
            controller: _searchController,
            query: _searchQuery,
            resultCount: _searchQuery.isNotEmpty ? _filtered.length : null,
            onChanged: (v) => setState(() => _searchQuery = v),
            onClear: () => setState(() {
              _searchQuery = '';
              _searchController.clear();
            }),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                  ? ListView(
                      children: [
                        if (!isOnline) const OfflineBanner(isMinimal: true),
                        SizedBox(
                          height: 400,
                          child: EmptyState(
                            message: _searchQuery.isNotEmpty
                                ? 'No results for "$_searchQuery".'
                                : _emptyMessage(),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        if (!isOnline) ...[
                          const OfflineBanner(isMinimal: true),
                          const SizedBox(height: 4),
                        ],
                        if (widget.status == 'osa') ...[
                          const _OsaNoticeBanner(),
                          const SizedBox(height: 12),
                        ],
                        if (widget.status == 'delivered') ...[
                          const _DeliveredTodayNoticeBanner(),
                          const SizedBox(height: 12),
                        ],
                        ...filtered.map((d) {
                          final identifier = resolveDeliveryIdentifier(d);
                          // RULE: If status is 'osa', navigation is disabled.
                          final isOsa = widget.status == 'osa';
                          return DeliveryCard(
                            delivery: d,
                            compact: isCompact,
                            showChevron: !isOsa,
                            onTap: (isOsa || identifier.isEmpty)
                                ? () {}
                                : () => context.push('/deliveries/$identifier'),
                          );
                        }),
                      ],
                    ),
            ),
          ),
        ],
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

// ─── Modern search bar ────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
    this.resultCount,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final int? resultCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
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
          if (resultCount != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 12),
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
          ],
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
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Colors.amber.shade800,
          ),
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
      margin: const EdgeInsets.only(top: 16),
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
