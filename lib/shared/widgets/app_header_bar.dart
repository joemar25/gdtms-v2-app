import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/core/providers/notifications_provider.dart';

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
    this.centerTitle = false,
  });

  final String title;
  final IconData? pageIcon;
  final Widget? leading;
  final List<Widget>? actions;
  final List<Widget>? trailingActions;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;
  final bool centerTitle;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(notificationsUnreadCountProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return AppBar(
      scrolledUnderElevation: 0,
      elevation: 0,
      backgroundColor: backgroundColor ?? Colors.transparent,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 0,
      centerTitle: centerTitle,
      leading: leading,
      leadingWidth: 56,
      title: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Row(
          children: [
            if (pageIcon != null) ...[
              Icon(pageIcon, size: 22, color: colorScheme.onSurface),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                    ),
              ),
            ),
          ],
        ),
      ),
      bottom: bottom,
      actions: [
        ...(actions ?? []),
        NotificationBell(
          unreadCount: unreadCount,
          onTap: () => context.push('/notifications'),
        ),
        ...(trailingActions ?? []),
        const SizedBox(width: 12),
      ],
    );
  }
}

class NotificationBell extends StatelessWidget {
  const NotificationBell({
    super.key,
    required this.unreadCount,
    required this.onTap,
  });

  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;
    final label = unreadCount > 99 ? '99+' : unreadCount.toString();
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: 'Notifications',
      value: hasUnread ? '$label unread notifications' : 'No unread notifications',
      button: true,
      child: IconButton(
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        tooltip: 'Notifications',
        onPressed: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        icon: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: child,
              ),
              child: Icon(
                hasUnread
                    ? Icons.notifications_rounded
                    : Icons.notifications_outlined,
                key: ValueKey(hasUnread),
                size: 26,
                color: colorScheme.onSurface,
              ),
            ),
            if (hasUnread)
              Positioned(
                top: -5,
                right: -5,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: anim,
                    child: child,
                  ),
                  child: _Badge(
                    key: ValueKey(label),
                    label: label,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final isWide = label.length > 2;

    return Container(
      height: 17.5,
      padding: EdgeInsets.symmetric(horizontal: isWide ? 6.5 : 5.5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.2,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.0,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}