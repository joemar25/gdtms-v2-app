import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/core/providers/notifications_provider.dart';

/// A drop-in replacement for [AppBar] that always includes a notification
/// bell icon in the trailing position with an unread-count badge.
/// - [actions]: appear **before** the notification bell.
/// - [trailingActions]: appear **after** the notification bell.
class AppHeaderBar extends ConsumerWidget implements PreferredSizeWidget {
  const AppHeaderBar({
    super.key,
    required this.title,
    this.pageIcon,
    this.leading,
    this.actions,
    this.trailingActions,
    this.bottom,
    this.backgroundColor,
  });

  final String title;
  final IconData? pageIcon;
  final Widget? leading;
  final List<Widget>? actions;
  final List<Widget>? trailingActions;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(notificationsUnreadCountProvider);

    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pageIcon != null) ...[
            Icon(pageIcon, size: 22, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
          ],
          Text(title),
        ],
      ),
      leading: leading,
      bottom: bottom,
      backgroundColor: backgroundColor,
      actions: [
        ...(actions ?? []),
        _IOSNotificationBell(
          unreadCount: unreadCount,
          onTap: () => context.push('/notifications'),
        ),
        ...(trailingActions ?? []),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _IOSNotificationBell extends StatefulWidget {
  const _IOSNotificationBell({
    required this.unreadCount,
    required this.onTap,
  });

  final int unreadCount;
  final VoidCallback onTap;

  @override
  State<_IOSNotificationBell> createState() => _IOSNotificationBellState();
}

class _IOSNotificationBellState extends State<_IOSNotificationBell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  int _prevCount = 0;

  @override
  void initState() {
    super.initState();
    _prevCount = widget.unreadCount;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_IOSNotificationBell old) {
    super.didUpdateWidget(old);
    if (widget.unreadCount != _prevCount) {
      _prevCount = widget.unreadCount;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasUnread = widget.unreadCount > 0;
    final label = widget.unreadCount > 99 ? '99+' : '${widget.unreadCount}';

    return Tooltip(
      message: 'Notifications',
      child: CupertinoStyleBellButton(
        onTap: widget.onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              hasUnread
                  ? Icons.notifications_rounded
                  : Icons.notifications_outlined,
              size: 24,
              color: hasUnread
                  ? colorScheme.onSurface
                  : colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            if (hasUnread)
              Positioned(
                top: -4,
                right: -6,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: _BadgePill(label: label, color: colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tap target with iOS press-shrink feedback.
class CupertinoStyleBellButton extends StatefulWidget {
  const CupertinoStyleBellButton({
    super.key,
    required this.child,
    required this.onTap,
  });

  final Widget child;
  final VoidCallback onTap;

  @override
  State<CupertinoStyleBellButton> createState() =>
      _CupertinoStyleBellButtonState();
}

class _CupertinoStyleBellButtonState extends State<CupertinoStyleBellButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _pressScale = Tween(begin: 1.0, end: 0.82).animate(
      CurvedAnimation(parent: _press, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) async {
        await _press.reverse();
        widget.onTap();
      },
      onTapCancel: () => _press.reverse(),
      child: ScaleTransition(
        scale: _pressScale,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Tight pill-shaped badge — no Flutter Badge widget.
class _BadgePill extends StatelessWidget {
  const _BadgePill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isWide = label.length > 1; // "1" vs "12" vs "99+"
    return Container(
      constraints: BoxConstraints(minWidth: isWide ? 0 : 16),
      height: 16,
      padding: EdgeInsets.symmetric(horizontal: isWide ? 4.5 : 0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}