// DOCS: docs/shared/widgets.md — update that file when you edit this one.

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:fsi_courier_app/shared/helpers/formatters.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

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
        color: isDark ? DSColors.scaffoldDark : DSColors.scaffoldLight,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? DSColors.white.withValues(alpha: DSStyles.alphaSubtle)
                : DSColors.black.withValues(alpha: DSStyles.alphaSoft),
            width: DSStyles.borderWidth,
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        DSSpacing.md,
        DSSpacing.sm,
        DSSpacing.md,
        DSSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? DSColors.cardDark : DSColors.cardLight,
              borderRadius: DSStyles.circularRadius,
              boxShadow: [
                BoxShadow(
                  color: DSColors.black.withValues(alpha: DSStyles.alphaSoft),
                  blurRadius: DSStyles.radiusSM,
                  offset: const Offset(0, DSSpacing.xs),
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
                hintStyle: DSTypography.caption(
                  color: isDark
                      ? DSColors.labelSecondaryDark
                      : DSColors.labelSecondary,
                ).copyWith(fontSize: DSTypography.sizeMd, letterSpacing: 0.4),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: cs.primary,
                  size: DSIconSize.lg,
                ),
                suffixIcon: (widget.query.isNotEmpty || _hasText)
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: DSIconSize.md,
                        ),
                        color: cs.onSurfaceVariant,
                        onPressed: _clear,
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: DSSpacing.xs,
                ),
              ),
              onChanged: _onChanged,
            ),
          ),
          DSSpacing.hSm,
          Row(
            children: [
              DSSpacing.wXs,
              if (widget.isLoading) ...[
                SizedBox(
                  width: DSIconSize.xs,
                  height: DSIconSize.xs,
                  child: CircularProgressIndicator(
                    strokeWidth: DSStyles.borderWidth * 1.5,
                    color: cs.primary,
                  ),
                ),
                DSSpacing.wSm,
                Text(
                  'SEARCHING…',
                  style: DSTypography.label(
                    color: DSColors.primary,
                  ).copyWith(fontSize: DSTypography.sizeSm),
                ),
              ] else if (widget.resultCount != null) ...[
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: DSSpacing.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: DSStyles.alphaSubtle),
                    borderRadius: DSStyles.cardRadius,
                  ),
                  child: Text(
                    '${widget.resultCount} RESULT${widget.resultCount == 1 ? '' : 'S'}',
                    style: DSTypography.label(
                      color: DSColors.primary,
                    ).copyWith(fontSize: DSTypography.sizeSm),
                  ),
                ),
              ] else if (widget.totalCount != null) ...[
                Text(
                  '${widget.totalCount} ITEM${widget.totalCount == 1 ? '' : 'S'} TOTAL',
                  style: DSTypography.caption(
                    color: isDark
                        ? DSColors.labelSecondaryDark
                        : DSColors.labelSecondary,
                  ).copyWith(fontSize: DSTypography.sizeSm, letterSpacing: 0.6),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
