import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/api/api_result.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/core/settings/app_settings.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/helpers/string_helper.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/widgets/dispatch_card.dart';
import 'package:fsi_courier_app/shared/widgets/empty_state.dart';
import 'package:fsi_courier_app/shared/widgets/offline_placeholder.dart';

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
    final result = await ref
        .read(apiClientProvider)
        .get<Map<String, dynamic>>(
          '/pending-dispatches',
          queryParameters: {'page': 1, 'per_page': kDispatchesPerPage},
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

  Future<void> _openDispatch(int index, String partialCode) async {
    setState(() => _checkingIndex = index);
    try {
      const uuid = Uuid();
      final requestId = uuid.v4();
      final result = await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/check-dispatch-eligibility',
            data: {'partial_code': partialCode, 'client_request_id': requestId},
            parser: parseApiMap,
          );
      if (!mounted) return;
      if (result case ApiSuccess<Map<String, dynamic>>(:final data)) {
        final autoAccept = await ref
            .read(appSettingsProvider)
            .getAutoAcceptDispatch();
        if (!mounted) return;
        context.push(
          '/dispatches/eligibility',
          extra: {
            'dispatch_code': data['partial_code']?.toString() ?? partialCode,
            'eligibility_response': data,
            'auto_accept': autoAccept,
          },
        );
      } else {
        showAppSnackbar(
          context,
          'Could not check eligibility. Please try again.',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _checkingIndex = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      appBar: AppHeaderBar(
        title: 'PENDING DISPATCH',
        pageIcon: Icons.list_alt_rounded,
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
              message: 'Viewing pending dispatches requires an internet connection.',
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
                      padding: const EdgeInsets.all(16),
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemCount: _dispatches.length,
                      itemBuilder: (_, i) {
                        final item = _dispatches[i];
                        final partialCode =
                            item['partial_code']?.toString() ?? '';
                        final maskedCode = _maskCode(partialCode);
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

                        return DispatchCard(
                          maskedCode: maskedCode,
                          branchName: branchName.isNotEmpty
                            ? branchName
                            : 'N/A',
                          volume: volume,
                          reportingDate: reportingDate,
                          status: status,
                          isChecking: isChecking,
                          onTap: isChecking
                            ? null
                            : () => _openDispatch(i, partialCode),
                        );
                      },
                    ),
            ),
    );
  }
}

