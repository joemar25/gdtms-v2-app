import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
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
    const testInfo = UpdateInfo(
      latestVersion: '2.0.0',
      minimumVersion: '1.0.0',
      releaseNotes: 'New features',
      isMandatory: false,
    );

    test('initial state has no update', () {
      final state = container.read(updateProvider);
      expect(state.hasUpdate, false);
      expect(state.showBanner, false);
    });

    test('checkForUpdate updates state with info', () async {
      when(
        () => mockService.checkForUpdate(),
      ).thenAnswer((_) async => testInfo);

      await container.read(updateProvider.notifier).checkForUpdate();

      final state = container.read(updateProvider);
      expect(state.updateInfo, testInfo);
      expect(state.hasUpdate, true);
      expect(state.showBanner, true);
    });

    test('checkForUpdate leaves state unchanged when already up to date', () async {
      when(() => mockService.checkForUpdate()).thenAnswer((_) async => null);

      await container.read(updateProvider.notifier).checkForUpdate();

      final state = container.read(updateProvider);
      expect(state.hasUpdate, false);
    });

    test('dismissBanner hides the banner but keeps the update info', () async {
      when(
        () => mockService.checkForUpdate(),
      ).thenAnswer((_) async => testInfo);
      await container.read(updateProvider.notifier).checkForUpdate();

      container.read(updateProvider.notifier).dismissBanner();

      final state = container.read(updateProvider);
      expect(state.hasUpdate, true);
      expect(state.showBanner, false);
    });

    test('openUpdate delegates to UpdateService.launchStoreListing', () async {
      when(
        () => mockService.launchStoreListing(),
      ).thenAnswer((_) async => true);

      final result = await container.read(updateProvider.notifier).openUpdate();

      expect(result, true);
      verify(() => mockService.launchStoreListing()).called(1);
    });

    test('openUpdate returns false when the store listing cannot be opened', () async {
      when(
        () => mockService.launchStoreListing(),
      ).thenAnswer((_) async => false);

      final result = await container.read(updateProvider.notifier).openUpdate();

      expect(result, false);
    });
  });
}
