import 'package:flutter_test/flutter_test.dart';
import 'package:fsi_courier_app/core/sync/delivery_bootstrap_service.dart';
import 'package:fsi_courier_app/core/sync/sync_upsert_policy.dart';

void main() {
  group('SyncUpsertPolicy.shouldSkipUnchangedChecksum (P5 accuracy)', () {
    test('skips when clean and checksums match', () {
      expect(
        SyncUpsertPolicy.shouldSkipUnchangedChecksum(
          isDirty: false,
          existingChecksum: 'abc123',
          incomingChecksum: 'abc123',
        ),
        isTrue,
      );
    });

    test('does not skip dirty rows even when checksums match (Rule 2 path)', () {
      expect(
        SyncUpsertPolicy.shouldSkipUnchangedChecksum(
          isDirty: true,
          existingChecksum: 'abc123',
          incomingChecksum: 'abc123',
        ),
        isFalse,
      );
    });

    test('does not skip when checksums differ', () {
      expect(
        SyncUpsertPolicy.shouldSkipUnchangedChecksum(
          isDirty: false,
          existingChecksum: 'old',
          incomingChecksum: 'new',
        ),
        isFalse,
      );
    });

    test('does not skip when existing checksum missing', () {
      expect(
        SyncUpsertPolicy.shouldSkipUnchangedChecksum(
          isDirty: false,
          existingChecksum: null,
          incomingChecksum: 'abc',
        ),
        isFalse,
      );
    });

    test('does not skip when incoming checksum missing', () {
      expect(
        SyncUpsertPolicy.shouldSkipUnchangedChecksum(
          isDirty: false,
          existingChecksum: 'abc',
          incomingChecksum: null,
        ),
        isFalse,
      );
    });

    test('trims whitespace before compare', () {
      expect(
        SyncUpsertPolicy.shouldSkipUnchangedChecksum(
          isDirty: false,
          existingChecksum: '  hash  ',
          incomingChecksum: 'hash',
        ),
        isTrue,
      );
    });

    test('empty strings do not skip', () {
      expect(
        SyncUpsertPolicy.shouldSkipUnchangedChecksum(
          isDirty: false,
          existingChecksum: '',
          incomingChecksum: '',
        ),
        isFalse,
      );
    });
  });

  group('DeliverySyncPaging (P1)', () {
    test('remainingPages empty when last_page is 1', () {
      expect(DeliverySyncPaging.remainingPages(1), isEmpty);
      expect(DeliverySyncPaging.remainingPages(0), isEmpty);
    });

    test('remainingPages is 2..N inclusive', () {
      expect(DeliverySyncPaging.remainingPages(5), [2, 3, 4, 5]);
    });

    test('chunkPages respects concurrency of 3', () {
      final pages = DeliverySyncPaging.remainingPages(7); // 2..7 = 6 pages
      final chunks = DeliverySyncPaging.chunkPages(pages, 3);
      expect(chunks, [
        [2, 3, 4],
        [5, 6, 7],
      ]);
    });

    test('chunkPages handles non-divisible remainder', () {
      expect(DeliverySyncPaging.chunkPages([2, 3, 4, 5], 3), [
        [2, 3, 4],
        [5],
      ]);
    });

    test('expectedListCallsForStatus equals last_page', () {
      expect(DeliverySyncPaging.expectedListCallsForStatus(1), 1);
      expect(DeliverySyncPaging.expectedListCallsForStatus(4), 4);
    });
  });

  group('DeliveryBootstrapService P2 constants', () {
    test('per_page is 100–200 for production throughput', () {
      expect(
        DeliveryBootstrapService.kSyncPerPage,
        inInclusiveRange(100, 200),
      );
    });
  });
}
