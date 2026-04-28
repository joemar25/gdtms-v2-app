// DOCS: docs/development-standards.md
// DOCS: docs/core/providers.md — update that file when you edit this one.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Incrementing counter used to signal that delivery data should be refreshed.
/// Any screen that displays delivery data watches this provider,
/// and increments it (via ref.read(deliveryRefreshProvider.notifier).increment())
/// after a successful status update or dispatch acceptance.
class _DeliveryRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}

final deliveryRefreshProvider = NotifierProvider<_DeliveryRefreshNotifier, int>(
  _DeliveryRefreshNotifier.new,
);

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
