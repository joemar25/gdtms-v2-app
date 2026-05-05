import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fsi_courier_app/core/providers/update_provider.dart';
import 'package:fsi_courier_app/core/services/app_version_service.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/features/permissions/providers/permissions_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';

class AppUpdateCard extends ConsumerStatefulWidget {
  const AppUpdateCard({super.key, required this.isDark});
  final bool isDark;

  @override
  ConsumerState<AppUpdateCard> createState() => _AppUpdateCardState();
}

class _AppUpdateCardState extends ConsumerState<AppUpdateCard> {
  bool _releaseNotesExpanded = false;

  Future<void> _handleDownload() async {
    await ref.read(updateProvider.notifier).startDownload();
    if (mounted && ref.read(updateProvider).isCompleted) {
      await _handleInstall();
    }
  }

  Future<void> _handleInstall() async {
    // Check install-packages permission before proceeding.
    // extraPermissionsProvider refreshes on app resume, so this is current.
    final installGranted = ref
        .read(extraPermissionsProvider)
        .installStatus
        .isGranted;

    if (!installGranted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: const Text(
            'Allow "Install unknown apps" for FSI Courier in Settings first.',
          ),
          backgroundColor: DSColors.warning,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          margin: EdgeInsets.fromLTRB(
            DSSpacing.sm,
            0,
            DSSpacing.sm,
            DSSpacing.massive,
          ),
          action: SnackBarAction(
            label: 'Settings',
            textColor: DSColors.white,
            onPressed: () =>
                ref.read(extraPermissionsProvider.notifier).openSettings(),
          ),
        ),
      );
      return;
    }

    final result = await ref.read(updateProvider.notifier).installUpdate();
    if (!mounted) return;
    if (result == null) return;

    if (result.type == ResultType.done) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: const Text('Installing update…'),
          backgroundColor: DSColors.success,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(
            DSSpacing.sm,
            0,
            DSSpacing.sm,
            DSSpacing.massive,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final updateState = ref.watch(updateProvider);
    final info = updateState.updateInfo;
    final isDark = widget.isDark;

    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: DSSpacing.md,
              vertical: DSSpacing.sm + 2,
            ),
            child: Row(
              children: [
                Container(
                  width: DSIconSize.heroSm,
                  height: DSIconSize.heroSm,
                  decoration: BoxDecoration(
                    color: info != null
                        ? DSColors.warning.withValues(alpha: 0.12)
                        : DSColors.primary.withValues(alpha: 0.12),
                    borderRadius: DSStyles.cardRadius,
                  ),
                  child: Icon(
                    info != null
                        ? Icons.system_update_alt_rounded
                        : Icons.check_circle_outline_rounded,
                    color: info != null ? DSColors.warning : DSColors.primary,
                    size: DSIconSize.md,
                  ),
                ),
                DSSpacing.wMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info != null
                            ? 'Update Available'
                            : 'App is up to date ✓',
                        style: DSTypography.body(
                          color: isDark
                              ? DSColors.labelPrimaryDark
                              : DSColors.labelPrimary,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      DSSpacing.hXs,
                      Text(
                        info != null
                            ? 'Current: v${AppVersionService.version}  →  '
                                  'Latest: v${info.latestVersion}'
                            : 'v${AppVersionService.version}',
                        style: DSTypography.caption(
                          color: isDark
                              ? DSColors.labelSecondaryDark
                              : DSColors.labelSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (info != null) ...[
                  DSSpacing.wSm,
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DSSpacing.sm,
                      vertical: DSSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: info.isMandatory
                          ? DSColors.error.withValues(alpha: 0.12)
                          : DSColors.warning.withValues(alpha: 0.12),
                      borderRadius: DSStyles.circularRadius,
                    ),
                    child: Text(
                      info.isMandatory ? 'Required' : 'Optional',
                      style:
                          DSTypography.label(
                            color: info.isMandatory
                                ? DSColors.error
                                : DSColors.warning,
                          ).copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: DSTypography.sizeXs,
                          ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (info != null) ...[
            Divider(
              height: 1,
              color: isDark ? DSColors.separatorDark : DSColors.separatorLight,
            ),

            // ── Details row ────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: DSSpacing.md,
                vertical: DSSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_zip_outlined,
                    size: DSIconSize.xs,
                    color: isDark
                        ? DSColors.labelTertiaryDark
                        : DSColors.labelTertiary,
                  ),
                  DSSpacing.wXs,
                  Text(
                    '${info.fileSizeMb.toStringAsFixed(1)} MB',
                    style: DSTypography.caption(
                      color: isDark
                          ? DSColors.labelSecondaryDark
                          : DSColors.labelSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // ── Release notes (collapsible) ────────────────────────────────
            if (info.releaseNotes.isNotEmpty) ...[
              GestureDetector(
                onTap: () => setState(
                  () => _releaseNotesExpanded = !_releaseNotesExpanded,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: DSSpacing.md,
                    vertical: DSSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notes_rounded,
                        size: DSIconSize.xs,
                        color: isDark
                            ? DSColors.labelTertiaryDark
                            : DSColors.labelTertiary,
                      ),
                      DSSpacing.wXs,
                      Text(
                        'Release notes',
                        style: DSTypography.caption(
                          color: isDark
                              ? DSColors.labelSecondaryDark
                              : DSColors.labelSecondary,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        _releaseNotesExpanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: DSIconSize.xs,
                        color: isDark
                            ? DSColors.labelTertiaryDark
                            : DSColors.labelTertiary,
                      ),
                    ],
                  ),
                ),
              ),
              if (_releaseNotesExpanded)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    DSSpacing.md,
                    0,
                    DSSpacing.md,
                    DSSpacing.sm,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(DSSpacing.sm),
                    decoration: BoxDecoration(
                      color: isDark
                          ? DSColors.secondarySurfaceDark
                          : DSColors.secondarySurfaceLight,
                      borderRadius: DSStyles.cardRadius,
                    ),
                    child: Text(
                      info.releaseNotes,
                      style: DSTypography.caption(
                        color: isDark
                            ? DSColors.labelSecondaryDark
                            : DSColors.labelSecondary,
                      ).copyWith(height: 1.5),
                    ),
                  ),
                ),
            ],

            Divider(
              height: 1,
              color: isDark ? DSColors.separatorDark : DSColors.separatorLight,
            ),

            // ── Download / progress / install controls ─────────────────────
            Padding(
              padding: EdgeInsets.all(DSSpacing.md),
              child: _UpdateActionArea(
                updateState: updateState,
                isDark: isDark,
                onDownload: _handleDownload,
                onInstall: _handleInstall,
                onCancel: () =>
                    ref.read(updateProvider.notifier).cancelDownload(),
                onRetry: () =>
                    ref.read(updateProvider.notifier).resetDownload(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UpdateActionArea extends StatelessWidget {
  const _UpdateActionArea({
    required this.updateState,
    required this.isDark,
    required this.onDownload,
    required this.onInstall,
    required this.onRetry,
    required this.onCancel,
  });

  final UpdateState updateState;
  final bool isDark;
  final VoidCallback onDownload;
  final VoidCallback onInstall;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    if (updateState.hasError) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            updateState.errorMessage ?? 'Download failed.',
            style: DSTypography.caption(color: DSColors.error),
            textAlign: TextAlign.center,
          ),
          DSSpacing.hSm,
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: DSIconSize.sm),
            label: const Text('Retry'),
            style: OutlinedButton.styleFrom(
              foregroundColor: DSColors.primary,
              side: const BorderSide(color: DSColors.primary),
            ),
          ),
        ],
      );
    }

    if (updateState.isDownloading) {
      final pct = (updateState.downloadProgress * 100).toStringAsFixed(0);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Downloading… $pct%',
                style: DSTypography.caption(
                  color: isDark
                      ? DSColors.labelSecondaryDark
                      : DSColors.labelSecondary,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                '$pct%',
                style: DSTypography.label(color: DSColors.primary).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: DSTypography.sizeXs,
                ),
              ),
            ],
          ),
          DSSpacing.hSm,
          ClipRRect(
            borderRadius: DSStyles.circularRadius,
            child: LinearProgressIndicator(
              value: updateState.downloadProgress,
              backgroundColor: isDark
                  ? DSColors.separatorDark
                  : DSColors.separatorLight,
              color: DSColors.primary,
              minHeight: 6,
            ),
          ),
          DSSpacing.hSm,
          TextButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded, size: DSIconSize.sm),
            label: const Text('Cancel Download'),
            style: TextButton.styleFrom(
              foregroundColor: DSColors.error,
              minimumSize: const Size.fromHeight(40),
            ),
          ),
        ],
      );
    }

    if (updateState.isCompleted) {
      return ElevatedButton.icon(
        onPressed: onInstall,
        icon: const Icon(Icons.install_mobile_rounded, size: DSIconSize.sm),
        label: const Text('Install Now'),
        style: ElevatedButton.styleFrom(
          backgroundColor: DSColors.primary,
          foregroundColor: DSColors.white,
          minimumSize: const Size(double.infinity, 44),
          shape: RoundedRectangleBorder(borderRadius: DSStyles.cardRadius),
        ),
      );
    }

    // Idle — show download button.
    return ElevatedButton.icon(
      onPressed: onDownload,
      icon: const Icon(Icons.download_rounded, size: DSIconSize.sm),
      label: const Text('Download & Install Update'),
      style: ElevatedButton.styleFrom(
        backgroundColor: DSColors.warning,
        foregroundColor: DSColors.white,
        minimumSize: const Size(double.infinity, 44),
        shape: RoundedRectangleBorder(borderRadius: DSStyles.cardRadius),
      ),
    );
  }
}
