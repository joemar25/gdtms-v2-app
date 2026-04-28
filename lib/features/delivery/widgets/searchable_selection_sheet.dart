// DOCS: docs/development-standards.md
// DOCS: docs/features/delivery.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

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
      backgroundColor: DSColors.transparent,
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
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final bgColor = widget.isDark ? DSColors.cardDark : DSColors.white;
    final surfaceColor = widget.isDark
        ? DSColors.white.withValues(alpha: DSStyles.alphaSubtle)
        : DSColors.scaffoldLight;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DSSpacing.xl),
        ),
        boxShadow: [
          BoxShadow(
            color: DSColors.black.withValues(alpha: DSStyles.alphaMuted),
            blurRadius: DSStyles.radiusXL,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Handle ──────────────────────────────────────────────────────────
          DSSpacing.hMd,
          Container(
            width: DSIconSize.heroSm,
            height: 4,
            decoration: BoxDecoration(
              color: widget.isDark
                  ? DSColors.white.withValues(alpha: DSStyles.alphaMuted)
                  : DSColors.separatorLight,
              borderRadius: DSStyles.pillRadius,
            ),
          ),
          DSSpacing.hMd,

          // ── Header ──────────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(horizontal: DSSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title.toUpperCase(),
                    style: DSTypography.heading().copyWith(
                      fontSize: DSTypography.sizeMd,
                      fontWeight: FontWeight.w900,
                      letterSpacing: DSTypography.lsExtraLoose,
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
          DSSpacing.hMd,

          // ── Search Bar ──────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(horizontal: DSSpacing.lg),
            child: Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: DSStyles.cardRadius,
                border: Border.all(
                  color: widget.isDark
                      ? DSColors.white.withValues(alpha: DSStyles.alphaSubtle)
                      : DSColors.secondarySurfaceLight,
                ),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                textCapitalization: TextCapitalization.characters,
                onChanged: _filter,
                decoration: InputDecoration(
                  hintText: 'SEARCH OPTIONS...',
                  labelStyle: DSTypography.body().copyWith(
                    fontSize: DSTypography.sizeMd,
                  ),
                  hintStyle: DSTypography.body(
                    color: DSColors.labelTertiary,
                  ).copyWith(
                    fontSize: DSTypography.sizeMd,
                    letterSpacing: DSTypography.lsLoose,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: DSIconSize.lg,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear_rounded,
                            size: DSIconSize.md,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _filter('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: DSSpacing.md),
                ),
              ),
            ),
          ),
          DSSpacing.hMd,

          // ── Options List ────────────────────────────────────────────────────
          Expanded(
            child: _filteredOptions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: DSIconSize.heroSm,
                          color: DSColors.labelTertiary,
                        ),
                        DSSpacing.hMd,
                        Text(
                          'NO MATCHES FOUND',
                          style: DSTypography.caption(
                            color: DSColors.labelTertiary,
                          ).copyWith(
                            fontSize: DSTypography.sizeSm,
                            fontWeight: FontWeight.w700,
                            letterSpacing: DSTypography.lsExtraLoose,
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
                        padding: EdgeInsets.only(bottom: DSSpacing.sm),
                        child: InkWell(
                          onTap: () => Navigator.pop(context, value),
                          borderRadius: DSStyles.cardRadius,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(
                              horizontal: DSSpacing.md,
                              vertical: DSSpacing.md,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? DSColors.primary.withValues(
                                      alpha: DSStyles.alphaSoft,
                                    )
                                  : DSColors.transparent,
                              borderRadius: DSStyles.cardRadius,
                              border: Border.all(
                                color: isSelected
                                    ? DSColors.primary.withValues(alpha: 0.5)
                                    : DSColors.transparent,
                                width: DSStyles.borderWidth * 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    label,
                                    style: DSTypography.body(
                                      color: isSelected
                                          ? DSColors.primary
                                          : (widget.isDark
                                                ? DSColors.white
                                                : DSColors.labelPrimary),
                                    ).copyWith(
                                      fontSize: DSTypography.sizeMd,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: DSColors.primary,
                                    size: DSIconSize.md,
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
