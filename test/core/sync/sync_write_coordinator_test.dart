import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/core/providers/sync_provider.dart';
import 'package:fsi_courier_app/core/sync/sync_write_coordinator.dart';

class _RecordingSyncManager extends SyncManagerNotifier {
  final List<String> reasons = [];
  final List<bool> awaitIdleFlags = [];

  @override
  SyncState build() => const SyncState.initial();

  @override
  Future<void> requestFlush({
    String reason = 'unspecified',
    bool awaitIdle = false,
  }) async {
    reasons.add(reason);
    awaitIdleFlags.add(awaitIdle);
  }
}

void main() {
  group('SyncWriteCoordinator', () {
    test(
      'Given online device, when completeWrite kickQueue true, then requestFlush is called',
      () async {
        final sync = _RecordingSyncManager();
        final container = ProviderContainer(
          overrides: [
            isOnlineProvider.overrideWithValue(true),
            syncManagerProvider.overrideWith(() => sync),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(syncWriteCoordinatorProvider)
            .completeWrite(
              reason: 'unit_online',
              awaitIdle: true,
              refreshDeliveries: true,
            );

        expect(sync.reasons, ['unit_online']);
        expect(sync.awaitIdleFlags, [true]);
        // A3: refresh is debounced (~80ms).
        await Future<void>.delayed(const Duration(milliseconds: 120));
        expect(container.read(deliveryRefreshProvider), 1);
      },
    );

    test(
      'Given offline device, when completeWrite kickQueue true, then requestFlush is skipped',
      () async {
        final sync = _RecordingSyncManager();
        final container = ProviderContainer(
          overrides: [
            isOnlineProvider.overrideWithValue(false),
            syncManagerProvider.overrideWith(() => sync),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(syncWriteCoordinatorProvider)
            .completeWrite(
              reason: 'unit_offline',
              kickQueue: true,
              refreshDeliveries: true,
            );

        expect(sync.reasons, isEmpty);
        await Future<void>.delayed(const Duration(milliseconds: 120));
        expect(container.read(deliveryRefreshProvider), 1);
      },
    );

    test(
      'Given kickQueue false, when completeWrite, then only refresh runs',
      () async {
        final sync = _RecordingSyncManager();
        final container = ProviderContainer(
          overrides: [
            isOnlineProvider.overrideWithValue(true),
            syncManagerProvider.overrideWith(() => sync),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(syncWriteCoordinatorProvider)
            .completeWrite(
              reason: 'unit_refresh_only',
              kickQueue: false,
              refreshDeliveries: true,
              barcodes: {'BC1'},
            );

        expect(sync.reasons, isEmpty);
        await Future<void>.delayed(const Duration(milliseconds: 120));
        expect(container.read(deliveryRefreshProvider), 1);
      },
    );

    test(
      'Given rapid completeWrite refresh, when debounced, then one generation bump',
      () async {
        final sync = _RecordingSyncManager();
        final container = ProviderContainer(
          overrides: [
            isOnlineProvider.overrideWithValue(false),
            syncManagerProvider.overrideWith(() => sync),
          ],
        );
        addTearDown(container.dispose);

        final coord = container.read(syncWriteCoordinatorProvider);
        await coord.completeWrite(
          reason: 'a',
          kickQueue: false,
          barcodes: {'A'},
        );
        await coord.completeWrite(
          reason: 'b',
          kickQueue: false,
          barcodes: {'B'},
        );
        await Future<void>.delayed(const Duration(milliseconds: 120));
        expect(container.read(deliveryRefreshProvider), 1);
      },
    );
  });
}
