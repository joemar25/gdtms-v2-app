// DOCS: docs/features/location.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fsi_courier_app/core/providers/location_provider.dart';
import 'package:fsi_courier_app/core/providers/permissions_provider.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

class LocationRequiredScreen extends ConsumerWidget {
  const LocationRequiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationState = ref.watch(locationProvider);
    final locationNotifier = ref.read(locationProvider.notifier);
    final permsState = ref.watch(extraPermissionsProvider);
    final permsNotifier = ref.read(extraPermissionsProvider.notifier);
    final theme = Theme.of(context);

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
                'Permissions Required',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
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
                'FSI Courier needs the following permissions to function properly. Please enable all of them to continue.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: DSStyles.heightRelaxed,
                ),
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
                label: 'Location',
                description: locationGranted
                    ? 'Granted'
                    : _locationDescription(locationState.status),
                granted: locationGranted,
                buttonLabel: locationGranted
                    ? 'Enabled'
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
                label: 'Camera',
                description: cameraGranted
                    ? 'Granted'
                    : permsState.cameraStatus.isPermanentlyDenied
                    ? 'Permanently denied — open Settings to enable'
                    : 'Required to capture proof-of-delivery photos',
                granted: cameraGranted,
                buttonLabel: cameraGranted
                    ? 'Enabled'
                    : permsState.cameraStatus.isPermanentlyDenied
                    ? 'Open Settings'
                    : 'Grant Permission',
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
                label: 'Notifications',
                description: notifGranted
                    ? 'Granted'
                    : permsState.notificationStatus.isPermanentlyDenied
                    ? 'Permanently denied — open Settings to enable'
                    : 'Required for dispatch assignments and delivery alerts',
                granted: notifGranted,
                buttonLabel: notifGranted
                    ? 'Enabled'
                    : permsState.notificationStatus.isPermanentlyDenied
                    ? 'Open Settings'
                    : 'Grant Permission',
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
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('I have enabled them, refresh'),
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
      LocationStatus.serviceDisabled =>
        'GPS is turned off — required to verify delivery coordinates',
      LocationStatus.permissionPermanentlyDenied =>
        'Permanently denied — open Settings to enable',
      LocationStatus.permissionDenied =>
        'Required to verify delivery coordinates and tracking',
      LocationStatus.determining || LocationStatus.ready => 'Checking…',
    };
  }

  String _locationButtonLabel(LocationStatus status) {
    return switch (status) {
      LocationStatus.serviceDisabled => 'Open Location Settings',
      LocationStatus.permissionPermanentlyDenied => 'Open Settings',
      LocationStatus.permissionDenied => 'Grant Permission',
      LocationStatus.determining || LocationStatus.ready => 'Loading…',
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
    final statusColor = granted
        ? DSColors.primary
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: DSStyles.cardRadius,
        border: Border.all(
          color: granted
              ? DSColors.primary.withValues(alpha: DSStyles.alphaMuted)
              : theme.dividerColor.withValues(alpha: DSStyles.alphaMuted),
          width: DSStyles.borderWidth,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: DSSpacing.md,
        vertical: DSSpacing.sm,
      ),
      child: Row(
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
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                DSSpacing.hXs,
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: statusColor,
                    height: DSStyles.heightNormal,
                  ),
                ),
              ],
            ),
          ),
          DSSpacing.wSm,
          if (granted)
            Icon(
              Icons.check_circle_rounded,
              color: DSColors.primary,
              size: DSIconSize.xl,
            )
          else
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                foregroundColor: DSColors.error,
                padding: EdgeInsets.symmetric(
                  horizontal: DSSpacing.md,
                  vertical: DSSpacing.sm,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: DSTypography.button().copyWith(
                  fontSize: DSTypography.sizeSm,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(buttonLabel),
            ),
        ],
      ),
    );
  }
}
