import 'package:flutter/material.dart';

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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200, width: 1.2),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, size: 15, color: Colors.orange.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade800,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "You're offline",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.orange,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Local preferences (theme, compact mode, auto-accept) still work. '
                  'Dispatch scanning and data sync require an internet connection.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade800,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
