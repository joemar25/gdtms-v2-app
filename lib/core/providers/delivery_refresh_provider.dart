// DOCS: docs/development-standards.md
// DOCS: docs/core/providers.md — update that file when you edit this one.
// DOCS: docs/architecture/system-map.md

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Last barcode set passed to [DeliveryRefreshNotifier.invalidate].
/// `null` means a full refresh was requested (all lists should reload).
///
/// Screens may optionally filter on this; most still reload on generation change.
final lastDeliveryRefreshBarcodesProvider =
    NotifierProvider<_LastRefreshBarcodesNotifier, Set<String>?>(
      _LastRefreshBarcodesNotifier.new,
    );

class _LastRefreshBarcodesNotifier extends Notifier<Set<String>?> {
  @override
  Set<String>? build() => null;

  void setScope(Set<String>? barcodes) => state = barcodes;
}

/// Generation counter: any screen showing delivery data watches this and
/// reloads when it changes.
///
/// **A3:** bumps are debounced (~80ms) so completeWrite + processQueue success
/// in the same tick collapse to one UI rebuild. Use [incrementNow] only when
/// a synchronous bump is required (rare; tests).
class DeliveryRefreshNotifier extends Notifier<int> {
  Timer? _debounce;

  static const _kDebounce = Duration(milliseconds: 80);

  @override
  int build() {
    ref.onDispose(() => _debounce?.cancel());
    return 0;
  }

  /// Full list invalidation (bootstrap, multi-item, or unknown scope).
  void increment() => invalidate();

  /// Prefer after a write that only affects specific barcodes.
  /// Still bumps the generation (lists reload) but records scope for future
  /// selective listeners and collapses storms via debounce.
  void invalidate({Set<String>? barcodes}) {
    final scope = (barcodes == null || barcodes.isEmpty)
        ? null
        : Set<String>.from(barcodes);
    ref.read(lastDeliveryRefreshBarcodesProvider.notifier).setScope(scope);
    _scheduleBump();
  }

  /// Immediate generation bump (no debounce). Prefer [invalidate] in product code.
  void incrementNow() {
    _debounce?.cancel();
    state = state + 1;
  }

  void _scheduleBump() {
    _debounce?.cancel();
    _debounce = Timer(_kDebounce, () {
      state = state + 1;
    });
  }
}

final deliveryRefreshProvider =
    NotifierProvider<DeliveryRefreshNotifier, int>(DeliveryRefreshNotifier.new);

/// Incrementing counter used to signal that wallet data should be refreshed.
/// Incremented after a successful payout request submission so WalletScreen
/// re-fetches even when the widget is kept alive by the shell navigator.
class _WalletRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}

final walletRefreshProvider = NotifierProvider<_WalletRefreshNotifier, int>(
  _WalletRefreshNotifier.new,
);
