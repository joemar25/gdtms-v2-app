import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/api/api_result.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/core/settings/app_settings.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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

  /// Masks the last 4 characters of the dispatch code: DISP-XXXX-****
  String _maskDispatchCode(String code) {
    if (code.length <= 4) return '****';
    return '${code.substring(0, code.length - 4)}****';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeaderBar(
        title: 'PENDING DISPATCH',
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scan Dispatch',
            onPressed: () =>
                context.push('/scan', extra: {'mode': 'dispatch'}),
          ),
        ],
      ),
      body: _loading
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
                        final code =
                            item['dispatch_code']?.toString() ?? '';
                        final maskedCode = _maskDispatchCode(code);
                        final area =
                            item['delivery_area']?.toString() ?? '';
                        final mailpackCount =
                            item['deliveries_count'] ??
                            item['mailpack_count'] ??
                            '-';
                        final droppedDate =
                            item['dropped_date']?.toString() ??
                            item['created_at']?.toString() ??
                            '';
                        final status =
                            item['status']?.toString().toUpperCase() ??
                            'PENDING';

                        return _DispatchCard(
                          maskedCode: maskedCode,
                          area: area,
                          mailpackCount: mailpackCount.toString(),
                          droppedDate: droppedDate.isNotEmpty
                              ? formatDate(droppedDate)
                              : '-',
                          status: status,
                          onTap: () async {
                            final autoAccept = await ref
                                .read(appSettingsProvider)
                                .getAutoAcceptDispatch();
                            if (!context.mounted) return;
                            context.push('/dispatches/eligibility', extra: {
                              'dispatch_code': code,
                              'eligibility_response': {
                                ...item,
                                'eligible': true,
                              },
                              'auto_accept': autoAccept,
                            });
                          },
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
    required this.area,
    required this.mailpackCount,
    required this.droppedDate,
    required this.status,
    required this.onTap,
  });

  final String maskedCode;
  final String area;
  final String mailpackCount;
  final String droppedDate;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return GestureDetector(
      onTap: onTap,
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
              color: Colors.black.withValues(
                alpha: isDark ? 0.25 : 0.05,
              ),
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
            Row(
              children: [
                _InfoChip(
                  icon: Icons.location_on_outlined,
                  label: area.isNotEmpty ? area : 'N/A',
                ),
                const SizedBox(width: 8),
                _InfoChip(
                  icon: Icons.inventory_2_outlined,
                  label: '$mailpackCount mailpacks',
                ),
                const SizedBox(width: 8),
                _InfoChip(
                  icon: Icons.calendar_today_outlined,
                  label: droppedDate,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
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
    );
  }
}

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
