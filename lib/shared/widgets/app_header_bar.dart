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
    this.leading,
    this.actions,
    this.trailingActions,
    this.bottom,
    this.backgroundColor,
  });

  final String title;
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
      title: Text(title),
      leading: leading,
      bottom: bottom,
      backgroundColor: backgroundColor,
      actions: [
        ...(actions ?? []),
        Badge(
          isLabelVisible: unreadCount > 0,
          label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
          child: IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
          ),
        ),
        ...(trailingActions ?? []),
        const SizedBox(width: 4),
      ],
    );
  }
}
