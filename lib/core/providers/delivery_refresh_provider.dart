import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Incrementing counter used to signal that delivery data should be refreshed.
/// Any screen that displays delivery data watches this provider,
/// and increments it (via ref.read(deliveryRefreshProvider.notifier).state++)
/// after a successful status update or dispatch acceptance.
final deliveryRefreshProvider = StateProvider<int>((ref) => 0);
