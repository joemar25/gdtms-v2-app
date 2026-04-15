// DOCS: docs/features/notifications.md — update that file when you edit this one.

// =============================================================================
// notifications_screen.dart
// =============================================================================
//
// Purpose:
//   In-app notification centre that displays system and operational alerts
//   pushed to the courier (e.g. new dispatch assignments, sync warnings,
//   account messages from FSI operations).
//
// Key behaviours:
//   • Notifications are stored and served via [NotificationsProvider].
//   • Each item shows a timestamp, type badge, and message body.
//   • Tapping a notification marks it as read and navigates to the relevant
//     screen if applicable (e.g. a delivery barcode deep-link).
//   • An unread badge count is shown on the bell icon in AppHeaderBar.
//   • Offline banner is shown when connectivity is unavailable (new
//     notifications cannot be fetched but cached ones remain readable).
//
// Navigation:
//   Route: /notifications
//   Pushed from: AppHeaderBar bell icon (present on most screens)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/styles/ui_styles.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/notifications_provider.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';
import 'package:fsi_courier_app/shared/widgets/offline_banner.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Reload fresh data whenever the screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsProvider.notifier).load();
    });
  }

  Future<void> _onMarkAllRead() async {
    await ref.read(notificationsProvider.notifier).markAllAsRead();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      appBar: AppHeaderBar(
        titleWidget: Text(
          'Notifications',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        showNotificationBell: false,
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: _onMarkAllRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _buildBody(context, state, isOnline),
    );
  }

  Widget _buildBody(
    BuildContext context,
    NotificationsState state,
    bool isOnline,
  ) {
    Widget content;

    if (state.loading && state.entries.isEmpty) {
      content = const Center(child: CircularProgressIndicator());
    } else if (state.entries.isEmpty) {
      content = LayoutBuilder(
        builder: (context, constraints) {
          return RefreshIndicator(
            onRefresh: () => ref.read(notificationsProvider.notifier).load(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Container(
                height: constraints.maxHeight,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 56,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No notifications yet',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } else {
      content = RefreshIndicator(
        onRefresh: () => ref.read(notificationsProvider.notifier).load(),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: state.entries.length + (state.hasMore ? 1 : 0),
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
          itemBuilder: (context, index) {
            if (index == state.entries.length) {
              return _LoadMoreButton(
                loading: state.loadingMore,
                onTap: () =>
                    ref.read(notificationsProvider.notifier).loadMore(),
              );
            }
            return _NotificationTile(
              notification: state.entries[index],
              onTap: () => _handleTap(state.entries[index], isOnline),
            );
          },
        ),
      );
    }

    if (!isOnline) {
      return Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: OfflineBanner(isMinimal: true, margin: EdgeInsets.zero),
          ),
          Expanded(child: content),
        ],
      );
    }

    return content;
  }

  void _handleTap(AppNotification n, bool isOnline) {
    if (!isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot open notification while offline'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (!n.read) {
      ref.read(notificationsProvider.notifier).markAsRead(n.id);
    }

    // new_dispatch → open dispatch eligibility screen so courier can accept.
    if (n.type == 'new_dispatch' && n.dispatchCode != null) {
      context.push(
        '/dispatches/eligibility',
        extra: {'dispatch_code': n.dispatchCode},
      );
      return;
    }

    // Payout notifications → wallet detail.
    if (n.transactionReference != null && n.transactionReference!.isNotEmpty) {
      context.push('/wallet/${n.transactionReference}');
      return;
    }

    // Single-barcode notifications → delivery detail.
    if (n.deliveryReferences.length == 1) {
      context.push('/deliveries/${n.deliveryReferences.first}');
    }
  }
}

// ─ Helper functions ───────────────────────────────────────────────────────────

/// Mask a dispatch code to show only last 4 characters
String _maskDispatchCode(String code) {
  if (code.length <= 4) return code;
  return '${code.substring(0, code.length - 4)}****';
}

// ─── Notification tile ────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUnread = !notification.read;

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isUnread
              ? (isDark
                    ? ColorStyles.grabGreen.withValues(
                        alpha: UIStyles.alphaSoft,
                      )
                    : ColorStyles.grabGreen.withValues(
                        alpha: UIStyles.alphaSoft,
                      ))
              : null,
          border: isUnread
              ? Border(left: BorderSide(color: ColorStyles.grabGreen, width: 3))
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TypeIcon(type: notification.type),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notification.message,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isUnread
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      if (isUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 4),
                          decoration: const BoxDecoration(
                            color: ColorStyles.grabGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Rejection reason (payout_rejected only).
                  if (notification.rejectionReason != null) ...[
                    Text(
                      'Reason: ${notification.rejectionReason}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red.shade400,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Row(
                    children: [
                      // Transaction reference (payout_*).
                      if (notification.transactionReference != null &&
                          notification.dispatchCode == null) ...[
                        Flexible(
                          child: Text(
                            notification.transactionReference!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: ColorStyles.grabGreen,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        formatDate(notification.date, includeTime: true),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Type icon ────────────────────────────────────────────────────────────────

class _TypeIcon extends StatelessWidget {
  const _TypeIcon({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (type) {
      'new_dispatch' => (Icons.local_shipping_rounded, Colors.blue.shade600),
      'payout_requested' => (Icons.send_rounded, Colors.blue.shade400),
      'payout_approved' => (Icons.check_circle_rounded, ColorStyles.grabGreen),
      'payout_rejected' => (Icons.cancel_rounded, Colors.red.shade400),
      'payout_paid' => (Icons.payments_rounded, ColorStyles.grabGreen),
      'transaction_due_soon' => (
        Icons.schedule_rounded,
        Colors.orange.shade400,
      ),
      'transaction_due_today' => (Icons.today_rounded, Colors.red.shade500),
      _ => (Icons.notifications_rounded, Colors.grey.shade400),
    };

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: UIStyles.alphaActiveAccent),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

// ─── Load more button ─────────────────────────────────────────────────────────

class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({required this.loading, required this.onTap});
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : OutlinedButton(onPressed: onTap, child: const Text('Load more')),
      ),
    );
  }
}
