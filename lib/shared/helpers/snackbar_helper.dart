// DOCS: docs/shared/helpers.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/styles/ui_styles.dart';

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
class _NotificationEntry {
  final String id;
  final Widget banner;

  _NotificationEntry({required this.id, required this.banner});
}

class AppNotificationManager {
  static final List<_NotificationEntry> _entries = [];
  static OverlayEntry? _overlayEntry;

  static void show(
    BuildContext context,
    Widget Function(String id, VoidCallback onClose) builder,
  ) {
    final String id = UniqueKey().toString();

    void close() {
      _entries.removeWhere((e) => e.id == id);
      _overlayEntry?.markNeedsBuild();
      if (_entries.isEmpty) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      }
    }

    final banner = builder(id, close);
    _entries.insert(0, _NotificationEntry(id: id, banner: banner));

    // Limit to max 2 overlapping notifications
    if (_entries.length > 2) {
      _entries.removeLast();
    }

    if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(
        builder: (context) {
          final top = MediaQuery.of(context).padding.top;
          return Positioned(
            top: top + 8,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.transparent,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: _entries
                    .asMap()
                    .entries
                    .map((kv) {
                      int i = kv.key;
                      var entry = kv.value;

                      return AnimatedContainer(
                        key: ValueKey(entry.id),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        margin: EdgeInsets.only(top: i * 12.0),
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: AnimatedScale(
                          scale: 1.0 - (i * 0.05),
                          alignment: Alignment.topCenter,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          child: IgnorePointer(
                            ignoring:
                                i !=
                                0, // Only the top notification is interactive
                            child: Dismissible(
                              key: ValueKey('dismiss_up_${entry.id}'),
                              direction: DismissDirection.up,
                              onDismissed: (_) {
                                _entries.removeWhere((e) => e.id == entry.id);
                                _overlayEntry?.markNeedsBuild();
                                if (_entries.isEmpty) {
                                  _overlayEntry?.remove();
                                  _overlayEntry = null;
                                }
                              },
                              child: Dismissible(
                                key: ValueKey('dismiss_horiz_${entry.id}'),
                                direction: DismissDirection.horizontal,
                                onDismissed: (_) {
                                  _entries.removeWhere((e) => e.id == entry.id);
                                  _overlayEntry?.markNeedsBuild();
                                  if (_entries.isEmpty) {
                                    _overlayEntry?.remove();
                                    _overlayEntry = null;
                                  }
                                },
                                child: entry.banner,
                              ),
                            ),
                          ),
                        ),
                      );
                    })
                    .toList()
                    .reversed
                    .toList(),
              ),
            ),
          );
        },
      );
      Overlay.maybeOf(context, rootOverlay: true)?.insert(_overlayEntry!);
    } else {
      _overlayEntry?.markNeedsBuild();
    }

    // Auto dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (_entries.any((e) => e.id == id)) {
        close();
      }
    });
  }
}

void showSuccessNotification(BuildContext? context, String message) {
  final ctx = context ?? appScaffoldMessengerKey.currentContext;
  if (ctx == null || !ctx.mounted) return;

  AppNotificationManager.show(ctx, (id, close) {
    return _SuccessBanner(message: message, onClose: close);
  });
}

/// Show a top info/warning notification with a lock icon.
/// Same overlay style as [showSuccessNotification] but with an amber accent.
void showInfoNotification(
  BuildContext? context,
  String message, {
  IconData icon = Icons.lock_outline_rounded,
  Color color = const Color(0xFFF59E0B), // amber-500
}) {
  final ctx = context ?? appScaffoldMessengerKey.currentContext;
  if (ctx == null || !ctx.mounted) return;

  AppNotificationManager.show(ctx, (id, close) {
    return _InfoBanner(
      message: message,
      icon: icon,
      color: color,
      onClose: close,
    );
  });
}

/// Show a top error notification matching the NotificationWidget card style.
/// Uses Overlay so the screen behind remains fully scrollable/interactive.
void showErrorNotification(
  BuildContext? context,
  String message, {
  IconData icon = Icons.error_outline_rounded,
}) {
  showInfoNotification(
    context,
    message,
    icon: icon,
    color: Colors.red.shade600,
  );
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.message,
    required this.icon,
    required this.color,
    required this.onClose,
  });

  final String message;
  final IconData icon;
  final Color color;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: UIStyles.cardRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: UIStyles.alphaActiveAccent),
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
              color: color.withValues(alpha: UIStyles.alphaActiveAccent),
              borderRadius: UIStyles.cardRadius,
            ),
            child: Icon(icon, color: color, size: 20),
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
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 1.0, end: 0.0),
                  duration: const Duration(seconds: 3),
                  builder: (context, value, child) {
                    return CircularProgressIndicator(
                      value: value,
                      strokeWidth: 2,
                      color: Colors.grey.shade300,
                      backgroundColor: Colors.transparent,
                    );
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                style: IconButton.styleFrom(
                  foregroundColor: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: UIStyles.cardRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: UIStyles.alphaActiveAccent),
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
              color: ColorStyles.grabGreen.withValues(
                alpha: UIStyles.alphaActiveAccent,
              ),
              borderRadius: UIStyles.cardRadius,
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
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 1.0, end: 0.0),
                  duration: const Duration(seconds: 3),
                  builder: (context, value, child) {
                    return CircularProgressIndicator(
                      value: value,
                      strokeWidth: 2,
                      color: Colors.grey.shade300,
                      backgroundColor: Colors.transparent,
                    );
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                style: IconButton.styleFrom(
                  foregroundColor: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
