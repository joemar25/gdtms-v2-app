import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reactive compact mode state — initialized at startup from SharedPreferences.
/// Toggle this provider anywhere; changes reflect immediately across all screens.
final compactModeProvider = StateProvider<bool>((ref) => false);
