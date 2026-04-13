// DOCS: docs/shared/widgets.md — update that file when you edit this one.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/shared/helpers/formatters.dart';

class AppSearchBar extends StatefulWidget {
  const AppSearchBar({
    super.key,
    required this.onChanged,
    this.controller,
    this.query = '',
    this.hintText = 'SEARCH',
    this.autofocus = false,
    this.isLoading = false,
    this.resultCount,
    this.totalCount,
    this.onClear,
  });

  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final String query;
  final String hintText;
  final bool autofocus;
  final bool isLoading;
  final int? resultCount;
  final int? totalCount;
  final VoidCallback? onClear;

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late final TextEditingController _controller;
  Timer? _debounce;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _hasText = _controller.text.isNotEmpty;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() => _hasText = value.isNotEmpty);
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => widget.onChanged(value),
    );
  }

  void _clear() {
    _controller.clear();
    setState(() => _hasText = false);
    _debounce?.cancel();
    if (widget.onClear != null) {
      widget.onClear!();
    } else {
      widget.onChanged('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : cs.surface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF2A2A3E)
                  : cs.surfaceContainerHighest,
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
              controller: _controller,
              autofocus: widget.autofocus,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [UpperCaseFormatter()],
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
              decoration: InputDecoration(
                hintText: widget.hintText,
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
                suffixIcon: (widget.query.isNotEmpty || _hasText)
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: cs.onSurfaceVariant,
                        onPressed: _clear,
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 4,
                ),
              ),
              onChanged: _onChanged,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 4),
              if (widget.isLoading) ...[
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'SEARCHING…',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                    letterSpacing: 0.8,
                  ),
                ),
              ] else if (widget.resultCount != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${widget.resultCount} RESULT${widget.resultCount == 1 ? '' : 'S'}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ] else if (widget.totalCount != null) ...[
                Text(
                  '${widget.totalCount} ITEM${widget.totalCount == 1 ? '' : 'S'} TOTAL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
