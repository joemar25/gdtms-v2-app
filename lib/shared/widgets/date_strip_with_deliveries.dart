import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:fsi_courier_app/core/settings/compact_mode_provider.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_identifier.dart';
import 'package:fsi_courier_app/shared/widgets/delivery_card.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';

/// A horizontally-scrollable date strip paired with a delivery list for the
/// selected day.
///
/// - Today (or [referenceDate]) is the **rightmost** tile; scrolling left
///   reveals older dates. Load-more happens automatically when the user
///   scrolls within 150 px of the left edge, adding 7 more days.
/// - Dates that have deliveries show a green dot indicator.
/// - Provide [itemBuilder] to customise each delivery row; the default renders
///   [DeliveryCard] and navigates to the delivery detail page on tap.
class DateStripWithDeliveries extends StatefulWidget {
  const DateStripWithDeliveries({
    super.key,
    required this.dailyBreakdown,
    this.initialSelectedDate,
    this.referenceDate,
    this.itemBuilder,
    this.showDayTotal = true,
    this.dataMode = false,
    this.hasMorePages = false,
    this.onLoadMore,
    this.itemCountLabelBuilder,
    this.enableHoldToReveal = true,
  });

  /// Flat list of day objects. Each entry should have:
  ///   • `date`           – "YYYY-MM-DD"
  ///   • `deliveries`     – List of delivery maps
  ///   • `delivery_count` – int  (or `count` as fallback)
  ///   • `day_total`      – num  (optional; used when [showDayTotal] is true)
  final List<Map<String, dynamic>> dailyBreakdown;

  /// The date tile that is pre-selected when the widget first mounts.
  /// Defaults to [referenceDate]'s day (or today) if any deliveries exist.
  final String? initialSelectedDate;

  /// The anchor date shown at index 0 (leftmost). Defaults to [DateTime.now()].
  /// Pass the coverage `to_date` when displaying a historical payout so the
  /// relevant dates are immediately visible.
  final DateTime? referenceDate;

  /// Optional custom builder for each delivery item in the selected day.
  /// Defaults to [DeliveryCard] with navigation on tap.
  final Widget Function(BuildContext context, Map<String, dynamic> delivery)?
  itemBuilder;

  /// Whether to show the ₱ total on the right of the day header row.
  final bool showDayTotal;

  /// When [dataMode] is true, the strip shows only tiles for dates that have
  /// data in [dailyBreakdown] — no virtual empty tiles are generated.
  /// Virtual date-expansion is disabled; instead if [hasMorePages] is true
  /// and [onLoadMore] is provided, that callback is invoked when the user
  /// scrolls near the left edge.
  final bool dataMode;

  /// Whether there is a next page of data to load.
  /// Only used when [dataMode] is true and [onLoadMore] is provided.
  final bool hasMorePages;

  /// Called when the user scrolls near the left edge, [dataMode] is true,
  /// [hasMorePages] is true, and [onLoadMore] is non-null.
  /// Pass `null` while a load is in flight to suppress duplicate calls.
  final VoidCallback? onLoadMore;

  /// Defaults to "N delivery / N deliveries".
  final String Function(int count)? itemCountLabelBuilder;

  /// Whether to enable the "Hold-to-Reveal" feature in [DeliveryCard].
  final bool enableHoldToReveal;

  @override
  State<DateStripWithDeliveries> createState() =>
      _DateStripWithDeliveriesState();
}

class _DateStripWithDeliveriesState extends State<DateStripWithDeliveries> {
  late String? _selectedDate;
  int _daysShown = 30;
  bool _loadingMoreDates = false;
  /// Guards against load-more firing during the initial programmatic scroll.
  bool _loadMoreEnabled = false;
  late final ScrollController _scrollCtrl;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController();
    _selectedDate = widget.initialSelectedDate ?? _defaultDate();
    // Jump to the right end (today) after layout so the newest date is visible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
      // Enable load-more only after the initial jump has fully settled.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _loadMoreEnabled = true);
      });
    });
  }

  @override
  void didUpdateWidget(DateStripWithDeliveries old) {
    super.didUpdateWidget(old);
    // In dataMode, the parent drives loading state via onLoadMore nullability:
    // onLoadMore goes null while loading, then back to non-null when done.
    // When it transitions back to non-null, reset the internal spinner.
    if (widget.dataMode &&
        _loadingMoreDates &&
        old.onLoadMore == null &&
        widget.onLoadMore != null) {
      setState(() => _loadingMoreDates = false);
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  String? _defaultDate() {
    // Determine the anchor date (Today or referenceDate)
    final anchor = widget.referenceDate ?? DateTime.now();
    return _toDateStr(anchor);
  }

  // ── Formatters ────────────────────────────────────────────────────────────

  String _dayLabel(String d) {
    try {
      final dt = DateTime.parse(d);
      return '${DateFormat('MMM').format(dt)} ${DateFormat('d').format(dt)}';
    } catch (_) {
      return '';
    }
  }

  String _dayYear(String d) {
    try {
      return DateFormat('yyyy').format(DateTime.parse(d));
    } catch (_) {
      return '';
    }
  }


  String _dateHeader(String d) {
    try {
      return DateFormat('EEE, MMM d').format(DateTime.parse(d));
    } catch (_) {
      return d;
    }
  }

  String _toDateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── Helpers ───────────────────────────────────────────────────────────────

  int _countFor(String dateStr, Map<String, Map<String, dynamic>> index) {
    final d = index[dateStr];
    
    // Fall back to list length if count fields are missing or zero but list has items.
    // This is crucial for history items that might not have explicit count metadata.
    final list = d?['deliveries'] as List?;
    if (list != null && list.isNotEmpty) return list.length;

    final fromCount = d?['delivery_count'] ?? d?['count'];
    if (fromCount != null) return (fromCount as num).toInt();
    
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final isCompact = ref.watch(compactModeProvider);
        return _buildContent(context, isCompact);
      },
    );
  }

  Widget _buildContent(BuildContext context, bool isCompact) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? ColorStyles.grabCardDark : ColorStyles.white;
    final subtleBg = isDark ? ColorStyles.grabCardElevatedDark : ColorStyles.grabCardLight;
    final cardBorder = isDark
        ? ColorStyles.white.withValues(alpha: 0.10)
        : ColorStyles.tertiary;
    final primaryText = isDark ? ColorStyles.white : ColorStyles.black;

    // Build a lookup index keyed by date string
    final breakdownIndex = <String, Map<String, dynamic>>{
      for (final d in widget.dailyBreakdown)
        if (d['date'] is String) d['date'] as String: d,
    };

    // Dates: oldest at index 0 (leftmost), newest at the end (rightmost).
    // In dataMode, only tiles that have data are shown (no virtual empties).
    final List<DateTime> allDates;
    if (widget.dataMode) {
      final parsedDates = widget.dailyBreakdown
          .map((d) => d['date'] as String?)
          .whereType<String>()
          .map((s) {
            try { return DateTime.parse(s); } catch (_) { return null; }
          })
          .whereType<DateTime>()
          .toList();
          
      // Force include today if it's the requested behavior
      final today = DateTime.now();
      final todayNormalized = DateTime(today.year, today.month, today.day);
      if (!parsedDates.any((d) => d.year == today.year && d.month == today.month && d.day == today.day)) {
        parsedDates.add(todayNormalized);
      }
      allDates = parsedDates..sort();
    } else {
      final anchorDate = widget.referenceDate ?? DateTime.now();
      final anchor =
          DateTime(anchorDate.year, anchorDate.month, anchorDate.day);
      allDates = List.generate(_daysShown, (i) {
        // i=0 → oldest day; i=_daysShown-1 → anchor (today)
        final d = anchor.subtract(Duration(days: _daysShown - 1 - i));
        return DateTime(d.year, d.month, d.day);
      });
    }

    // Selected day data
    final selectedDay =
        (_selectedDate != null ? breakdownIndex[_selectedDate] : null) ??
        const <String, dynamic>{};
    final deliveries =
        (selectedDay['deliveries'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    final dayTotal = (selectedDay['day_total'] as num?)?.toDouble() ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Date strip ──────────────────────────────────────────────────────
        SizedBox(
          height: 85,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notif) {
              if (notif is ScrollUpdateNotification && _loadMoreEnabled) {
                final cur = notif.metrics.pixels;
                // Load more older dates when scrolling near the LEFT edge
                if (!_loadingMoreDates && cur <= 150) {
                  if (widget.dataMode) {
                    // Data-driven mode: delegate to the parent's load callback.
                    if (widget.hasMorePages && widget.onLoadMore != null) {
                      setState(() => _loadingMoreDates = true);
                      widget.onLoadMore!();
                    }
                  } else {
                    // Virtual mode: expand the date window by 7 days.
                    setState(() => _loadingMoreDates = true);
                    final prevMax = notif.metrics.maxScrollExtent;
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (mounted) {
                        setState(() {
                          _daysShown += 7;
                          _loadingMoreDates = false;
                        });
                        // Restore scroll position so the view doesn't jump.
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_scrollCtrl.hasClients) {
                            final newMax =
                                _scrollCtrl.position.maxScrollExtent;
                            _scrollCtrl.jumpTo(newMax - prevMax + cur);
                          }
                        });
                      }
                    });
                  }
                }
              }
              return false;
            },
            child: ListView.builder(
              controller: _scrollCtrl,
              scrollDirection: Axis.horizontal,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: allDates.length + (_loadingMoreDates ? 1 : 0),
              itemBuilder: (ctx, i) {
                // Loading spinner prepended at the leading (left) end
                if (_loadingMoreDates && i == 0) {
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 60,
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cardBorder),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }

                final dateIndex = _loadingMoreDates ? i - 1 : i;
                final date = allDates[dateIndex];
                final dateStr = _toDateStr(date);
                final count = _countFor(dateStr, breakdownIndex);
                final hasDeliveries = count > 0;
                final selected = dateStr == _selectedDate;
                final isAnchor = dateIndex == allDates.length - 1; // today / referenceDate

                return GestureDetector(
                  onTap: () => setState(() => _selectedDate = dateStr),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? ColorStyles.grabGreen
                          : hasDeliveries
                          ? cardBg
                          : subtleBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? ColorStyles.grabGreen
                            : isAnchor
                            ? ColorStyles.grabGreen.withValues(alpha: 0.4)
                            : hasDeliveries
                            ? ColorStyles.subSecondary.withValues(alpha: 0.4)
                            : cardBorder,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _dayYear(dateStr),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? Colors.white.withValues(alpha: 0.7)
                                : ColorStyles.subSecondary.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _dayLabel(dateStr),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: selected
                                ? Colors.white
                                : primaryText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasDeliveries
                                ? (selected
                                      ? Colors.white
                                      : ColorStyles.grabGreen)
                                : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Day header ───────────────────────────────────────────────────────
        if (_selectedDate != null) ...[
          Row(
            children: [
              Text(
                _dateHeader(_selectedDate!),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: subtleBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.itemCountLabelBuilder != null
                      ? widget.itemCountLabelBuilder!(deliveries.length)
                      : (deliveries.length == 1
                            ? '1 delivery'
                            : '${deliveries.length} deliveries'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: ColorStyles.secondary,
                  ),
                ),
              ),
              if (widget.showDayTotal && dayTotal > 0) ...[
                const Spacer(),
                Text(
                  '₱ ${dayTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ColorStyles.grabGreen,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
        ],

        // ── Delivery list ────────────────────────────────────────────────────
        ...deliveries.map((d) {
          if (widget.itemBuilder != null) {
            return widget.itemBuilder!(context, d);
          }
          final barcode = resolveDeliveryIdentifier(d);
          final status = (d['delivery_status']?.toString() ?? 'PENDING').toUpperCase();
          final rtsVerifStatus =
              (d['_rts_verification_status']?.toString() ??
              d['rts_verification_status']?.toString() ??
              'unvalidated').toLowerCase();
          final isLocked = (status == 'OSA') || 
                           (status == 'RTS' && (rtsVerifStatus == 'verified_with_pay' || rtsVerifStatus == 'verified_no_pay'));

          return DeliveryCard(
            delivery: d,
            compact: isCompact,
            showChevron: barcode.isNotEmpty && !isLocked,
            enableHoldToReveal: widget.enableHoldToReveal,
            onTap: (barcode.isNotEmpty && !isLocked)
                ? () => context.push('/deliveries/$barcode')
                : () {},
          );
        }),
      ],
    );
  }
}
