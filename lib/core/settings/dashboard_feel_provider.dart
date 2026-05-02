// DOCS: docs/development-standards.md
// DOCS: docs/core/settings.md — update that file when you edit this one.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reactive dashboard feel state — initialized at startup from SharedPreferences.
/// Toggle this provider anywhere; changes reflect immediately across all screens.
class _DashboardFeelNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setValue(bool value) => state = value;
}

/// Global provider for the "New Feel" dashboard layout preference.
///
/// Watch this provider in UI screens to reactively switch layouts when the
/// preference is changed in settings.
final dashboardFeelProvider = NotifierProvider<_DashboardFeelNotifier, bool>(
  _DashboardFeelNotifier.new,
);
