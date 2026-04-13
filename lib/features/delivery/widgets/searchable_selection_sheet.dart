// DOCS: docs/features/delivery.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';

/// A premium, searchable bottom sheet for selecting from a list of options.
/// Supports both simple [String] lists and [Map<String, String>] lists with 'label'/'value' keys.
class SearchableSelectionSheet extends StatefulWidget {
  const SearchableSelectionSheet({
    super.key,
    required this.title,
    required this.options,
    this.initialValue,
    required this.isDark,
  });

  final String title;
  final List<dynamic> options;
  final dynamic initialValue;
  final bool isDark;

  @override
  State<SearchableSelectionSheet> createState() =>
      _SearchableSelectionSheetState();

  /// Static helper to show the sheet.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required List<dynamic> options,
    T? initialValue,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SearchableSelectionSheet(
        title: title,
        options: options,
        initialValue: initialValue,
        isDark: isDark,
      ),
    );
  }
}

class _SearchableSelectionSheetState extends State<SearchableSelectionSheet> {
  late List<dynamic> _filteredOptions;
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _filteredOptions = widget.options;
    // Auto-focus the search field after the sheet animation completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _focusNode.requestFocus();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _filter(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredOptions = widget.options;
      } else {
        _filteredOptions = widget.options.where((opt) {
          final String label = _getLabel(opt);
          return label.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  String _getLabel(dynamic opt) {
    if (opt is Map) return opt['label'] ?? opt['value'] ?? '';
    return opt.toString();
  }

  dynamic _getValue(dynamic opt) {
    if (opt is Map) return opt['value'] ?? opt['label'];
    return opt;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final bgColor = widget.isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final surfaceColor = widget.isDark ? Colors.white12 : Colors.grey.shade50;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Handle ──────────────────────────────────────────────────────────
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // ── Header ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Search Bar ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.isDark ? Colors.white10 : Colors.grey.shade200,
                ),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                textCapitalization: TextCapitalization.characters,
                onChanged: _filter,
                decoration: InputDecoration(
                  hintText: 'SEARCH OPTIONS...',
                  labelStyle: const TextStyle(fontSize: 13),
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _filter('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Options List ────────────────────────────────────────────────────
          Expanded(
            child: _filteredOptions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'NO MATCHES FOUND',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade500,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 20 + bottomPadding),
                    itemCount: _filteredOptions.length,
                    itemBuilder: (context, index) {
                      final opt = _filteredOptions[index];
                      final label = _getLabel(opt);
                      final value = _getValue(opt);
                      final isSelected = value == widget.initialValue;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => Navigator.pop(context, value),
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? ColorStyles.grabGreen.withValues(alpha: 0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? ColorStyles.grabGreen.withValues(
                                        alpha: 0.5,
                                      )
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? ColorStyles.grabGreen
                                          : (widget.isDark
                                                ? Colors.white
                                                : Colors.black87),
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: ColorStyles.grabGreen,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
