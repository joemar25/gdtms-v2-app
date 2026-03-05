import 'package:flutter/material.dart';

import 'package:fsi_courier_app/shared/router/router_keys.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';

enum SnackbarType { success, error, info }

void showAppSnackbar(
  BuildContext? context,
  String message, {
  SnackbarType type = SnackbarType.info,
}) {
  final color = switch (type) {
    SnackbarType.success => Colors.green,
    SnackbarType.error => Colors.red,
    SnackbarType.info => Colors.blue,
  };

  final messenger = context != null
      ? ScaffoldMessenger.maybeOf(context)
      : appScaffoldMessengerKey.currentState;

  messenger?.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Show a top success notification matching the NotificationWidget card style.
/// Uses Overlay so the screen behind remains fully scrollable/interactive.
void showSuccessNotification(
  BuildContext? context,
  String message,
) {
  final ctx = context ?? appScaffoldMessengerKey.currentContext;
  if (ctx == null || !ctx.mounted) return;

  final overlay = Overlay.maybeOf(ctx, rootOverlay: true);
  if (overlay == null) return;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _SuccessBanner(
      message: message,
      onClose: () { if (entry.mounted) entry.remove(); },
    ),
  );

  overlay.insert(entry);
  Future.delayed(const Duration(seconds: 2), () {
    if (entry.mounted) entry.remove();
  });
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    // IgnorePointer on the full-screen wrapper so only the banner itself
    // captures touches — everything below stays scrollable/interactive.
    return IgnorePointer(
      ignoring: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, top + 8, 16, 0),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: ColorStyles.grabGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline_rounded,
                      color: ColorStyles.grabGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
