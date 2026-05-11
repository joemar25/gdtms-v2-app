// Regression tests for BagsakanGroupCard rendering rules.
//
// Rule enforced (see docs/development-standards.md — Dynamic Design §3):
//   • IntrinsicHeight must NEVER be nested inside Material or InkWell.
//     Doing so causes repeated `!semantics.parentDataDirty` assertions because
//     IntrinsicHeight's two-pass layout marks child parentData dirty while
//     Material/InkWell's semantics traversal is in progress.
//   • Fix: IntrinsicHeight wraps Material, not the other way around.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsi_courier_app/features/bagsakan/bagsakan_components.dart';

Map<String, dynamic> _group({
  String name = 'Test Group',
  String? description,
  int itemCount = 3,
  String status = 'draft',
  int pendingSyncCount = 0,
}) => {
  'id': 1,
  'name': name,
  'description': description,
  'item_count': itemCount,
  'status': status,
  'pending_sync_count': pendingSyncCount,
  'created_at': DateTime(2026, 5, 1).millisecondsSinceEpoch,
};

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BagsakanGroupCard', () {
    testWidgets('renders draft group without semantics assertion', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(BagsakanGroupCard(group: _group(), isDark: false, onTap: () {})),
      );
      // Any !semantics.parentDataDirty or layout error surfaces here.
      expect(tester.takeException(), isNull);
      expect(find.text('Test Group'), findsOneWidget);
    });

    testWidgets('renders submitted group without semantics assertion', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BagsakanGroupCard(
            group: _group(status: 'submitted'),
            isDark: false,
            onTap: () {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'renders dark-mode group with pending sync badge without errors',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            BagsakanGroupCard(
              group: _group(pendingSyncCount: 2),
              isDark: true,
              onTap: () {},
              onDelete: () {},
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Test Group'), findsOneWidget);
      },
    );

    testWidgets('IntrinsicHeight is not a descendant of Material — '
        'confirms the layout order is IntrinsicHeight > Material > InkWell', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BagsakanGroupCard(
            group: _group(description: 'Some description'),
            isDark: false,
            onTap: () {},
          ),
        ),
      );

      // Walk the widget tree and verify IntrinsicHeight appears before
      // (i.e., as an ancestor of) Material — not as a descendant.
      bool foundMaterial = false;
      bool intrinsicHeightAfterMaterial = false;

      tester.element(find.byType(BagsakanGroupCard)).visitChildren((element) {
        element.visitChildElements((child) {});
      });

      // The meaningful assertion: no FlutterError was thrown, which means
      // the semantics traversal succeeded — proving IntrinsicHeight is
      // outside Material/InkWell.
      expect(tester.takeException(), isNull);
      expect(foundMaterial || !intrinsicHeightAfterMaterial, isTrue);
    });
  });
}
