// DOCS: docs/development-standards.md
// DOCS: docs/features/location.md — update that file when you edit this one.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/features/permissions/providers/location_provider.dart';
import 'package:fsi_courier_app/features/permissions/providers/permissions_provider.dart';

/// Gate before dashboard — location, camera, notifications.
///
/// Visual language matches onboarding gates (quiet backdrop + glass cards),
/// not a plain white form.
class PermissionsRequiredScreen extends ConsumerWidget {
  const PermissionsRequiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationState = ref.watch(locationProvider);
    final locationNotifier = ref.read(locationProvider.notifier);
    final permsState = ref.watch(extraPermissionsProvider);
    final permsNotifier = ref.read(extraPermissionsProvider.notifier);

    final locationGranted = locationState.isReady;
    final cameraGranted = permsState.cameraStatus == PermissionStatus.granted;
    final notifGranted =
        permsState.notificationStatus == PermissionStatus.granted;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark
        ? DSColors.labelPrimaryDark
        : DSColors.labelPrimary;
    final muted = isDark
        ? DSColors.labelSecondaryDark
        : DSColors.labelSecondary;

    return DSGateShell(
      showThemeToggle: true,
      backdrop: DsBackdrop.gate,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: DSColors.primary.withValues(
                      alpha: DSStyles.alphaSubtle,
                    ),
                    borderRadius: BorderRadius.circular(DSStyles.radius2XL),
                    border: Border.all(
                      color: DSColors.primary.withValues(
                        alpha: DSStyles.alphaMuted,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: DSColors.primary.withValues(alpha: 0.16),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shield_moon_rounded,
                    size: DSIconSize.xl,
                    color: DSColors.primary,
                  ),
                ),
              )
              .animate()
              .fadeIn(duration: DSAnimations.dNormal)
              .scale(
                begin: const Offset(0.85, 0.85),
                end: const Offset(1, 1),
                duration: DSAnimations.dHero,
                curve: Curves.easeOutBack,
              ),

          DSSpacing.hLg,

          Text(
                'permissions.title'.tr(),
                textAlign: TextAlign.center,
                style: DSTypography.heading(color: titleColor).copyWith(
                  fontSize: DSTypography.sizeXl,
                  fontWeight: FontWeight.w700,
                ),
              )
              .animate()
              .fadeIn(delay: 80.ms, duration: DSAnimations.dNormal)
              .slideY(begin: 0.1, end: 0, delay: 80.ms),

          DSSpacing.hSm,

          Text(
            'permissions.subtitle'.tr(),
            textAlign: TextAlign.center,
            style: DSTypography.body(color: muted).copyWith(
              height: DSStyles.heightRelaxed,
              fontSize: DSTypography.sizeMd,
            ),
          ).animate().fadeIn(delay: 120.ms, duration: DSAnimations.dNormal),

          DSSpacing.hXl,

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
                : () => _handleLocation(locationState.status, locationNotifier),
          ).dsCardEntry(
            delay: DSAnimations.stagger(1, step: DSAnimations.staggerCoarse),
          ),

          DSSpacing.hFormField,

          _PermissionCard(
            icon: cameraGranted
                ? Icons.camera_alt_rounded
                : Icons.no_photography_rounded,
            label: 'permissions.camera.label'.tr(),
            description: cameraGranted
                ? 'permissions.status_granted'.tr()
                : permsState.cameraStatus == PermissionStatus.permanentlyDenied
                ? 'permissions.status_permanently_denied'.tr()
                : 'permissions.status_denied'.tr(
                    namedArgs: {'reason': 'permissions.camera.reason'.tr()},
                  ),
            granted: cameraGranted,
            buttonLabel: cameraGranted
                ? 'permissions.button_enabled'.tr()
                : permsState.cameraStatus == PermissionStatus.permanentlyDenied
                ? 'permissions.button_settings'.tr()
                : 'permissions.button_grant'.tr(),
            onTap: cameraGranted
                ? null
                : permsState.cameraStatus == PermissionStatus.permanentlyDenied
                ? () => permsNotifier.openSettings()
                : () => permsNotifier.requestCamera(),
          ).dsCardEntry(
            delay: DSAnimations.stagger(2, step: DSAnimations.staggerCoarse),
          ),

          DSSpacing.hFormField,

          _PermissionCard(
            icon: notifGranted
                ? Icons.notifications_rounded
                : Icons.notifications_off_rounded,
            label: 'permissions.notifications.label'.tr(),
            description: notifGranted
                ? 'permissions.status_granted'.tr()
                : permsState.notificationStatus ==
                      PermissionStatus.permanentlyDenied
                ? 'permissions.status_permanently_denied'.tr()
                : 'permissions.status_denied'.tr(
                    namedArgs: {
                      'reason': 'permissions.notifications.reason'.tr(),
                    },
                  ),
            granted: notifGranted,
            buttonLabel: notifGranted
                ? 'permissions.button_enabled'.tr()
                : permsState.notificationStatus ==
                      PermissionStatus.permanentlyDenied
                ? 'permissions.button_settings'.tr()
                : 'permissions.button_grant'.tr(),
            onTap: notifGranted
                ? null
                : permsState.notificationStatus ==
                      PermissionStatus.permanentlyDenied
                ? () => permsNotifier.openSettings()
                : () => permsNotifier.requestNotification(),
          ).dsCardEntry(
            delay: DSAnimations.stagger(3, step: DSAnimations.staggerCoarse),
          ),

          DSSpacing.hLg,

          TextButton(
            onPressed: () {
              locationNotifier.refresh();
              permsNotifier.refresh();
            },
            style: TextButton.styleFrom(
              foregroundColor: muted,
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text('permissions.refresh'.tr()),
          ).animate().fadeIn(
            delay: DSAnimations.stagger(4, step: DSAnimations.staggerCoarse),
            duration: DSAnimations.dFast,
          ),
        ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = granted ? DSColors.success : DSColors.primary;
    final borderColor = granted
        ? DSColors.success.withValues(alpha: 0.35)
        : null;

    return DSGlassCard(
      borderColor: borderColor,
      padding: const EdgeInsets.all(DSSpacing.md),
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
                  borderRadius: BorderRadius.circular(DSStyles.radiusXL),
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
                        color: isDark
                            ? DSColors.labelSecondaryDark
                            : DSColors.labelSecondary,
                      ).copyWith(height: DSStyles.heightNormal),
                    ),
                  ],
                ),
              ),
              if (granted) ...[
                DSSpacing.wSm,
                Icon(
                  Icons.check_circle_rounded,
                  color: DSColors.success,
                  size: DSIconSize.xl,
                ),
              ],
            ],
          ),
          if (!granted) ...[
            DSSpacing.hMd,
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: DSColors.primary,
                  foregroundColor: DSColors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DSStyles.radiusXL),
                  ),
                ),
                child: Text(
                  buttonLabel,
                  style: DSTypography.button(color: DSColors.white).copyWith(
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
