import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:open_filex/open_filex.dart';
import 'package:fsi_courier_app/core/providers/update_provider.dart';
import 'package:fsi_courier_app/services/update_service.dart';
import 'package:fsi_courier_app/models/update_info.dart';

class MockUpdateService extends Mock implements UpdateService {}

void main() {
  late MockUpdateService mockService;
  late ProviderContainer container;

  setUp(() {
    mockService = MockUpdateService();
    container = ProviderContainer(
      overrides: [updateServiceProvider.overrideWithValue(mockService)],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('UpdateNotifier', () {
    final testInfo = UpdateInfo(
      latestVersion: '2.0.0',
      minimumVersion: '1.0.0',
      downloadUrl: 'https://example.com/app.apk',
      fileSizeMb: 15.5,
      releaseNotes: 'New features',
      checksumSha256: 'abc',
      isMandatory: false,
    );

    test('initial state is idle', () {
      final state = container.read(updateProvider);
      expect(state.downloadStatus, UpdateDownloadStatus.idle);
      expect(state.downloadProgress, 0.0);
    });

    test('checkForUpdate updates state with info', () async {
      when(
        () => mockService.checkForUpdate(),
      ).thenAnswer((_) async => testInfo);

      await container.read(updateProvider.notifier).checkForUpdate();

      final state = container.read(updateProvider);
      expect(state.updateInfo, testInfo);
      expect(state.hasUpdate, true);
    });

    test(
      'startDownload handles successful download and verification',
      () async {
        // Setup state with update info
        when(
          () => mockService.checkForUpdate(),
        ).thenAnswer((_) async => testInfo);
        await container.read(updateProvider.notifier).checkForUpdate();

        // Mock download and verification
        when(() => mockService.downloadUpdate(any(), any())).thenAnswer((
          invocation,
        ) async {
          final onProgress =
              invocation.positionalArguments[1] as Function(double);
          onProgress(0.5);
          return '/mock/path/app.apk';
        });
        when(
          () => mockService.verifyChecksum(any(), any()),
        ).thenAnswer((_) async => true);

        final future = container.read(updateProvider.notifier).startDownload();

        // Check downloading state
        var state = container.read(updateProvider);
        expect(state.downloadStatus, UpdateDownloadStatus.downloading);

        await future;

        // Check completed state
        state = container.read(updateProvider);
        expect(state.downloadStatus, UpdateDownloadStatus.completed);
        expect(state.downloadProgress, 1.0);
        expect(state.downloadedFilePath, '/mock/path/app.apk');
      },
    );

    test('installUpdate calls service with correct path', () async {
      // Mock completed state
      when(
        () => mockService.checkForUpdate(),
      ).thenAnswer((_) async => testInfo);
      await container.read(updateProvider.notifier).checkForUpdate();

      when(
        () => mockService.downloadUpdate(any(), any()),
      ).thenAnswer((_) async => '/mock/path/app.apk');
      when(
        () => mockService.verifyChecksum(any(), any()),
      ).thenAnswer((_) async => true);

      await container.read(updateProvider.notifier).startDownload();

      when(() => mockService.installUpdate('/mock/path/app.apk')).thenAnswer(
        (_) async => OpenResult(type: ResultType.done, message: 'ok'),
      );

      final result = await container
          .read(updateProvider.notifier)
          .installUpdate();

      expect(result?.type, ResultType.done);
      verify(() => mockService.installUpdate('/mock/path/app.apk')).called(1);
    });

    test(
      'startDownload clears updateInfo on failure (broken link handling)',
      () async {
        // Setup state with update info
        when(
          () => mockService.checkForUpdate(),
        ).thenAnswer((_) async => testInfo);
        await container.read(updateProvider.notifier).checkForUpdate();

        // Mock download failure
        when(() => mockService.downloadUpdate(any(), any())).thenThrow(
          UpdateDownloadException(
            'Invalid URL',
            type: UpdateDownloadErrorType.unknown,
          ),
        );

        await container.read(updateProvider.notifier).startDownload();

        final state = container.read(updateProvider);
        expect(state.updateInfo, isNull);
        expect(state.downloadStatus, UpdateDownloadStatus.idle);
        expect(state.hasUpdate, false);
      },
    );
  });
}
