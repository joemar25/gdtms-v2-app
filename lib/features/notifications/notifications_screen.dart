// DOCS: docs/development-standards.md
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
//   • Items are grouped by Today / Yesterday / Earlier.
//   • Tapping a notification marks it as read and navigates to the relevant
//     screen if applicable (e.g. a delivery barcode deep-link).
//   • An unread badge count is shown on the bell icon in AppHeaderBar.
//   • Offline banner is shown when connectivity is unavailable.
//
// Navigation:
//   Route: /notifications
//   Pushed from: AppHeaderBar bell icon (present on most screens)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/notifications_provider.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';
import 'package:fsi_courier_app/shared/widgets/offline_banner.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

// ─── Flat list entry model ────────────────────────────────────────────────────

class _Entry {
  const _Entry._({required this.kind, this.label, this.notification});

  factory _Entry.header(String label) =>
      _Entry._(kind: _Kind.header, label: label);
  factory _Entry.tile(AppNotification n) =>
      _Entry._(kind: _Kind.tile, notification: n);
  factory _Entry.loadMore() => const _Entry._(kind: _Kind.loadMore);

  final _Kind kind;
  final String? label;
  final AppNotification? notification;

  bool get isHeader => kind == _Kind.header;
  bool get isTile => kind == _Kind.tile;
  bool get isLoadMore => kind == _Kind.loadMore;
}

enum _Kind { header, tile, loadMore }

// ─── Screen ───────────────────────────────────────────────────────────────────

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  // ─── MARK: Lifecycle ───────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsProvider.notifier).load();
    });
  }

  // ─── MARK: Handlers ────────────────────────────────────────────────────────

  void _handleTap(AppNotification n, bool isOnline) {
    if (!isOnline) return;
    if (!n.read) {
      ref.read(notificationsProvider.notifier).markAsRead(n.id);
    }
    if (n.type == 'new_dispatch') {
      context.push('/dispatches');
      return;
    }
    if (n.transactionReference != null && n.transactionReference!.isNotEmpty) {
      context.push('/wallet/${n.transactionReference}');
      return;
    }
    if (n.deliveryReferences.length == 1) {
      context.push('/deliveries/${n.deliveryReferences.first}/update');
    }
  }

  // ─── MARK: Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? DSColors.scaffoldDark : DSColors.scaffoldLight,
      appBar: AppHeaderBar(
        showNotificationBell: false,
        titleWidget: Row(
          children: [
            DSSpacing.wSm,
            Text(
              'Notifications',
              style: DSTypography.heading().copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: DSTypography.lsSlightlyTight,
              ),
            ),
            if (state.unreadCount > 0) ...[
              DSSpacing.wSm,
              _UnreadPill(count: state.unreadCount),
            ],
          ],
        ),
        actions: [
          if (state.unreadCount > 0)
            TextButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(notificationsProvider.notifier).markAllAsRead();
              },
              style: TextButton.styleFrom(
                foregroundColor: DSColors.primary,
                padding: EdgeInsets.symmetric(
                  horizontal: DSSpacing.md,
                  vertical: DSSpacing.sm,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: DSTypography.button().copyWith(
                  fontSize: DSTypography.sizeSm,
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon: const Icon(Icons.done_all_rounded, size: DSIconSize.sm),
              label: const Text('Mark all read'),
            ),
        ],
      ),
      body: _buildBody(context, state, isOnline, isDark),
    );
  }

  Widget _buildBody(
    BuildContext context,
    NotificationsState state,
    bool isOnline,
    bool isDark,
  ) {
    Widget content;

    if (state.loading && state.entries.isEmpty) {
      content = const Center(child: DSLoading());
    } else if (state.entries.isEmpty) {
      content = _EmptyState(
        onRefresh: () => ref.read(notificationsProvider.notifier).load(),
        isDark: isDark,
      );
    } else {
      // Precompute flat entry list once per build.
      final entries = _buildEntries(state.entries, state.hasMore);

      content = RefreshIndicator(
        onRefresh: () => ref.read(notificationsProvider.notifier).load(),
        color: DSColors.primary,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(DSSpacing.md, 4, DSSpacing.md, 32),
          itemCount: entries.length,
          itemBuilder: (context, i) {
            final entry = entries[i];

            if (entry.isHeader) {
              return _SectionHeader(label: entry.label!).dsFadeEntry(
                delay: DSAnimations.stagger(i, step: DSAnimations.staggerFine),
                duration: DSAnimations.dFast,
              );
            }

            if (entry.isLoadMore) {
              return _LoadMoreButton(
                loading: state.loadingMore,
                onTap: () =>
                    ref.read(notificationsProvider.notifier).loadMore(),
              );
            }

            // Tile
            final n = entry.notification!;
            return _NotificationCard(
              notification: n,
              isDark: isDark,
              onTap: () => _handleTap(n, isOnline),
            ).dsCardEntry(
              delay: DSAnimations.stagger(i, step: DSAnimations.staggerFine),
            );
          },
        ),
      );
    }

    if (!isOnline) {
      return Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              DSSpacing.md,
              DSSpacing.md,
              DSSpacing.md,
              0,
            ),
            child: const ConnectionStatusBanner(
              isMinimal: true,
              margin: EdgeInsets.zero,
            ),
          ),
          Expanded(child: content),
        ],
      );
    }

    return content;
  }

  // ─── MARK: Logic ───────────────────────────────────────────────────────────

  // ── Group entries ────────────────────────────────────────────────────────

  static List<_Entry> _buildEntries(
    List<AppNotification> notifications,
    bool hasMore,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final groups = <String, List<AppNotification>>{};
    for (final n in notifications) {
      final parsed = DateTime.tryParse(n.date);
      final String key;
      if (parsed == null) {
        key = 'Earlier';
      } else {
        final d = DateTime(parsed.year, parsed.month, parsed.day);
        if (d == today) {
          key = 'Today';
        } else if (d == yesterday) {
          key = 'Yesterday';
        } else {
          key = 'Earlier';
        }
      }
      (groups[key] ??= []).add(n);
    }

    final entries = <_Entry>[];
    for (final key in ['Today', 'Yesterday', 'Earlier']) {
      final list = groups[key];
      if (list == null || list.isEmpty) continue;
      entries.add(_Entry.header(key));
      for (final n in list) {
        entries.add(_Entry.tile(n));
      }
    }
    if (hasMore) entries.add(_Entry.loadMore());
    return entries;
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(
        top: DSSpacing.md,
        bottom: DSSpacing.sm,
        left: DSSpacing.xs,
      ),
      child: Text(
        label.toUpperCase(),
        style: DSTypography.label().copyWith(
          fontSize: DSTypography.sizeSm,
          fontWeight: FontWeight.w700,
          color: isDark ? DSColors.labelTertiaryDark : DSColors.labelTertiary,
          letterSpacing: DSTypography.lsExtraLoose,
        ),
      ),
    );
  }
}

// ─── Notification card ────────────────────────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.isDark,
    required this.onTap,
  });

  final AppNotification notification;
  final bool isDark;
  final VoidCallback onTap;

  bool get _isNavigable =>
      notification.type == 'new_dispatch' ||
      (notification.transactionReference?.isNotEmpty ?? false) ||
      notification.deliveryReferences.length == 1;

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.read;
    final (iconData, accentColor) = _resolve(notification.type);

    final cardColor = isDark ? DSColors.cardDark : DSColors.cardLight;
    final unreadBg = accentColor.withValues(alpha: DSStyles.alphaSoft);
    final bg = isUnread ? unreadBg : cardColor;

    return Padding(
      padding: EdgeInsets.only(bottom: DSSpacing.sm),
      child: Material(
        color: bg,
        borderRadius: DSStyles.cardRadius,
        elevation: isDark ? 0 : 1,
        shadowColor: DSColors.black.withValues(alpha: DSStyles.alphaSoft),
        child: InkWell(
          borderRadius: DSStyles.cardRadius,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: ClipRRect(
            borderRadius: DSStyles.cardRadius,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left accent bar — rendered as a plain Container, no Border.
                  Container(
                    width: DSSpacing.xs,
                    color: isUnread ? accentColor : DSColors.transparent,
                  ),

                  // Card body
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(DSSpacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon container
                          Container(
                            width: DSIconSize.heroSm,
                            height: DSIconSize.heroSm,
                            decoration: BoxDecoration(
                              color: accentColor.withValues(
                                alpha: DSStyles.alphaSubtle,
                              ),
                              borderRadius: DSStyles.pillRadius,
                            ),
                            child: Icon(
                              iconData,
                              size: DSIconSize.lg,
                              color: accentColor,
                            ),
                          ),
                          DSSpacing.wMd,

                          // Text content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Message + unread dot
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        notification.message,
                                        style: DSTypography.body().copyWith(
                                          fontSize: DSTypography.sizeMd,
                                          fontWeight: isUnread
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: isDark
                                              ? DSColors.labelPrimaryDark
                                              : DSColors.labelPrimary,
                                          height: DSStyles.heightNormal,
                                        ),
                                      ),
                                    ),
                                    if (isUnread) ...[
                                      DSSpacing.wSm,
                                      Padding(
                                        padding: EdgeInsets.only(
                                          top: DSSpacing.xs,
                                        ),
                                        child: Container(
                                          width: DSIconSize.xs,
                                          height: DSIconSize.xs,
                                          decoration: BoxDecoration(
                                            color: accentColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),

                                // Rejection reason pill
                                if (notification.rejectionReason != null) ...[
                                  DSSpacing.hSm,
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: DSSpacing.sm,
                                      vertical: DSSpacing.xs,
                                    ),
                                    decoration: BoxDecoration(
                                      color: DSColors.error.withValues(
                                        alpha: DSStyles.alphaSoft,
                                      ),
                                      borderRadius: DSStyles.pillRadius,
                                      border: Border.all(
                                        color: DSColors.error.withValues(
                                          alpha: DSStyles.alphaSubtle,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      notification.rejectionReason!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: DSTypography.caption().copyWith(
                                        fontSize: DSTypography.sizeSm,
                                        color: DSColors.error,
                                        fontWeight: FontWeight.w500,
                                        height: DSStyles.heightNormal,
                                      ),
                                    ),
                                  ),
                                ],

                                DSSpacing.hSm,

                                // Meta row
                                Row(
                                  children: [
                                    if (notification.transactionReference !=
                                            null &&
                                        notification.dispatchCode == null) ...[
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: DSSpacing.sm,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: accentColor.withValues(
                                            alpha: DSStyles.alphaSubtle,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          notification.transactionReference!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: DSTypography.label().copyWith(
                                            fontSize: DSTypography.sizeXs,
                                            fontWeight: FontWeight.w700,
                                            color: accentColor,
                                            letterSpacing: DSTypography.lsLoose,
                                          ),
                                        ),
                                      ),
                                      DSSpacing.wSm,
                                    ],
                                    Expanded(
                                      child: Text(
                                        formatDate(
                                          notification.date,
                                          includeTime: true,
                                        ),
                                        style: DSTypography.caption().copyWith(
                                          fontSize: DSTypography.sizeSm,
                                          color: isDark
                                              ? DSColors.labelTertiaryDark
                                              : DSColors.labelTertiary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (_isNavigable) ...[
                                      DSSpacing.wXs,
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: DSIconSize.sm,
                                        color: isDark
                                            ? DSColors.labelTertiaryDark
                                            : DSColors.labelTertiary,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

  static (IconData, Color) _resolve(String type) => switch (type) {
    'new_dispatch' => (Icons.local_shipping_rounded, DSColors.primary),
    'payout_requested' => (Icons.send_rounded, DSColors.primary),
    'payout_approved' => (Icons.check_circle_rounded, DSColors.primary),
    'payout_rejected' => (Icons.cancel_rounded, DSColors.error),
    'payout_paid' => (Icons.payments_rounded, DSColors.primary),
    'transaction_due_soon' => (Icons.schedule_rounded, DSColors.warning),
    'transaction_due_today' => (Icons.today_rounded, DSColors.error),
    _ => (Icons.notifications_rounded, DSColors.labelTertiary),
  };
}

// ─── Unread pill ──────────────────────────────────────────────────────────────

class _UnreadPill extends StatelessWidget {
  const _UnreadPill({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: DSSpacing.sm,
        vertical: DSSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: DSColors.primary,
        borderRadius: DSStyles.circularRadius,
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: DSTypography.caption().copyWith(
          fontSize: DSTypography.sizeSm,
          fontWeight: FontWeight.w700,
          color: DSColors.white,
          height: DSStyles.heightNormal,
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh, required this.isDark});
  final Future<void> Function() onRefresh;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RefreshIndicator(
          onRefresh: onRefresh,
          color: DSColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: DSIconSize.xs,
                      height: DSIconSize.xs,
                      decoration: BoxDecoration(
                        color: isDark
                            ? DSColors.secondarySurfaceDark
                            : DSColors.secondarySurfaceLight,
                        borderRadius: DSStyles.cardRadius,
                      ),
                      child: Icon(
                        Icons.notifications_none_rounded,
                        size: DSIconSize.xl,
                        color: isDark
                            ? DSColors.labelTertiaryDark
                            : DSColors.labelTertiary,
                      ),
                    ).dsHeroEntry(),
                    DSSpacing.hMd,
                    Text(
                      'All caught up',
                      style: DSTypography.heading().copyWith(
                        fontSize: DSTypography.sizeMd,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? DSColors.labelPrimaryDark
                            : DSColors.labelPrimary,
                        letterSpacing: -0.3,
                      ),
                    ).dsFadeEntry(
                      delay: const Duration(milliseconds: 150),
                      duration: const Duration(milliseconds: 350),
                    ),
                    DSSpacing.hSm,
                    Text(
                      'No notifications yet. Pull to refresh.',
                      style: DSTypography.body().copyWith(
                        fontSize: DSTypography.sizeMd,
                        color: isDark
                            ? DSColors.labelTertiaryDark
                            : DSColors.labelTertiary,
                      ),
                    ).dsFadeEntry(
                      delay: const Duration(milliseconds: 250),
                      duration: const Duration(milliseconds: 350),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Load more ────────────────────────────────────────────────────────────────

class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({required this.loading, required this.onTap});
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: DSSpacing.lg),
      child: Center(
        child: loading
            ? const DSLoading(size: DSIconSize.sm)
            : OutlinedButton.icon(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: DSColors.primary,
                  side: const BorderSide(color: DSColors.primary),
                  padding: EdgeInsets.symmetric(
                    horizontal: DSSpacing.lg,
                    vertical: DSSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: DSStyles.cardRadius,
                  ),
                  textStyle: DSTypography.button().copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: DSTypography.sizeMd,
                  ),
                ),
                icon: const Icon(
                  Icons.expand_more_rounded,
                  size: DSIconSize.md,
                ),
                label: const Text('Load more'),
              ),
      ),
    );
  }
}
