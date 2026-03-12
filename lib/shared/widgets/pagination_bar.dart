import 'package:flutter/material.dart';

class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.firstItem,
    required this.lastItem,
    required this.totalCount,
    required this.onPageChanged,
  });

  final int currentPage;
  final int totalPages;
  final int firstItem;
  final int lastItem;
  final int totalCount;
  final ValueChanged<int> onPageChanged;

  /// Returns up to 5 page numbers centred around [currentPage].
  List<int> get _pageNumbers {
    if (totalPages <= 7) return List.generate(totalPages, (i) => i);
    final start = (currentPage - 2).clamp(0, totalPages - 5);
    return List.generate(5, (i) => start + i);
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
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Range label ─────────────────────────────────────────────────
          Text(
            '$firstItem–$lastItem of $totalCount',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          // ── Page controls ───────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // First page
              _NavButton(
                icon: Icons.first_page_rounded,
                enabled: currentPage > 0,
                onTap: () => onPageChanged(0),
              ),
              // Previous
              _NavButton(
                icon: Icons.chevron_left_rounded,
                enabled: currentPage > 0,
                onTap: () => onPageChanged(currentPage - 1),
              ),
              const SizedBox(width: 4),
              // Page number chips
              ..._pageNumbers.map(
                (page) => _PageChip(
                  page: page,
                  isSelected: page == currentPage,
                  onTap: () => onPageChanged(page),
                ),
              ),
              const SizedBox(width: 4),
              // Next
              _NavButton(
                icon: Icons.chevron_right_rounded,
                enabled: currentPage < totalPages - 1,
                onTap: () => onPageChanged(currentPage + 1),
              ),
              // Last page
              _NavButton(
                icon: Icons.last_page_rounded,
                enabled: currentPage < totalPages - 1,
                onTap: () => onPageChanged(totalPages - 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 22,
          color: enabled ? cs.onSurface : cs.onSurface.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}

class _PageChip extends StatelessWidget {
  const _PageChip({
    required this.page,
    required this.isSelected,
    required this.onTap,
  });

  final int page;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: isSelected ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: isSelected ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? null
              : Border.all(color: cs.outline.withValues(alpha: 0.3)),
        ),
        alignment: Alignment.center,
        child: Text(
          '${page + 1}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? cs.onPrimary : cs.onSurface,
          ),
        ),
      ),
    );
  }
}
