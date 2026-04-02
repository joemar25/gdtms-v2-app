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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161625) : cs.surface,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: Range details
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'LISTING $firstItem – $lastItem',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'OF $totalCount ENTRIES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),

            // Right: Page Indicator + Swipe Prompt
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (currentPage > 0)
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onPageChanged(currentPage - 1),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.keyboard_arrow_left_rounded,
                          size: 16,
                          color: cs.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'PAGE ${currentPage + 1} / $totalPages',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  if (currentPage < totalPages - 1)
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onPageChanged(currentPage + 1),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.keyboard_arrow_right_rounded,
                          size: 16,
                          color: cs.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
