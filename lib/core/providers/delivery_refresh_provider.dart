import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Incrementing counter used to signal that delivery data should be refreshed.
/// Any screen that displays delivery data watches this provider,
/// and increments it (via ref.read(deliveryRefreshProvider.notifier).state++)
/// after a successful status update or dispatch acceptance.
final deliveryRefreshProvider = StateProvider<int>((ref) => 0);

/// Incrementing counter used to signal that wallet data should be refreshed.
/// Incremented after a successful payout request submission so WalletScreen
/// re-fetches even when the widget is kept alive by the shell navigator.
final walletRefreshProvider = StateProvider<int>((ref) => 0);
