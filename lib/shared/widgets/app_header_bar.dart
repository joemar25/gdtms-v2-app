import 'package:flutter/material.dart';

import 'package:fsi_courier_app/shared/widgets/notification_widget.dart';

/// A drop-in replacement for [AppBar] that always includes a notification
/// bell icon in the trailing position.
/// - [actions]: appear **before** the notification bell.
/// - [trailingActions]: appear **after** the notification bell.
class AppHeaderBar extends StatelessWidget implements PreferredSizeWidget {
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
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      leading: leading,
      bottom: bottom,
      backgroundColor: backgroundColor,
      actions: [
        ...(actions ?? []),
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          tooltip: 'Notifications',
          onPressed: () => NotificationWidget.showSheet(context),
        ),
        ...(trailingActions ?? []),
        const SizedBox(width: 4),
      ],
    );
  }
}
