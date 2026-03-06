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
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/widgets/empty_state.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';

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
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scan Dispatch',
            onPressed: () => context.push('/scan', extra: {'mode': 'dispatch'}),
          ),
        ],
      ),
      body: !isOnline
          ? _OfflinePlaceholder(onRetry: _load)
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
                          item['status']?.toString().toUpperCase() ??
                          'PENDING';
                        final isChecking = _checkingIndex == i;

                        // Add TAT label to reportingDate
                        final reportingDate = tat.isNotEmpty
                          ? '${formatDate(tat)} (TAT)'
                          : '-';

                        return _DispatchCard(
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

// ─── Dispatch Card ────────────────────────────────────────────────────────────

class _DispatchCard extends StatelessWidget {
  const _DispatchCard({
    required this.maskedCode,
    required this.branchName,
    required this.volume,
    required this.reportingDate,
    required this.status,
    required this.isChecking,
    this.onTap,
  });

  final String maskedCode;
  final String branchName;
  final String volume;
  final String reportingDate;
  final String status;
  final bool isChecking;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: isChecking ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border(
              left: BorderSide(color: ColorStyles.grabOrange, width: 4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      maskedCode,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: ColorStyles.grabOrange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: ColorStyles.grabOrange,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  _InfoChip(icon: Icons.store_outlined, label: branchName),
                  _InfoChip(
                    icon: Icons.inventory_2_outlined,
                    label: '$volume item${volume == '1' ? '' : 's'}',
                  ),
                  _InfoChip(icon: Icons.event_outlined, label: reportingDate),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (isChecking) ...[
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                          ColorStyles.grabOrange,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Checking eligibility\u2026',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ] else ...[
                    const Icon(
                      Icons.info_outline,
                      size: 13,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Tap to view and accept or reject',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey.shade400,
                    size: 20,
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
class _OfflinePlaceholder extends StatelessWidget {
  const _OfflinePlaceholder({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No Internet Connection',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Viewing pending dispatches\nrequires an internet connection.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Info chip ────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey.shade500),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
