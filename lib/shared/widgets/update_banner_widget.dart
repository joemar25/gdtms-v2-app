// DOCS: docs/development-standards.md

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/core/providers/update_provider.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/shared/router/app_router.dart';
import 'package:fsi_courier_app/shared/router/router_keys.dart';

// ─── Routes on which the banner must never appear ──────────────────────────
const _kBannerHiddenRoutes = {
  '/profile',
  '/splash',
  '/reset-password',
  '/location-required',
  '/permissions-required',
  '/initial-sync',
};

/// A root OverlayEntry that displays an update banner at the bottom of the
/// screen when a new version is available.  It is route-aware and hides itself
/// on the profile screen (where the full update UI lives).
///
/// Usage — insert once into the root overlay alongside the sync pill:
/// ```dart
/// OverlayEntry(builder: (_) => const RepaintBoundary(child: UpdateBannerOverlay()))
/// ```
class UpdateBannerOverlay extends ConsumerWidget {
  const UpdateBannerOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(updateProvider);

    if (!updateState.showBanner) return const SizedBox.shrink();

    final router = ref.watch(appRouterProvider);

    return ListenableBuilder(
      listenable: router.routeInformationProvider,
      builder: (context, _) {
        final path = router.routeInformationProvider.value.uri.path;
        if (_kBannerHiddenRoutes.any((r) => path.startsWith(r))) {
          return const SizedBox.shrink();
        }
        return _UpdateBannerContent(updateState: updateState);
      },
    );
  }
}

// ─── Banner content widget ─────────────────────────────────────────────────

class _UpdateBannerContent extends ConsumerWidget {
  const _UpdateBannerContent({required this.updateState});

  final UpdateState updateState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = updateState.updateInfo!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).padding.bottom;

    final bgColor = isDark ? const Color(0xFF1C1409) : DSColors.warningSurface;
    final borderColor = isDark
        ? DSColors.warningDark.withValues(alpha: 0.4)
        : DSColors.warning.withValues(alpha: 0.5);
    final iconColor = isDark ? DSColors.warningDark : DSColors.warning;
    final labelColor = isDark
        ? DSColors.labelPrimaryDark
        : DSColors.labelPrimary;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          DSSpacing.md,
          0,
          DSSpacing.md,
          // Sit above the bottom nav bar (~80 px) + system bottom padding.
          80 + bottom + DSSpacing.sm,
        ),
        child: GestureDetector(
          onTap: () {
            rootNavigatorKey.currentContext?.go('/update');
          },
          child:
              Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: DSStyles.circularRadius,
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: DSColors.warning.withValues(alpha: 0.18),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.system_update_alt_rounded,
                          size: DSIconSize.sm,
                          color: iconColor,
                        ),
                        DSSpacing.wSm,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                info.isMandatory
                                    ? 'Required Update'
                                    : 'Update Available',
                                style: DSTypography.label(color: iconColor)
                                    .copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: DSTypography.sizeXs,
                                    ),
                              ),
                              Text(
                                'v${info.latestVersion} is ready to install',
                                style: DSTypography.caption(
                                  color: labelColor,
                                ).copyWith(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        if (!info.isMandatory) ...[
                          DSSpacing.wSm,
                          GestureDetector(
                            onTap: () => ref
                                .read(updateProvider.notifier)
                                .dismissBanner(),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: iconColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: iconColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .shimmer(
                    duration: const Duration(milliseconds: 1800),
                    color: DSColors.warning.withValues(alpha: 0.12),
                  ),
        ),
      ),
    );
  }
}
