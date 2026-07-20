import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fsi_courier_app/core/providers/update_provider.dart';
import 'package:fsi_courier_app/shared/widgets/update_card_widget.dart';
import 'package:fsi_courier_app/models/update_info.dart';
import 'package:fsi_courier_app/services/update_service.dart';

class MockUpdateService extends Mock implements UpdateService {}

void main() {
  late MockUpdateService mockService;

  setUp(() {
    mockService = MockUpdateService();
    // Default mock behavior
    when(() => mockService.checkForUpdate()).thenAnswer((_) async => null);
  });

  Widget createWidgetUnderTest({bool isDark = false}) {
    return ProviderScope(
      overrides: [updateServiceProvider.overrideWithValue(mockService)],
      child: MaterialApp(
        home: Scaffold(body: AppUpdateCard(isDark: isDark)),
      ),
    );
  }

  group('AppUpdateCard Widget Tests', () {
    const testInfo = UpdateInfo(
      latestVersion: '2.0.0',
      minimumVersion: '1.0.0',
      releaseNotes: 'New features',
      isMandatory: false,
    );

    testWidgets('displays "App is up to date" when no update available', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('App is up to date ✓'), findsOneWidget);
    });

    testWidgets('displays "Update Available" when update exists', (
      tester,
    ) async {
      when(
        () => mockService.checkForUpdate(),
      ).thenAnswer((_) async => testInfo);

      await tester.pumpWidget(createWidgetUnderTest());

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppUpdateCard)),
      );
      await container.read(updateProvider.notifier).checkForUpdate();
      await tester.pumpAndSettle();

      expect(find.text('Update Available'), findsOneWidget);
      expect(find.textContaining('Latest: v2.0.0'), findsOneWidget);
    });

    testWidgets('tapping the button opens the store listing', (tester) async {
      when(
        () => mockService.checkForUpdate(),
      ).thenAnswer((_) async => testInfo);
      when(
        () => mockService.launchStoreListing(),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(createWidgetUnderTest());

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppUpdateCard)),
      );
      await container.read(updateProvider.notifier).checkForUpdate();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update on Play Store'));
      await tester.pumpAndSettle();

      verify(() => mockService.launchStoreListing()).called(1);
      expect(find.textContaining('Could not open'), findsNothing);
    });

    testWidgets('shows an error snackbar when the store cannot be opened', (
      tester,
    ) async {
      when(
        () => mockService.checkForUpdate(),
      ).thenAnswer((_) async => testInfo);
      when(
        () => mockService.launchStoreListing(),
      ).thenAnswer((_) async => false);

      await tester.pumpWidget(createWidgetUnderTest());

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppUpdateCard)),
      );
      await container.read(updateProvider.notifier).checkForUpdate();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update on Play Store'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not open'), findsOneWidget);
    });
  });
}
