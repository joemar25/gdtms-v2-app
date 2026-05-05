// DOCS: docs/development-standards.md
// DOCS: docs/core/providers.md — update that file when you edit this one.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import 'package:fsi_courier_app/models/update_info.dart';
import 'package:fsi_courier_app/services/update_service.dart';

// ── State ──────────────────────────────────────────────────────────────────────

enum UpdateDownloadStatus { idle, downloading, completed, error }

class UpdateState {
  const UpdateState({
    this.updateInfo,
    this.isDismissed = false,
    this.downloadStatus = UpdateDownloadStatus.idle,
    this.downloadProgress = 0.0,
    this.downloadedFilePath,
    this.errorMessage,
  });

  final UpdateInfo? updateInfo;

  /// Banner hidden for this session (resets on next app launch).
  final bool isDismissed;

  final UpdateDownloadStatus downloadStatus;

  /// Download progress in [0, 1].
  final double downloadProgress;

  /// Local path of the downloaded APK, available after [downloadStatus] is
  /// [UpdateDownloadStatus.completed].
  final String? downloadedFilePath;

  /// Non-null when [downloadStatus] is [UpdateDownloadStatus.error].
  final String? errorMessage;

  bool get hasUpdate => updateInfo != null;
  bool get isDownloading => downloadStatus == UpdateDownloadStatus.downloading;
  bool get isCompleted => downloadStatus == UpdateDownloadStatus.completed;
  bool get hasError => downloadStatus == UpdateDownloadStatus.error;

  /// True when the banner should be visible (update available and not dismissed
  /// and not yet downloaded/installing).
  bool get showBanner =>
      hasUpdate &&
      !isDismissed &&
      downloadStatus != UpdateDownloadStatus.completed;

  UpdateState copyWith({
    UpdateInfo? updateInfo,
    bool? isDismissed,
    UpdateDownloadStatus? downloadStatus,
    double? downloadProgress,
    String? downloadedFilePath,
    String? errorMessage,
    bool clearError = false,
    bool clearFilePath = false,
    bool clearUpdateInfo = false,
  }) {
    return UpdateState(
      updateInfo: clearUpdateInfo ? null : (updateInfo ?? this.updateInfo),
      isDismissed: isDismissed ?? this.isDismissed,
      downloadStatus: downloadStatus ?? this.downloadStatus,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadedFilePath: clearFilePath
          ? null
          : (downloadedFilePath ?? this.downloadedFilePath),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
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

  Future<void> startDownload() async {
    final info = state.updateInfo;
    if (info == null) return;

    state = state.copyWith(
      downloadStatus: UpdateDownloadStatus.downloading,
      downloadProgress: 0.0,
      clearError: true,
      clearFilePath: true,
    );

    try {
      final filePath = await _service.downloadUpdate(info.downloadUrl, (p) {
        state = state.copyWith(
          downloadStatus: UpdateDownloadStatus.downloading,
          downloadProgress: p,
        );
      });

      if (info.checksumSha256.isNotEmpty) {
        await _service.verifyChecksum(filePath, info.checksumSha256);
      }

      state = state.copyWith(
        downloadStatus: UpdateDownloadStatus.completed,
        downloadProgress: 1.0,
        downloadedFilePath: filePath,
      );
    } catch (e) {
      // If download fails (invalid URL, 404, etc), clear the update info
      // to avoid stuck error states for invalid links, as requested.
      state = state.copyWith(
        clearUpdateInfo: true,
        downloadStatus: UpdateDownloadStatus.idle,
        clearError: true,
        clearFilePath: true,
      );
    }
  }

  Future<OpenResult?> installUpdate() async {
    final path = state.downloadedFilePath;
    if (path == null) return null;
    return _service.installUpdate(path);
  }

  void resetDownload() {
    state = state.copyWith(
      downloadStatus: UpdateDownloadStatus.idle,
      downloadProgress: 0.0,
      clearError: true,
      clearFilePath: true,
    );
  }
}

// ── Provider ───────────────────────────────────────────────────────────────────

final updateProvider = NotifierProvider<UpdateNotifier, UpdateState>(
  UpdateNotifier.new,
);
