// DOCS: docs/features/dispatch.md — update that file when you edit this one.

// =============================================================================
// dispatch_list_screen.dart
// =============================================================================
//
// Purpose:
//   Displays the courier's current dispatch batch — the set of deliveries
//   assigned for today's run. The courier reviews the list, then confirms to
//   start the dispatch and seed deliveries into their local SQLite queue.
//
// Key behaviours:
//   • Fetches the dispatch list from GET /dispatch/items (requires connectivity).
//   • Each item shows barcode, recipient, address, mail type, and dispatch code.
//   • Compact / expanded card toggle respects the global compact mode setting.
//   • Confirm DISPATCH button calls POST /dispatch/confirm and triggers a full
//     delivery bootstrap, populating the local offline database.
//   • Offline guard — screen is unreachable without network; an offline banner
//     is shown and the confirm action is disabled.
//
// Navigation:
//   Route: /dispatch/list
//   Pushed from: DispatchEligibilityScreen (on eligible)
//   Pops back to: DashboardScreen after successful dispatch confirmation
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/core/settings/compact_mode_provider.dart';
import 'package:fsi_courier_app/core/settings/app_settings.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/helpers/string_helper.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/widgets/delivery_card.dart';
import 'package:fsi_courier_app/shared/widgets/empty_state.dart';
import 'package:fsi_courier_app/shared/widgets/offline_placeholder.dart';
import 'package:fsi_courier_app/core/device/device_info.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

class DispatchListScreen extends ConsumerStatefulWidget {
  const DispatchListScreen({super.key});

  @override
  ConsumerState<DispatchListScreen> createState() => _DispatchListScreenState();
}

class _DispatchListScreenState extends ConsumerState<DispatchListScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _dispatches = [];
  // Tracks which card index is checking eligibility
  int? _checkingIndex;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final isCompact = ref.read(compactModeProvider);
    final pageSize = isCompact ? kCompactDispatchesPerPage : kDispatchesPerPage;
    final result = await ref
        .read(apiClientProvider)
        .get<Map<String, dynamic>>(
          '/pending-dispatches',
          queryParameters: {'page': 1, 'per_page': pageSize},
          parser: parseApiMap,
        );

    if (!mounted) return;
    if (result case ApiSuccess<Map<String, dynamic>>(:final data)) {
      _dispatches = listOfMapsFromKey(data, 'pending_dispatches');
    }
    setState(() => _loading = false);
  }

  /// Masks the last 4 characters of the partial code
  String _maskCode(String code) {
    if (code.length <= 4) return '****';
    return '${code.substring(0, code.length - 4)}****';
  }

  Future<void> _openDispatch(int index, String dispatchCode) async {
    setState(() => _checkingIndex = index);
    try {
      const uuid = Uuid();
      final requestId = uuid.v4();
      final device = ref.read(deviceInfoProvider);
      final result = await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/check-dispatch-eligibility',
            data: {
              'dispatch_code': dispatchCode,
              'client_request_id': requestId,
              'device_info': await device.toMap(),
            },
            parser: parseApiMap,
          );
      if (!mounted) return;
      if (result case ApiSuccess<Map<String, dynamic>>(:final data)) {
        final autoAccept = await ref
            .read(appSettingsProvider)
            .getAutoAcceptDispatch();
        if (!mounted) return;
        // Merge dispatch list item (has branch, tat, transmittal_date) with
        // eligibility response (eligible, volume, item_count, etc.). Eligibility
        // fields win on overlap so eligible/status stay authoritative.
        final dispatchItem = _dispatches[index];
        final mergedData = {...dispatchItem, ...data};
        context.push(
          '/dispatches/eligibility',
          extra: {
            'dispatch_code': dispatchCode,
            'eligibility_response': mergedData,
            'auto_accept': autoAccept,
          },
        );
      } else {
        final errorMessage = switch (result) {
          ApiBadRequest(:final message) => message,
          ApiValidationError(:final message) => message ?? 'Validation error',
          ApiNetworkError(:final message) => message,
          ApiRateLimited(:final message) => message,
          ApiConflict(:final message) => message,
          ApiServerError(:final message) => message,
          _ => 'Could not check eligibility. Please try again.',
        };
        showErrorNotification(context, errorMessage);
      }
    } finally {
      if (mounted) setState(() => _checkingIndex = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(compactModeProvider, (_, _) => _load());
    final isCompact = ref.watch(compactModeProvider);
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      appBar: AppHeaderBar(
        title: 'DISPATCH',
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scan Dispatch',
            onPressed: () => context.push('/scan', extra: {'mode': 'dispatch'}),
          ),
        ],
      ),
      body: !isOnline
          ? OfflinePlaceholder(
              onRetry: _load,
              message:
                  'Viewing pending dispatches requires an internet connection.',
            )
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _dispatches.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(
                          height: 400,
                          child: EmptyState(message: 'No pending dispatches.'),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(DSSpacing.base),
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemCount: _dispatches.length,
                      itemBuilder: (_, i) {
                        final item = _dispatches[i];
                        final dispatchCode =
                            item['dispatch_code']?.toString() ?? '';
                        final maskedCode = _maskCode(dispatchCode);
                        final branch = item['branch'] is Map
                            ? item['branch'] as Map
                            : <String, dynamic>{};
                        final branchName =
                            branch['branch_name']?.toString() ?? '';
                        final volume = item['volume']?.toString() ?? '-';
                        final tat = item['tat']?.toString() ?? '';
                        final status =
                            item['status']?.toString().toDisplayStatus() ??
                            'PENDING';
                        final isChecking = _checkingIndex == i;

                        // Add TAT label to reportingDate
                        final reportingDate = tat.isNotEmpty
                            ? '${formatDate(tat)} (TAT)'
                            : '-';

                        // Map dispatch data to DeliveryCard format
                        final deliveryMap = {
                          'barcode': maskedCode,
                          'delivery_status': status,
                          'metadata': [
                            {
                              'icon': Icons.store_outlined,
                              'label': branchName.isNotEmpty
                                  ? branchName
                                  : 'N/A',
                            },
                            {
                              'icon': Icons.inventory_2_outlined,
                              'label':
                                  '$volume item${volume == '1' ? '' : 's'}',
                            },
                            {
                              'icon': Icons.event_outlined,
                              'label': reportingDate,
                            },
                          ],
                        };

                        return DeliveryCard(
                          delivery: deliveryMap,
                          compact: isCompact,
                          footerText: 'Tap to view and accept or reject',
                          isChecking: isChecking,
                          enableHoldToReveal: false,
                          showChevron: false,
                          showLockIcon: false,
                          onTap: isChecking
                              ? null
                              : () => _openDispatch(i, dispatchCode),
                        );
                      },
                    ),
            ),
    );
  }
}
