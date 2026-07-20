import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fsi_courier_app/core/providers/update_provider.dart';
import 'package:fsi_courier_app/core/services/app_version_service.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

class AppUpdateCard extends ConsumerStatefulWidget {
  const AppUpdateCard({super.key, required this.isDark});
  final bool isDark;

  @override
  ConsumerState<AppUpdateCard> createState() => _AppUpdateCardState();
}

class _AppUpdateCardState extends ConsumerState<AppUpdateCard> {
  bool _releaseNotesExpanded = false;
  bool _opening = false;

  Future<void> _handleOpenUpdate() async {
    setState(() => _opening = true);
    final opened = await ref.read(updateProvider.notifier).openUpdate();
    if (!mounted) return;
    setState(() => _opening = false);

    if (!opened) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: const Text('Could not open the store listing.'),
          backgroundColor: DSColors.error,
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
                        ).copyWith(fontWeight: FontWeight.w800),
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
                            fontWeight: FontWeight.w900,
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

            // ── Action ──────────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.all(DSSpacing.md),
              child: ElevatedButton.icon(
                onPressed: _opening ? null : _handleOpenUpdate,
                icon: _opening
                    ? SizedBox(
                        width: DSIconSize.sm,
                        height: DSIconSize.sm,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: DSColors.white,
                        ),
                      )
                    : const Icon(
                        Icons.storefront_rounded,
                        size: DSIconSize.sm,
                      ),
                label: const Text('Update on Play Store'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DSColors.warning,
                  foregroundColor: DSColors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: DSStyles.cardRadius,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
