// DOCS: docs/features/location.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fsi_courier_app/core/providers/location_provider.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';

class LocationRequiredScreen extends ConsumerWidget {
  const LocationRequiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationState = ref.watch(locationProvider);
    final notifier = ref.read(locationProvider.notifier);
    final theme = Theme.of(context);

    String title;
    String message;
    String buttonLabel;
    IconData icon;
    VoidCallback? onAction;

    switch (locationState.status) {
      case LocationStatus.serviceDisabled:
        title = 'GPS is Disabled';
        message =
            'FSI Courier requires your device location to be turned on to verify delivery coordinates and ensure accurate tracking.';
        buttonLabel = 'Open Location Settings';
        icon = Icons.gps_off_rounded;
        onAction = () => notifier.openSettings();
        break;
      case LocationStatus.permissionPermanentlyDenied:
        title = 'Permission Denied';
        message =
            'Location permission has been permanently denied. You must enable it in your device settings to continue using the app.';
        buttonLabel = 'Open App Settings';
        icon = Icons.location_disabled_rounded;
        onAction = () => notifier.openSettings();
        break;
      case LocationStatus.permissionDenied:
        title = 'Permission Required';
        message =
            'FSI Courier needs access to your location to function properly. Please grant location permissions when prompted.';
        buttonLabel = 'Grant Permission';
        icon = Icons.location_off_rounded;
        onAction = () => notifier.requestPermission();
        break;
      case LocationStatus.determining:
      case LocationStatus.ready:
        title = 'Checking Location...';
        message = 'Please wait while we verify your location settings.';
        buttonLabel = 'Loading...';
        icon = Icons.my_location_rounded;
        onAction = null;
        break;
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(icon, size: 84, color: ColorStyles.grabOrange),
              const SizedBox(height: 32),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: ColorStyles.grabOrange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  buttonLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => notifier.refresh(),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                  minimumSize: const Size.fromHeight(54),
                ),
                child: const Text('I have enabled it, refresh'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
