// DOCS: docs/development-standards.md
// DOCS: docs/core/auth.md — update that file when you edit this one.
// DOCS: docs/architecture/coupling-todo.md

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';

/// A4: read-only combination of the three things almost every feature screen
/// reads together — `ref.read(authProvider).courier?['id']`,
/// `ref.read(isOnlineProvider)`, and (nearby) `ref.read(apiClientProvider)`.
/// Screens that only need courier id / online gate should read this facade
/// instead of composing the individual providers themselves.
///
/// `apiClientProvider` is intentionally NOT part of this facade — that stays
/// a service-layer concern (see A5), not something every button handler
/// should reach for directly.
class CourierSession {
  const CourierSession({
    required this.isAuthenticated,
    required this.courierId,
    required this.courier,
    required this.isOnline,
  });

  final bool isAuthenticated;

  /// Empty string when not authenticated or the courier record has no id.
  final String courierId;

  /// Full courier record (name, phone, courier_code, ...), when authenticated.
  final Map<String, dynamic>? courier;
  final bool isOnline;
}

final courierSessionProvider = Provider<CourierSession>((ref) {
  final auth = ref.watch(authProvider);
  final isOnline = ref.watch(isOnlineProvider);
  return CourierSession(
    isAuthenticated: auth.isAuthenticated,
    courierId: auth.courier?['id']?.toString() ?? '',
    courier: auth.courier,
    isOnline: isOnline,
  );
});
