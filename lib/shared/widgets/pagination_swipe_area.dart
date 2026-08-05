// DOCS: docs/development-standards.md
// DOCS: docs/shared/widgets.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Swipe-left/right-to-change-page gesture for any screen paired with
/// [PaginationBar]. Centralized here so the gesture travels with the
/// pagination pattern instead of being hand-copied per screen, where it
/// has silently gone missing before during unrelated widget-tree refactors.
class PaginationSwipeArea extends StatelessWidget {
  const PaginationSwipeArea({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    required this.child,
  });

  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;
  final Widget child;

  static const double _kSwipeVelocityThreshold = 200;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -_kSwipeVelocityThreshold &&
            currentPage < totalPages - 1) {
          HapticFeedback.mediumImpact();
          onPageChanged(currentPage + 1);
        } else if (velocity > _kSwipeVelocityThreshold && currentPage > 0) {
          HapticFeedback.mediumImpact();
          onPageChanged(currentPage - 1);
        }
      },
      child: child,
    );
  }
}
