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
import 'package:fsi_courier_app/shared/widgets/empty_state.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await LocalDeliveryDao.instance.getByStatus(widget.status);
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
      await DeliveryBootstrapService.instance
          .syncFromApi(ref.read(apiClientProvider));
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
    return base;
  }

  List<Widget> _buildActions(BuildContext context) {
    // RULE: If status is 'osa', do not ever show update status button here.
    return switch (widget.status) {
      'pending' => [
        IconButton(
          icon: const Icon(Icons.qr_code_scanner_rounded),
          tooltip: 'Scan POD',
          onPressed: () => context.push('/scan', extra: {'mode': 'pod'}),
        ),
      ],
      'rts' => [
        IconButton(
          icon: const Icon(Icons.qr_code_scanner_rounded),
          tooltip: 'Scan Dispatch',
          onPressed: () => context.push('/scan', extra: {'mode': 'dispatch'}),
        ),
      ],
      _ => [],
    };
  }

  String _emptyMessage() => switch (widget.status) {
    'pending' => 'No active deliveries.',
    'delivered' => 'No delivered items.',
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

    return Scaffold(
      appBar: AppHeaderBar(
        title: widget.title,
        actions: _buildActions(context),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
            ? ListView(
                children: [
                  if (!isOnline) const _LocalDataBanner(),
                  SizedBox(
                    height: 400,
                    child: EmptyState(message: _emptyMessage()),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  if (!isOnline) ...[const _LocalDataBanner(), const SizedBox(height: 4)],
                  if (widget.status == 'osa') ...[
                    const _OsaNoticeBanner(),
                    const SizedBox(height: 12),
                  ],
                  ..._items.map((d) {
                    final identifier = resolveDeliveryIdentifier(d);
                    // RULE: If status is 'osa', navigation is disabled.
                    return DeliveryCard(
                      delivery: d,
                      compact: isCompact,
                      onTap: (widget.status == 'osa' || identifier.isEmpty)
                          ? () {}
                          : () => context.push('/deliveries/$identifier'),
                    );
                  }),
                ],
              ),
      ),
    );
  }
}
// ─── Offline local-data notice ─────────────────────────────────────────────

class _LocalDataBanner extends StatelessWidget {
  const _LocalDataBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 12, 0, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200, width: 1.2),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, size: 15, color: Colors.orange.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Showing locally saved data',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade800,
              ),
            ),
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
