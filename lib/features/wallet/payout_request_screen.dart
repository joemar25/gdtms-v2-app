import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/api/api_result.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';

class PayoutRequestScreen extends ConsumerStatefulWidget {
  const PayoutRequestScreen({super.key});

  @override
  ConsumerState<PayoutRequestScreen> createState() =>
      _PayoutRequestScreenState();
}

class _PayoutRequestScreenState extends ConsumerState<PayoutRequestScreen> {
  /// Today is always the cap — cannot go beyond today.
  final DateTime _today = DateTime.now();

  /// The selected "to date" — defaults to today.
  late DateTime _selectedDay;

  bool _submitting = false;
  bool _loadingRate = true;
  double? _ratePerDelivery;
  String? _error;

  /// Derived: from = selectedDay - 6 (7-day window)
  DateTime get _fromDate =>
      _selectedDay.subtract(const Duration(days: 6));

  /// The last 7 days in ascending order (oldest → today).
  List<DateTime> get _rollingWeek => List.generate(
        7,
        (i) => DateTime(
          _today.year,
          _today.month,
          _today.day - (6 - i),
        ),
      );

  @override
  void initState() {
    super.initState();
    _selectedDay = _today;
    _fetchRate();
  }

  Future<void> _fetchRate() async {
    final result = await ref
        .read(apiClientProvider)
        .get<Map<String, dynamic>>('/wallet-summary', parser: parseApiMap);

    if (!mounted) return;

    if (result case ApiSuccess<Map<String, dynamic>>(:final data)) {
      final summary = mapFromKey(data, 'data');
      final rawRate = summary['rate_per_delivery'] ??
          summary['rate'] ??
          summary['delivery_rate'];
      if (rawRate != null) {
        _ratePerDelivery = double.tryParse('$rawRate');
      }
    }

    setState(() => _loadingRate = false);
  }

  String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  String _fmtLabel(DateTime d) => DateFormat('MMM d').format(d);

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await ref
        .read(apiClientProvider)
        .post<Map<String, dynamic>>(
          '/payment-request',
          data: {
            'from_date': _fmt(_fromDate),
            'to_date': _fmt(_selectedDay),
          },
          parser: parseApiMap,
        );

    if (!mounted) return;

    if (result is ApiSuccess<Map<String, dynamic>>) {
      showAppSnackbar(
        context,
        'Payout request submitted.',
        type: SnackbarType.success,
      );
      context.go('/wallet');
    } else if (result is ApiValidationError<Map<String, dynamic>>) {
      final firstError = result.errors.values.isNotEmpty
          ? result.errors.values.first.first
          : null;
      setState(
          () => _error = firstError ?? result.message ?? 'Invalid input.');
    } else {
      showAppSnackbar(
        context,
        'Failed to submit payout request.',
        type: SnackbarType.error,
      );
    }

    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);
    final week = _rollingWeek;

    if (!isOnline) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'REQUEST PAYOUT',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded,
                  size: 52, color: Colors.orange.shade400),
              const SizedBox(height: 16),
              const Text(
                'You\'re Offline',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Payout requests require an internet\nconnection. Please reconnect and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'REQUEST PAYOUT',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            icon: const Icon(Icons.send_rounded),
            label: const Text(
              'SUBMIT REQUEST',
              style:
                  TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.8),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: ColorStyles.grabGreen,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _submitting ? null : _submit,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Rate per delivery (only shown here per spec) ─────────────
          _RateCard(
            loading: _loadingRate,
            rate: _ratePerDelivery,
          ),
          const SizedBox(height: 20),

          // ── 7-day calendar strip ──────────────────────────────────────
          _sectionHeader('SELECT COVERAGE END DATE'),
          const SizedBox(height: 8),
          _CalendarStrip(
            days: week,
            selectedDay: _selectedDay,
            onDaySelected: (d) => setState(() => _selectedDay = d),
          ),
          const SizedBox(height: 16),

          // ── Active date range label ────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: ColorStyles.grabGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ColorStyles.grabGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.date_range_rounded,
                    size: 18, color: ColorStyles.grabGreen),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'COVERAGE PERIOD',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: ColorStyles.grabGreen,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_fmtLabel(_fromDate)}  –  ${_fmtLabel(_selectedDay)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ColorStyles.grabGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '7 DAYS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: ColorStyles.grabGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                _error!,
                style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label) => Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: Colors.grey.shade600,
        ),
      );
}

// ─── Rate Card ────────────────────────────────────────────────────────────────

class _RateCard extends StatelessWidget {
  const _RateCard({required this.loading, required this.rate});
  final bool loading;
  final double? rate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ColorStyles.grabGreen.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.payments_rounded,
                color: ColorStyles.grabGreen, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RATE PER DELIVERY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 4),
                loading
                    ? const SizedBox(
                        height: 18,
                        width: 80,
                        child: LinearProgressIndicator(),
                      )
                    : rate != null
                        ? Text(
                            '₱ ${rate!.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: ColorStyles.grabGreen,
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '⚠ API PENDING',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.deepOrange,
                              ),
                            ),
                          ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 7-Day Calendar Strip ─────────────────────────────────────────────────────

class _CalendarStrip extends StatelessWidget {
  const _CalendarStrip({
    required this.days,
    required this.selectedDay,
    required this.onDaySelected,
  });

  final List<DateTime> days;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: days.map((day) {
        final selected = _isSameDay(day, selectedDay);
        final dayLabel = DateFormat('EEE').format(day).toUpperCase();
        final dateLabel = day.day.toString();

        return Expanded(
          child: GestureDetector(
            onTap: () => onDaySelected(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding:
                  const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? ColorStyles.grabGreen
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? ColorStyles.grabGreen
                      : Colors.grey.shade300,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dayLabel,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? Colors.white70
                          : Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateLabel,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color:
                          selected ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

