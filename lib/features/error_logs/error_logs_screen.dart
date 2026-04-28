// DOCS: docs/features/error-logs.md — update that file when you edit this one.

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:fsi_courier_app/core/database/error_log_dao.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/widgets/confirmation_dialog.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

class ErrorLogsScreen extends StatefulWidget {
  const ErrorLogsScreen({super.key});

  @override
  State<ErrorLogsScreen> createState() => _ErrorLogsScreenState();
}

class _ErrorLogsScreenState extends State<ErrorLogsScreen> {
  List<ErrorLogEntry> _all = [];
  List<ErrorLogEntry> _filtered = [];
  bool _loading = true;
  String _selectedLevel = 'all'; // 'all' | 'error' | 'warning'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await ErrorLogDao.instance.getAll();
    if (!mounted) return;

    setState(() {
      _all = entries;
      _loading = false;
      _applyFilterAndResetIfNeeded();
    });
  }

  void _applyFilterAndResetIfNeeded() {
    // Normalize all levels to lowercase for consistent filtering
    final normalized = _all
        .map(
          (e) => ErrorLogEntry(
            id: e.id,
            level: e.level.toLowerCase(),
            context: e.context,
            message: e.message,
            detail: e.detail,
            barcode: e.barcode,
            createdAt: e.createdAt,
          ),
        )
        .toList();

    // First apply the filter with current selection
    if (_selectedLevel == 'all') {
      _filtered = List.from(normalized);
    } else {
      _filtered = normalized.where((e) => e.level == _selectedLevel).toList();
    }

    // Edge case fix: If the selected filter now has no items, reset to 'all'
    if (_selectedLevel != 'all' && _filtered.isEmpty) {
      _selectedLevel = 'all';
      _filtered = List.from(normalized);
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Clear All Logs',
      subtitle:
          'This will permanently delete all error logs from this device. This cannot be undone.',
      confirmLabel: 'Clear All',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;

    await ErrorLogDao.instance.clearAll();
    if (!mounted) return;

    showSuccessNotification(context, 'All error logs cleared');
    await _load(); // This will reset filter to 'all' automatically
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final errorCount = _all
        .where((e) => e.level.toLowerCase() == 'error')
        .length;
    final warningCount = _all
        .where((e) => e.level.toLowerCase() == 'warning')
        .length;

    return Scaffold(
      appBar: AppHeaderBar(
        title: 'Error Logs',
        actions: [
          if (_all.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Clear all',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Column(
                children: [
                  // ── Summary bar ────────────────────────────────────────────
                  _SummaryBar(
                    errorCount: errorCount,
                    warningCount: warningCount,
                  ),
                  // ── Level filter ───────────────────────────────────────────
                  if (_all.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        DSSpacing.base,
                        0,
                        DSSpacing.base,
                        DSSpacing.sm,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: DSStyles.cardRadius,
                          border: Border.all(
                            color: isDark
                                ? DSColors.separatorDark
                                : DSColors.separatorLight,
                          ),
                        ),
                        child: SegmentedButton<String>(
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                              value: 'all',
                              label: Text('All (${_all.length})'),
                            ),
                            ButtonSegment(
                              value: 'error',
                              label: Text('Errors ($errorCount)'),
                            ),
                            ButtonSegment(
                              value: 'warning',
                              label: Text('Warnings ($warningCount)'),
                            ),
                          ],
                          selected: {_selectedLevel},
                          style: ButtonStyle(
                            textStyle: WidgetStateProperty.all(
                              const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: DSTypography.sizeSm,
                              ),
                            ),
                            shape: WidgetStateProperty.all(
                              RoundedRectangleBorder(
                                borderRadius: DSStyles.cardRadius,
                              ),
                            ),
                          ),
                          onSelectionChanged: (val) {
                            setState(() {
                              _selectedLevel = val.first;
                              _applyFilterAndResetIfNeeded();
                            });
                          },
                        ),
                      ),
                    ),
                  // ── List ───────────────────────────────────────────────────
                  Expanded(
                    child: _filtered.isEmpty
                        ? _EmptyState(isDark: isDark)
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              DSSpacing.base,
                              0,
                              DSSpacing.base,
                              DSSpacing.xl,
                            ),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, _) => DSSpacing.hSm,
                            itemBuilder: (context, i) =>
                                _LogCard(entry: _filtered[i], isDark: isDark)
                                    .dsCardEntry(
                                  delay: DSAnimations.stagger(
                                    i,
                                    step: DSAnimations.staggerFine,
                                  ),
                                ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ─── Summary Bar ─────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.errorCount, required this.warningCount});

  final int errorCount;
  final int warningCount;

  @override
  Widget build(BuildContext context) {
    if (errorCount == 0 && warningCount == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DSSpacing.base,
          vertical: DSSpacing.md,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 16,
              color: DSColors.success,
            ),
            DSSpacing.wSm,
            Text(
              'No errors recorded.',
              style: TextStyle(
                fontSize: DSTypography.sizeMd,
                color: DSColors.successText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DSSpacing.base,
        vertical: DSSpacing.md,
      ),
      child: Row(
        children: [
          if (errorCount > 0) ...[
            _Chip(
              icon: Icons.error_outline_rounded,
              label: '$errorCount error${errorCount == 1 ? '' : 's'}',
              color: DSColors.error,
              textColor: DSColors.errorText,
              surfaceColor: DSColors.errorSurface,
            ),
            DSSpacing.wSm,
          ],
          if (warningCount > 0)
            _Chip(
              icon: Icons.warning_amber_rounded,
              label: '$warningCount warning${warningCount == 1 ? '' : 's'}',
              color: DSColors.warning,
              textColor: DSColors.warningText,
              surfaceColor: DSColors.warningSurface,
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    required this.surfaceColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final Color surfaceColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DSSpacing.md,
        vertical: DSSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: DSStyles.cardRadius,
        border: Border.all(
          color: color.withValues(alpha: DSStyles.alphaDarkShadow),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: DSTypography.sizeXs + 1, color: color),
          DSSpacing.wXs,
          Text(
            label,
            style: TextStyle(
              fontSize: DSTypography.sizeSm,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Log Card ─────────────────────────────────────────────────────────────────

class _LogCard extends StatefulWidget {
  const _LogCard({required this.entry, required this.isDark});

  final ErrorLogEntry entry;
  final bool isDark;

  @override
  State<_LogCard> createState() => _LogCardState();
}

class _LogCardState extends State<_LogCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final isError = e.level.toLowerCase() == 'error';
    final color = isError ? DSColors.error : DSColors.warning;
    final fmt = DateFormat('MMM d, y HH:mm:ss');

    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? DSColors.cardDark : DSColors.cardLight,
        borderRadius: DSStyles.cardRadius,
        border: Border.all(
          color: color.withValues(alpha: DSStyles.alphaDarkShadow),
        ),
        boxShadow: [
          BoxShadow(
            color: DSColors.black.withValues(alpha: widget.isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────────────────────────
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: e.detail != null
                ? () => setState(() => _expanded = !_expanded)
                : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isError
                        ? Icons.error_outline_rounded
                        : Icons.warning_amber_rounded,
                    size: 16,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Context badge + barcode
                        Row(
                          children: [
                            _ContextBadge(context: e.context),
                            if (e.barcode != null) ...[
                              DSSpacing.wXs,
                              Flexible(
                                child: Text(
                                  e.barcode!,
                                  style: TextStyle(
                                    fontSize: DSTypography.sizeSm,
                                    color: widget.isDark
                                        ? DSColors.labelTertiaryDark
                                        : DSColors.labelTertiary,
                                    fontFamily: 'monospace',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Message
                        Text(
                          e.message,
                          style: const TextStyle(
                            fontSize: DSTypography.sizeMd,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Timestamp
                        Text(
                          fmt.format(e.createdAt),
                          style: TextStyle(
                            fontSize: DSTypography.sizeSm,
                            color: widget.isDark
                                ? DSColors.labelSecondaryDark
                                : DSColors.labelSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (e.detail != null)
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                      color: widget.isDark
                          ? DSColors.labelTertiaryDark
                          : DSColors.labelTertiary,
                    ),
                ],
              ),
            ),
          ),
          // ── Expandable detail ─────────────────────────────────────────────
          if (_expanded && e.detail != null)
            InkWell(
              onLongPress: () {
                Clipboard.setData(
                  ClipboardData(text: '${e.message}\n\n${e.detail}'),
                );
                showSuccessNotification(context, 'Copied to clipboard');
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: DSStyles.alphaSoft),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(
                      height: 16,
                      color: color.withValues(
                        alpha: DSStyles.alphaActiveAccent,
                      ),
                    ),
                    Text(
                      e.detail!,
                      style: TextStyle(
                        fontSize: DSTypography.sizeSm,
                        fontFamily: 'monospace',
                        color: widget.isDark
                            ? DSColors.labelSecondaryDark
                            : DSColors.labelSecondary,
                        height: 1.5,
                      ),
                    ),
                    DSSpacing.hXs,
                    Text(
                      'Long-press to copy',
                      style: TextStyle(
                        fontSize: DSTypography.sizeXs,
                        color: widget.isDark
                            ? DSColors.labelTertiaryDark
                            : DSColors.labelTertiary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Context Badge ────────────────────────────────────────────────────────────

class _ContextBadge extends StatelessWidget {
  const _ContextBadge({required this.context});

  final String context;

  static const _colors = <String, Color>{
    'sync': DSColors.primary,
    'delivery_update': DSColors.accent,
    'api': DSColors.error,
    'scan': DSColors.primary,
  };

  @override
  Widget build(BuildContext ctx) {
    final color = _colors[context] ?? DSColors.labelSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DSSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: DSStyles.alphaActiveAccent),
        borderRadius: DSStyles.pillRadius,
      ),
      child: Text(
        context.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: DSTypography.lsLoose,
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 56,
            color: DSColors.success,
          ),
          const SizedBox(height: 16),
          const Text(
            'No logs to show',
            style: TextStyle(
              fontSize: DSTypography.sizeMd,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Errors and warnings will appear here\nwhen they occur.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: DSTypography.sizeMd,
              color: isDark
                  ? DSColors.labelSecondaryDark
                  : DSColors.labelSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
