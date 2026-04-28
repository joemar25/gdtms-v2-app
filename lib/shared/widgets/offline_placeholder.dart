// DOCS: docs/shared/widgets.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

/// A full-page placeholder for offline states that requires connectivity to proceed.
class OfflinePlaceholder extends StatelessWidget {
  const OfflinePlaceholder({
    super.key,
    required this.onRetry,
    this.message = 'Viewing this screen requires an internet connection.',
  });

  final VoidCallback onRetry;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DSSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 64,
              color: Theme.of(context).brightness == Brightness.dark
                  ? DSColors.labelSecondaryDark
                  : DSColors.labelSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'No Internet Connection',
              style: DSTypography.heading().copyWith(
                fontWeight: FontWeight.w700,
                fontSize: DSTypography.sizeMd,
                color: Theme.of(context).brightness == Brightness.dark
                    ? DSColors.labelPrimaryDark
                    : DSColors.labelPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: DSTypography.caption(
                color: Theme.of(context).brightness == Brightness.dark
                    ? DSColors.labelSecondaryDark
                    : DSColors.labelSecondary,
              ).copyWith(fontSize: DSTypography.sizeMd),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
