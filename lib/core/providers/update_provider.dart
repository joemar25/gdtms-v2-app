// DOCS: docs/development-standards.md
// DOCS: docs/core/providers.md — update that file when you edit this one.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fsi_courier_app/models/update_info.dart';
import 'package:fsi_courier_app/services/update_service.dart';

// ── State ──────────────────────────────────────────────────────────────────────

class UpdateState {
  const UpdateState({this.updateInfo, this.isDismissed = false});

  final UpdateInfo? updateInfo;

  /// Banner hidden for this session (resets on next app launch).
  final bool isDismissed;

  bool get hasUpdate => updateInfo != null;

  /// True when the banner should be visible (update available and not dismissed).
  bool get showBanner => hasUpdate && !isDismissed;

  UpdateState copyWith({
    UpdateInfo? updateInfo,
    bool? isDismissed,
    bool clearUpdateInfo = false,
  }) {
    return UpdateState(
      updateInfo: clearUpdateInfo ? null : (updateInfo ?? this.updateInfo),
      isDismissed: isDismissed ?? this.isDismissed,
    );
  }
}

// ── Provider ───────────────────────────────────────────────────────────────────

final updateServiceProvider = Provider((ref) => UpdateService.instance);

// ── Notifier ───────────────────────────────────────────────────────────────────

class UpdateNotifier extends Notifier<UpdateState> {
  UpdateService get _service => ref.read(updateServiceProvider);

  @override
  UpdateState build() => const UpdateState();

  /// Called once on app startup (after a short delay).
  Future<void> checkForUpdate() async {
    final info = await _service.checkForUpdate();
    if (info != null) {
      state = state.copyWith(updateInfo: info);
    }
  }

  void dismissBanner() {
    state = state.copyWith(isDismissed: true);
  }

  /// Opens the platform app store listing for this app.
  Future<bool> openUpdate() => _service.launchStoreListing();
}

// ── Provider ───────────────────────────────────────────────────────────────────

final updateProvider = NotifierProvider<UpdateNotifier, UpdateState>(
  UpdateNotifier.new,
);
