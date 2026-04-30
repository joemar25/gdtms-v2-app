// DOCS: docs/development-standards.md
// DOCS: docs/shared/helpers.md — update that file when you edit this one.

import 'package:flutter/material.dart';

import 'package:fsi_courier_app/shared/router/router_keys.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

enum SnackbarType { success, error, info }

void showAppSnackbar(
  BuildContext? context,
  String message, {
  SnackbarType type = SnackbarType.info,
}) {
  final color = switch (type) {
    SnackbarType.success => DSColors.success,
    SnackbarType.error => DSColors.error,
    SnackbarType.info => DSColors.primary,
  };

  final messenger = context != null
      ? ScaffoldMessenger.maybeOf(context)
      : appScaffoldMessengerKey.currentState;

  messenger?.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      // Lift the snackbar above the floating bottom nav bar (~80 px).
      margin: EdgeInsets.fromLTRB(
        DSSpacing.sm,
        0,
        DSSpacing.sm,
        DSSpacing.xl * 2.5,
      ),
    ),
  );
}

// ─── MARK: Overlay Notifications ─────────────────────────────────────────────

/// Represents a single notification entry in the global overlay stack.
class _NotificationEntry {
  final String id;
  final Widget banner;

  _NotificationEntry({required this.id, required this.banner});
}

/// Global manager for top-aligned overlay notifications.
/// Supports stacking up to 2 simultaneous notifications with auto-dismiss.
class AppNotificationManager {
  static final List<_NotificationEntry> _entries = [];
  static OverlayEntry? _overlayEntry;

  /// Entry point to display a new notification banner.
  /// Automatically manages stack height and auto-dismiss timer.
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
              color: DSColors.transparent,
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
                        margin: EdgeInsets.only(top: i * DSSpacing.sm),
                        padding: EdgeInsets.symmetric(horizontal: DSSpacing.md),
                        child: AnimatedScale(
                          scale: DSAnimations.scaleNormal - (i * 0.05),
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

// ─── MARK: Helper Methods ────────────────────────────────────────────────────

/// Show a top success notification with a check icon.
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
  Color color = DSColors.warning, // amber-500
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
  showInfoNotification(context, message, icon: icon, color: DSColors.error);
}

// ─── MARK: UI Components ─────────────────────────────────────────────────────

/// Banner component for info and error notifications.
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
        borderRadius: DSStyles.cardRadius,
        boxShadow: [
          BoxShadow(
            color: DSColors.black.withValues(alpha: DSStyles.alphaSubtle),
            blurRadius: 24,
            offset: const Offset(0, DSSpacing.sm),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        DSSpacing.md,
        DSSpacing.md,
        DSSpacing.sm,
        DSSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: DSIconSize.heroSm,
            height: DSIconSize.heroSm,
            decoration: BoxDecoration(
              color: color.withValues(alpha: DSStyles.alphaSubtle),
              borderRadius: DSStyles.cardRadius,
            ),
            child: Icon(icon, color: color, size: DSIconSize.md),
          ),
          DSSpacing.wMd,
          Expanded(
            child: Text(
              message,
              style:
                  DSTypography.body(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? DSColors.labelPrimaryDark
                        : DSColors.labelPrimary,
                  ).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: DSTypography.sizeMd,
                    height: DSStyles.heightNormal,
                  ),
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 1.0, end: 0.0),
                  duration: const Duration(seconds: 3),
                  builder: (context, value, child) {
                    return CircularProgressIndicator(
                      value: value,
                      strokeWidth: 2,
                      color: color.withValues(alpha: DSStyles.alphaMuted),
                      backgroundColor: color.withValues(alpha: 0.05),
                    );
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: DSIconSize.sm),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: DSIconSize.heroSm,
                  minHeight: DSIconSize.heroSm,
                ),
                style: IconButton.styleFrom(
                  foregroundColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? DSColors.labelTertiaryDark
                      : DSColors.labelTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Banner component for success notifications.
class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: DSStyles.cardRadius,
        boxShadow: [
          BoxShadow(
            color: DSColors.black.withValues(alpha: DSStyles.alphaSubtle),
            blurRadius: 24,
            offset: const Offset(0, DSSpacing.sm),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        DSSpacing.md,
        DSSpacing.md,
        DSSpacing.sm,
        DSSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: DSIconSize.heroSm,
            height: DSIconSize.heroSm,
            decoration: BoxDecoration(
              color: DSColors.primary.withValues(alpha: DSStyles.alphaSubtle),
              borderRadius: DSStyles.cardRadius,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: DSColors.primary,
              size: DSIconSize.md,
            ),
          ),
          DSSpacing.wMd,
          Expanded(
            child: Text(
              message,
              style:
                  DSTypography.body(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? DSColors.labelPrimaryDark
                        : DSColors.labelPrimary,
                  ).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: DSTypography.sizeMd,
                    height: DSStyles.heightNormal,
                  ),
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 1.0, end: 0.0),
                  duration: const Duration(seconds: 3),
                  builder: (context, value, child) {
                    return CircularProgressIndicator(
                      value: value,
                      strokeWidth: 2,
                      color: DSColors.primary.withValues(
                        alpha: DSStyles.alphaMuted,
                      ),
                      backgroundColor: DSColors.primary.withValues(alpha: 0.05),
                    );
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: DSIconSize.sm),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: DSIconSize.heroSm,
                  minHeight: DSIconSize.heroSm,
                ),
                style: IconButton.styleFrom(
                  foregroundColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? DSColors.labelTertiaryDark
                      : DSColors.labelTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
