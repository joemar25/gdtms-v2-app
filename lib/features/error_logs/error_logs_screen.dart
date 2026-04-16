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
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: DSStyles.cardRadius,
                          border: Border.all(
                            color: Colors.grey.withValues(
                              alpha: DSStyles.alphaDarkShadow,
                            ),
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
                                fontSize: 12,
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
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) =>
                                _LogCard(entry: _filtered[i], isDark: isDark),
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 16,
              color: Colors.green.shade500,
            ),
            const SizedBox(width: 8),
            Text(
              'No errors recorded.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.green.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          if (errorCount > 0) ...[
            _Chip(
              icon: Icons.error_outline_rounded,
              label: '$errorCount error${errorCount == 1 ? '' : 's'}',
              color: Colors.red,
            ),
            const SizedBox(width: 8),
          ],
          if (warningCount > 0)
            _Chip(
              icon: Icons.warning_amber_rounded,
              label: '$warningCount warning${warningCount == 1 ? '' : 's'}',
              color: Colors.orange,
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final MaterialColor color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: DSStyles.alphaSoft),
        borderRadius: DSStyles.cardRadius,
        border: Border.all(
          color: color.withValues(alpha: DSStyles.alphaDarkShadow),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color.shade600),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color.shade700,
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
    final color = isError ? Colors.red : Colors.orange;
    final fmt = DateFormat('MMM d, y HH:mm:ss');

    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: DSStyles.cardRadius,
        border: Border.all(
          color: color.withValues(alpha: DSStyles.alphaDarkShadow),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDark ? 0.2 : 0.04),
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
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  e.barcode!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
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
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Timestamp
                        Text(
                          fmt.format(e.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
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
                      color: Colors.grey.shade400,
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
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: widget.isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade700,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Long-press to copy',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade400,
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
    'sync': Color(0xFF0EA5E9),
    'delivery_update': Color(0xFF8B5CF6),
    'api': Color(0xFFEC4899),
    'scan': Color(0xFF10B981),
  };

  @override
  Widget build(BuildContext ctx) {
    final color = _colors[context] ?? Colors.blueGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
          letterSpacing: 0.5,
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
            color: Colors.green.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            'No logs to show',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Errors and warnings will appear here\nwhen they occur.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
