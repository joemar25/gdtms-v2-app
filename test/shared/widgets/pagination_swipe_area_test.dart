// Tests for PaginationSwipeArea — the shared swipe-to-paginate gesture.
//
// Covered:
//   1. Fling left on a middle page advances to the next page.
//   2. Fling right on a middle page goes back a page.
//   3. Fling left on the last page is a no-op (upper bound guard).
//   4. Fling right on the first page is a no-op (lower bound guard).
//   5. A slow drag below the velocity threshold does not change the page.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsi_courier_app/shared/widgets/pagination_swipe_area.dart';

Widget _harness({
  required int currentPage,
  required int totalPages,
  required ValueChanged<int> onPageChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: PaginationSwipeArea(
        currentPage: currentPage,
        totalPages: totalPages,
        onPageChanged: onPageChanged,
        child: Container(
          key: const ValueKey('swipe-target'),
          color: Colors.blue,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    ),
  );
}

void main() {
  final target = find.byKey(const ValueKey('swipe-target'));

  testWidgets('fling left on a middle page advances to the next page', (
    tester,
  ) async {
    int? changedTo;
    await tester.pumpWidget(
      _harness(
        currentPage: 1,
        totalPages: 3,
        onPageChanged: (p) => changedTo = p,
      ),
    );

    await tester.fling(target, const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();

    expect(changedTo, 2);
  });

  testWidgets('fling right on a middle page goes back a page', (tester) async {
    int? changedTo;
    await tester.pumpWidget(
      _harness(
        currentPage: 1,
        totalPages: 3,
        onPageChanged: (p) => changedTo = p,
      ),
    );

    await tester.fling(target, const Offset(300, 0), 1000);
    await tester.pumpAndSettle();

    expect(changedTo, 0);
  });

  testWidgets('fling left on the last page does not change the page', (
    tester,
  ) async {
    int? changedTo;
    await tester.pumpWidget(
      _harness(
        currentPage: 2,
        totalPages: 3,
        onPageChanged: (p) => changedTo = p,
      ),
    );

    await tester.fling(target, const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();

    expect(changedTo, isNull);
  });

  testWidgets('fling right on the first page does not change the page', (
    tester,
  ) async {
    int? changedTo;
    await tester.pumpWidget(
      _harness(
        currentPage: 0,
        totalPages: 3,
        onPageChanged: (p) => changedTo = p,
      ),
    );

    await tester.fling(target, const Offset(300, 0), 1000);
    await tester.pumpAndSettle();

    expect(changedTo, isNull);
  });

  testWidgets('a slow drag below the velocity threshold is a no-op', (
    tester,
  ) async {
    int? changedTo;
    await tester.pumpWidget(
      _harness(
        currentPage: 1,
        totalPages: 3,
        onPageChanged: (p) => changedTo = p,
      ),
    );

    await tester.timedDrag(
      target,
      const Offset(-50, 0),
      const Duration(seconds: 2),
    );
    await tester.pumpAndSettle();

    expect(changedTo, isNull);
  });
}
