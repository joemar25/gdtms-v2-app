import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';

void main() {
  group('DeliveryRefreshNotifier (A3)', () {
    test('rapid invalidate collapses to one generation bump', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final n = container.read(deliveryRefreshProvider.notifier);
      n.invalidate(barcodes: {'A'});
      n.invalidate(barcodes: {'B'});
      n.increment();
      expect(container.read(deliveryRefreshProvider), 0);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(container.read(deliveryRefreshProvider), 1);
    });

    test('invalidate records barcode scope for last refresh', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(deliveryRefreshProvider.notifier)
          .invalidate(barcodes: {'BC99', 'BC100'});
      await Future<void>.delayed(const Duration(milliseconds: 120));

      final scope = container.read(lastDeliveryRefreshBarcodesProvider);
      expect(scope, containsAll(['BC99', 'BC100']));
    });

    test('full invalidate clears scope to null', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final n = container.read(deliveryRefreshProvider.notifier);
      n.invalidate(barcodes: {'X'});
      n.invalidate(); // full
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(container.read(lastDeliveryRefreshBarcodesProvider), isNull);
      expect(container.read(deliveryRefreshProvider), 1);
    });

    test('incrementNow bumps immediately without waiting debounce', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(deliveryRefreshProvider.notifier).incrementNow();
      expect(container.read(deliveryRefreshProvider), 1);
    });
  });
}
