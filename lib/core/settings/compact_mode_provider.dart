// DOCS: docs/development-standards.md
// DOCS: docs/core/settings.md — update that file when you edit this one.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reactive compact mode state — initialized at startup from SharedPreferences.
/// Toggle this provider anywhere; changes reflect immediately across all screens.
class _CompactModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setValue(bool value) => state = value;
}

final compactModeProvider = NotifierProvider<_CompactModeNotifier, bool>(
  _CompactModeNotifier.new,
);
