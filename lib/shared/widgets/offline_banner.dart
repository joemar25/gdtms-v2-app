// DOCS: docs/shared/widgets.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

/// A reusable offline banner widget with two variants:
/// - **Standard**: Full detailed message about what works offline
/// - **Minimal**: Compact version for list views like dispatches/deliveries
///
/// Use [isMinimal=true] for compact header in list pages, [isMinimal=false]
/// for detailed offline information sections.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    this.isMinimal = false,
    this.customMessage,
    this.margin = const EdgeInsets.only(bottom: 16),
  });

  /// If true, shows a compact minimal version. If false, shows the full detailed version.
  final bool isMinimal;

  /// Custom message to override the default. Only used if [isMinimal=true].
  final String? customMessage;

  /// Margin around the banner. Default is bottom 16 for standard, adjust as needed.
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    if (isMinimal) {
      return _MinimalOfflineBanner(
        message: customMessage ?? 'Showing locally saved data',
        margin: margin,
      );
    }

    return _StandardOfflineBanner(margin: margin);
  }
}

/// Minimal offline banner for use in list pages and compact layouts.
class _MinimalOfflineBanner extends StatelessWidget {
  const _MinimalOfflineBanner({required this.message, required this.margin});

  final String message;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: DSSpacing.md,
      ),
      decoration: BoxDecoration(
        color: DSColors.warning.withValues(alpha: 0.1),
        borderRadius: DSStyles.cardRadius,
        border: Border.all(
          color: DSColors.warning.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, size: DSIconSize.sm, color: DSColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: DSTypography.label(color: DSColors.warning).copyWith(
                fontSize: DSTypography.sizeSm,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Standard detailed offline banner for profile and detail pages.
class _StandardOfflineBanner extends StatelessWidget {
  const _StandardOfflineBanner({required this.margin});

  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(
        horizontal: DSSpacing.base,
        vertical: DSSpacing.md,
      ),
      decoration: BoxDecoration(
        color: DSColors.warning.withValues(alpha: DSStyles.alphaSoft),
        borderRadius: DSStyles.cardRadius,
        border: Border.all(
          color: DSColors.warning.withValues(alpha: DSStyles.alphaBorder),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.wifi_off_rounded, color: DSColors.warning, size: DSIconSize.lg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You're offline",
                  style: DSTypography.label(color: DSColors.warning).copyWith(
                    fontSize: DSTypography.sizeMd,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Local preferences (theme, compact mode, auto-accept) still work. '
                  'Dispatch scanning and data sync require an internet connection.',
                  style: DSTypography.body(
                    color: DSColors.warning,
                  ).copyWith(fontSize: DSTypography.sizeSm, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
