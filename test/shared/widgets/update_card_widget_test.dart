import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:open_filex/open_filex.dart';
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
    final testInfo = UpdateInfo(
      latestVersion: '2.0.0',
      minimumVersion: '1.0.0',
      downloadUrl: 'https://example.com/app.apk',
      fileSizeMb: 15.5,
      releaseNotes: 'New features',
      checksumSha256: 'abc',
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

      // Trigger check
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppUpdateCard)),
      );
      await container.read(updateProvider.notifier).checkForUpdate();
      await tester.pumpAndSettle();

      expect(find.text('Update Available'), findsOneWidget);
      expect(find.textContaining('Latest: v2.0.0'), findsOneWidget);
    });

    testWidgets('tapping download and install flow', (tester) async {
      when(
        () => mockService.checkForUpdate(),
      ).thenAnswer((_) async => testInfo);
      when(() => mockService.downloadUpdate(any(), any())).thenAnswer((
        invocation,
      ) async {
        final onProgress =
            invocation.positionalArguments[1] as Function(double);
        await Future.delayed(const Duration(milliseconds: 100));
        onProgress(0.5);
        await Future.delayed(const Duration(milliseconds: 100));
        return '/mock/path/app.apk';
      });
      when(
        () => mockService.verifyChecksum(any(), any()),
      ).thenAnswer((_) async => true);
      when(
        () => mockService.installUpdate(any()),
      ).thenAnswer((_) async => OpenResult(type: ResultType.done));

      await tester.pumpWidget(createWidgetUnderTest());

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppUpdateCard)),
      );
      await container.read(updateProvider.notifier).checkForUpdate();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Download & Install Update'));
      await tester.pump(const Duration(milliseconds: 50)); // Start download

      // Check progress
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle(); // Finish download and auto-trigger install

      verify(() => mockService.downloadUpdate(any(), any())).called(1);
      verify(() => mockService.installUpdate('/mock/path/app.apk')).called(1);
    });
  });
}
