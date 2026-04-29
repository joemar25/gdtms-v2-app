// DOCS: docs/development-standards.md
// DOCS: docs/features/location.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:fsi_courier_app/features/permissions/providers/location_provider.dart';
import 'package:fsi_courier_app/features/permissions/providers/permissions_provider.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

class PermissionsRequiredScreen extends ConsumerWidget {
  const PermissionsRequiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationState = ref.watch(locationProvider);
    final locationNotifier = ref.read(locationProvider.notifier);
    final permsState = ref.watch(extraPermissionsProvider);
    final permsNotifier = ref.read(extraPermissionsProvider.notifier);

    final locationGranted = locationState.isReady;
    final cameraGranted = permsState.cameraStatus.isGranted;
    final notifGranted = permsState.notificationStatus.isGranted;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: DSSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.security_rounded,
                size: DSIconSize.xl,
                color: DSColors.error,
              ).dsHeroEntry(),
              DSSpacing.hLg,
              Text(
                'permissions.title'.tr(),
                textAlign: TextAlign.center,
                style: DSTypography.heading(
                  fontSize: DSTypography.sizeXl,
                  fontWeight: FontWeight.w700,
                ),
              ).dsFadeEntry(
                delay: DSAnimations.stagger(
                  1,
                  step: DSAnimations.staggerNormal,
                ),
              ),
              DSSpacing.hSm,
              Text(
                'permissions.subtitle'.tr(),
                textAlign: TextAlign.center,
                style: DSTypography.body(
                  color: DSColors.labelSecondary,
                ).copyWith(height: DSStyles.heightRelaxed),
              ).dsFadeEntry(
                delay: DSAnimations.stagger(
                  2,
                  step: DSAnimations.staggerNormal,
                ),
              ),
              DSSpacing.hXl,

              // ── Location ────────────────────────────────────────────────────
              _PermissionCard(
                icon: locationGranted
                    ? Icons.location_on_rounded
                    : Icons.location_off_rounded,
                label: 'permissions.location.label'.tr(),
                description: locationGranted
                    ? 'permissions.status_granted'.tr()
                    : _locationDescription(locationState.status),
                granted: locationGranted,
                buttonLabel: locationGranted
                    ? 'permissions.button_enabled'.tr()
                    : _locationButtonLabel(locationState.status),
                onTap: locationGranted
                    ? null
                    : () => _handleLocation(
                        locationState.status,
                        locationNotifier,
                      ),
              ).dsCardEntry(
                delay: DSAnimations.stagger(
                  3,
                  step: DSAnimations.staggerNormal,
                ),
              ),
              DSSpacing.hMd,

              // ── Camera ──────────────────────────────────────────────────────
              _PermissionCard(
                icon: cameraGranted
                    ? Icons.camera_alt_rounded
                    : Icons.no_photography_rounded,
                label: 'permissions.camera.label'.tr(),
                description: cameraGranted
                    ? 'permissions.status_granted'.tr()
                    : permsState.cameraStatus.isPermanentlyDenied
                    ? 'permissions.status_permanently_denied'.tr()
                    : 'permissions.status_denied'.tr(
                        namedArgs: {'reason': 'permissions.camera.reason'.tr()},
                      ),
                granted: cameraGranted,
                buttonLabel: cameraGranted
                    ? 'permissions.button_enabled'.tr()
                    : permsState.cameraStatus.isPermanentlyDenied
                    ? 'permissions.button_settings'.tr()
                    : 'permissions.button_grant'.tr(),
                onTap: cameraGranted
                    ? null
                    : permsState.cameraStatus.isPermanentlyDenied
                    ? () => permsNotifier.openSettings()
                    : () => permsNotifier.requestCamera(),
              ).dsCardEntry(
                delay: DSAnimations.stagger(
                  4,
                  step: DSAnimations.staggerNormal,
                ),
              ),
              DSSpacing.hMd,

              // ── Notifications ───────────────────────────────────────────────
              _PermissionCard(
                icon: notifGranted
                    ? Icons.notifications_rounded
                    : Icons.notifications_off_rounded,
                label: 'permissions.notifications.label'.tr(),
                description: notifGranted
                    ? 'permissions.status_granted'.tr()
                    : permsState.notificationStatus.isPermanentlyDenied
                    ? 'permissions.status_permanently_denied'.tr()
                    : 'permissions.status_denied'.tr(
                        namedArgs: {
                          'reason': 'permissions.notifications.reason'.tr(),
                        },
                      ),
                granted: notifGranted,
                buttonLabel: notifGranted
                    ? 'permissions.button_enabled'.tr()
                    : permsState.notificationStatus.isPermanentlyDenied
                    ? 'permissions.button_settings'.tr()
                    : 'permissions.button_grant'.tr(),
                onTap: notifGranted
                    ? null
                    : permsState.notificationStatus.isPermanentlyDenied
                    ? () => permsNotifier.openSettings()
                    : () => permsNotifier.requestNotification(),
              ).dsCardEntry(
                delay: DSAnimations.stagger(
                  5,
                  step: DSAnimations.staggerNormal,
                ),
              ),

              DSSpacing.hXl,
              TextButton(
                onPressed: () {
                  locationNotifier.refresh();
                  permsNotifier.refresh();
                },
                style: TextButton.styleFrom(
                  foregroundColor: DSColors.labelSecondary,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text('permissions.refresh'.tr()),
              ).dsFadeEntry(
                delay: DSAnimations.stagger(
                  6,
                  step: DSAnimations.staggerNormal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _locationDescription(LocationStatus status) {
    return switch (status) {
      LocationStatus.serviceDisabled => 'permissions.location.gps_off'.tr(),
      LocationStatus.permissionPermanentlyDenied =>
        'permissions.status_permanently_denied'.tr(),
      LocationStatus.permissionDenied => 'permissions.status_denied'.tr(
        namedArgs: {'reason': 'permissions.location.reason'.tr()},
      ),
      LocationStatus.determining ||
      LocationStatus.ready => 'common.loading'.tr(),
    };
  }

  String _locationButtonLabel(LocationStatus status) {
    return switch (status) {
      LocationStatus.serviceDisabled =>
        'permissions.location.settings_label'.tr(),
      LocationStatus.permissionPermanentlyDenied =>
        'permissions.button_settings'.tr(),
      LocationStatus.permissionDenied => 'permissions.button_grant'.tr(),
      LocationStatus.determining ||
      LocationStatus.ready => 'common.loading'.tr(),
    };
  }

  void _handleLocation(
    LocationStatus status,
    LocationProviderNotifier notifier,
  ) {
    if (status == LocationStatus.permissionDenied) {
      notifier.requestPermission();
    } else {
      notifier.openSettings();
    }
  }
}

// ── Permission Card ────────────────────────────────────────────────────────────

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.granted,
    required this.buttonLabel,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final bool granted;
  final String buttonLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardColor = isDark ? DSColors.cardDark : DSColors.cardLight;
    final iconColor = granted ? DSColors.primary : DSColors.error;
    final statusColor = granted ? DSColors.primary : DSColors.labelSecondary;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: DSStyles.cardRadius,
        border: Border.all(
          color: granted
              ? DSColors.primary.withValues(alpha: DSStyles.alphaMuted)
              : DSColors.separatorLight.withValues(alpha: DSStyles.alphaMuted),
          width: DSStyles.borderWidth,
        ),
      ),
      padding: EdgeInsets.all(DSSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: DSIconSize.heroSm,
                height: DSIconSize.heroSm,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: DSStyles.alphaSubtle),
                  borderRadius: DSStyles.cardRadius,
                ),
                child: Icon(icon, color: iconColor, size: DSIconSize.lg),
              ),
              DSSpacing.wMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: DSTypography.subTitle(
                        fontSize: DSTypography.sizeMd,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    DSSpacing.hXs,
                    Text(
                      description,
                      style: DSTypography.caption(
                        color: statusColor,
                      ).copyWith(height: DSStyles.heightNormal),
                    ),
                  ],
                ),
              ),
              if (granted) ...[
                DSSpacing.wSm,
                Icon(
                  Icons.check_circle_rounded,
                  color: DSColors.primary,
                  size: DSIconSize.xl,
                ),
              ],
            ],
          ),
          if (!granted) ...[
            DSSpacing.hMd,
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  foregroundColor: DSColors.error,
                  backgroundColor: DSColors.error.withValues(alpha: 0.1),
                  padding: EdgeInsets.symmetric(
                    horizontal: DSSpacing.md,
                    vertical: DSSpacing.sm,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: DSStyles.pillRadius,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  buttonLabel,
                  style: DSTypography.button(
                    color: DSColors.error,
                    fontSize: DSTypography.sizeSm,
                    fontWeight: FontWeight.w700,
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
