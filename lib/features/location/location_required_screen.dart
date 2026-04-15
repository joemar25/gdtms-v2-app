// DOCS: docs/features/location.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fsi_courier_app/core/providers/location_provider.dart';
import 'package:fsi_courier_app/core/providers/permissions_provider.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fsi_courier_app/styles/ui_styles.dart';

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
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.security_rounded,
                size: 56,
                color: ColorStyles.grabOrange,
              ),
              const SizedBox(height: 20),
              Text(
                'Permissions Required',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'FSI Courier needs the following permissions to function properly. Please enable all of them to continue.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

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
                    : () => _handleLocation(locationState.status, locationNotifier),
              ),
              const SizedBox(height: 12),

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
              ),
              const SizedBox(height: 12),

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
              ),

              const SizedBox(height: 28),
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

    final cardColor = isDark ? ColorStyles.cardDark : ColorStyles.cardLight;
    final iconColor = granted ? ColorStyles.grabGreen : ColorStyles.grabOrange;
    final statusColor = granted ? ColorStyles.grabGreen : theme.colorScheme.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: UIStyles.cardRadius,
        border: Border.all(
          color: granted
              ? ColorStyles.grabGreen.withValues(alpha: 0.35)
              : theme.dividerColor.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
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
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: statusColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (granted)
            Icon(Icons.check_circle_rounded, color: ColorStyles.grabGreen, size: 26)
          else
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                foregroundColor: ColorStyles.grabOrange,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 12,
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
