// DOCS: docs/shared/widgets.md — update that file when you edit this one.

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/providers/notifications_provider.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/shared/widgets/scan_mode_sheet.dart';

class AppHeaderBar extends ConsumerWidget implements PreferredSizeWidget {
  const AppHeaderBar({
    super.key,
    this.title,
    this.titleWidget,
    this.pageIcon,
    this.leading,
    this.actions,
    this.trailingActions,
    this.bottom,
    this.backgroundColor,
    this.centerTitle = false,
    this.showNotificationBell = true,
    this.heroTag,
  });

  final String? title;
  final Widget? titleWidget;
  final IconData? pageIcon;
  final Widget? leading;
  final List<Widget>? actions;
  final List<Widget>? trailingActions;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;
  final bool centerTitle;
  final bool showNotificationBell;
  final String? heroTag;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(notificationsUnreadCountProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final appBar = AppBar(
      scrolledUnderElevation: DSStyles.elevationNone,
      elevation: DSStyles.elevationNone,
      backgroundColor: backgroundColor ?? DSColors.transparent,
      surfaceTintColor: DSColors.transparent,
      titleSpacing: 0,
      centerTitle: centerTitle,
      leading: leading,
      leadingWidth: DSIconSize.heroSm,
      title: Padding(
        padding: EdgeInsets.only(left: DSSpacing.sm),
        child:
            titleWidget ??
            Row(
              children: [
                if (pageIcon != null) ...[
                  Icon(pageIcon, size: DSIconSize.lg, color: colorScheme.onSurface),
                  DSSpacing.wSm,
                ],
                Expanded(
                  child: Text(
                    title ?? '',
                    overflow: TextOverflow.ellipsis,
                    style: DSTypography.heading().copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: DSTypography.lsSlightlyTight,
                    ),
                  ),
                ),
              ],
            ),
      ),
      bottom: bottom,
      actions: [
        ...(actions ?? []),
        if (showNotificationBell)
          NotificationBell(
            unreadCount: unreadCount,
            onTap: () => context.push('/notifications'),
          ),
        ...(trailingActions ?? []),
        DSSpacing.wMd,
      ],
    );

    if (heroTag != null) {
      return Hero(
        tag: heroTag!,
        // Use a material wrapper to prevent text style issues during Hero transition
        child: Material(color: DSColors.transparent, child: appBar),
      );
    }
    return appBar;
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
      value: hasUnread
          ? '$label unread notifications'
          : 'No unread notifications',
      button: true,
      child: IconButton(
        padding: EdgeInsets.all(DSSpacing.sm),
        constraints: const BoxConstraints(minWidth: DSSpacing.xs, minHeight: DSSpacing.xs),
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
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: Icon(
                hasUnread
                    ? Icons.notifications_rounded
                    : Icons.notifications_outlined,
                key: ValueKey(hasUnread),
                size: DSIconSize.xl,
                color: colorScheme.onSurface,
              ),
            ),
            if (hasUnread)
              Positioned(
                top: -5,
                right: -5,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: _Badge(key: ValueKey(label), label: label),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isWide = label.length > 2;

    return Container(
      height: 17.5,
      padding: EdgeInsets.symmetric(horizontal: isWide ? 6.5 : 5.5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        borderRadius: DSStyles.cardRadius,
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: DSStyles.strokeWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: DSColors.black.withValues(alpha: DSStyles.alphaSubtle),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: DSTypography.label(color: DSColors.white).copyWith(
          fontSize: DSTypography.sizeXs,
          fontWeight: FontWeight.w700,
          height: 1.0,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

// ─── Dashboard Home Header ────────────────────────────────────────────────────
// Personalised header for the dashboard: avatar + name + role on the left,
// search icon + notification bell on the right.
//
// Tapping the search icon expands the header into an inline search bar. The
// camera button in expanded mode calls [showScanModeSheet] so the courier can
// choose dispatch or POD mode exactly like the dedicated scan screen.
// Submitting text performs a local barcode lookup; an exact match navigates
// directly to the delivery detail, otherwise the delivery list opens with the
// query pre-populated.

class DashboardHeaderBar extends ConsumerStatefulWidget
    implements PreferredSizeWidget {
  const DashboardHeaderBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  ConsumerState<DashboardHeaderBar> createState() => _DashboardHeaderBarState();
}

class _DashboardHeaderBarState extends ConsumerState<DashboardHeaderBar> {
  bool _expanded = false;
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Collapse the search bar whenever the text field loses focus (e.g. the
  /// user taps blank space on the dashboard body).
  void _onFocusChanged() {
    if (_expanded && !_focusNode.hasFocus) {
      _collapse();
    }
  }

  void _expand() {
    setState(() => _expanded = true);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  void _collapse() {
    if (!_expanded) return;
    _focusNode.unfocus();
    setState(() {
      _expanded = false;
      _searchController.clear();
    });
  }

  Future<void> _onSubmit(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    _collapse();

    // Exact barcode lookup in local SQLite first.
    final matches = await LocalDeliveryDao.instance.searchVisibleByQuery(
      query.toUpperCase(),
    );
    if (!mounted) return;

    if (matches.length == 1 &&
        matches.first.barcode.toUpperCase() == query.toUpperCase()) {
      // Exact barcode match → go directly to delivery detail.
      context.push('/deliveries/${matches.first.barcode}/update');
    } else {
      // Generic (account name / partial) → open delivery list with search.
      context.push('/deliveries', extra: {'initialSearch': query});
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final courier = auth.courier ?? {};
    final firstName = courier['first_name']?.toString() ?? '';
    final lastName = courier['last_name']?.toString() ?? '';
    final name = '$firstName $lastName'.trim().isEmpty
        ? 'Courier'
        : '$firstName $lastName'.trim();
    // mar-note: this is necessary change since not all courier has email and to be considered all as FREELANCE COURIER
    // final email = courier['email']?.toString();
    // final role = email != null && email.isNotEmpty
    //     ? email
    //     : 'Freelance Courier';
    final role = "FREELANCE COURIER";
    final profileUrl = courier['profile_picture_url']?.toString();
    final unreadCount = ref.watch(notificationsUnreadCountProvider);

    return AppBar(
      scrolledUnderElevation: DSStyles.elevationNone,
      elevation: DSStyles.elevationNone,
      backgroundColor: DSColors.transparent,
      surfaceTintColor: DSColors.transparent,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: _expanded
            ? _SearchRow(
                key: const ValueKey('search'),
                controller: _searchController,
                focusNode: _focusNode,
                onCollapse: _collapse,
                onSubmit: _onSubmit,
              )
            : _ProfileRow(
                key: const ValueKey('profile'),
                name: name,
                role: role,
                profileUrl: profileUrl,
                unreadCount: unreadCount,
                onSearchTap: _expand,
              ),
      ),
    );
  }
}

// ── Expanded search row ───────────────────────────────────────────────────────

class _SearchRow extends StatelessWidget {
  const _SearchRow({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onCollapse,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onCollapse;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        // ── Back button ────────────────────────────────────────────
        GestureDetector(
          onTap: onCollapse,
          child: Container(
            width: DSIconSize.heroSm,
            height: DSIconSize.heroSm,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(DSStyles.radiusMD),
              boxShadow: [
                BoxShadow(
                  color: DSColors.black.withValues(alpha: DSStyles.alphaSoft),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              size: DSIconSize.md,
              color: cs.onSurface,
            ),
          ),
        ),
        DSSpacing.wSm,

        // ── Text field ─────────────────────────────────────────────
        Expanded(
          child: SizedBox(
            height: DSIconSize.heroSm,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: onSubmit,
              style: DSTypography.body().copyWith(
                fontSize: DSTypography.sizeMd,
              ),
              decoration: InputDecoration(
                hintText: 'Barcode, account name…',
                hintStyle: DSTypography.body(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? DSColors.labelSecondaryDark
                      : DSColors.labelSecondary,
                ).copyWith(fontSize: DSTypography.sizeMd),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: DSSpacing.md,
                  vertical: DSSpacing.md,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DSStyles.radiusMD),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DSStyles.radiusMD),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DSStyles.radiusMD),
                  borderSide: BorderSide(
                    color: DSColors.primary.withValues(alpha: DSStyles.alphaDisabled),
                  ),
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? DSColors.scaffoldDark
                    : DSColors.scaffoldLight,
              ),
            ),
          ),
        ),
        DSSpacing.wSm,

        // ── Camera (scan) button ───────────────────────────────────
        _HeaderIconButton(
          icon: Icons.camera_alt_rounded,
          onTap: () {
            HapticFeedback.lightImpact();
            showScanModeSheet(context);
          },
        ),
      ],
    );
  }
}

// ── Collapsed profile row ─────────────────────────────────────────────────────

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    super.key,
    required this.name,
    required this.role,
    required this.profileUrl,
    required this.unreadCount,
    required this.onSearchTap,
  });

  final String name;
  final String role;
  final String? profileUrl;
  final int unreadCount;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Avatar ─────────────────────────────────────────────────
        GestureDetector(
          onTap: () => context.go('/profile'),
          child: Container(
            width: DSIconSize.heroSm,
            height: DSIconSize.heroSm,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).brightness == Brightness.dark
                  ? DSColors.secondarySurfaceDark
                  : DSColors.secondarySurfaceLight,
              border: Border.all(
                color: DSColors.primary.withValues(alpha: DSStyles.alphaMuted),
                width: DSStyles.strokeWidth,
              ),
              boxShadow: [
                BoxShadow(
                  color: DSColors.black.withValues(alpha: DSStyles.alphaSubtle),
                  blurRadius: DSStyles.radiusSM,
                  offset: const Offset(0, DSSpacing.xs),
                ),
              ],
            ),
            child: ClipOval(
              child: profileUrl != null && profileUrl!.isNotEmpty
                  ? Image.network(
                      profileUrl!,
                      width: DSIconSize.heroSm,
                      height: DSIconSize.heroSm,
                      fit: BoxFit.cover,
                      // Graceful offline / broken-URL fallback.
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.person_rounded,
                        size: DSIconSize.xl,
                        color: DSColors.labelSecondary,
                      ),
                    )
                  : const Icon(
                      Icons.person_rounded,
                      size: DSIconSize.xl,
                      color: DSColors.labelSecondary,
                    ),
            ),
          ),
        ),
        DSSpacing.wMd,

        // ── Name + role ─────────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: DSTypography.label().copyWith(
                  fontSize: DSTypography.sizeMd,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  height: DSStyles.heightTight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              DSSpacing.hXs,
              Text(
                role,
                style:
                    DSTypography.caption(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? DSColors.labelSecondaryDark
                          : DSColors.labelSecondary,
                    ).copyWith(
                      fontSize: DSTypography.sizeSm,
                      fontWeight: FontWeight.w500,
                      height: DSStyles.heightTight,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // ── Search icon ──────────────────────────────────────────────
        _HeaderIconButton(
          icon: Icons.search_rounded,
          onTap: () {
            HapticFeedback.lightImpact();
            onSearchTap();
          },
        ),
        DSSpacing.wSm,

        // ── Notification bell ────────────────────────────────────────
        NotificationBell(
          unreadCount: unreadCount,
          onTap: () => context.push('/notifications'),
        ),
        DSSpacing.wXs,
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: DSIconSize.heroSm,
        height: DSIconSize.heroSm,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(DSStyles.radiusMD),
          boxShadow: [
            BoxShadow(
              color: DSColors.black.withValues(alpha: DSStyles.alphaSoft),
              blurRadius: DSStyles.radiusSM * 0.75,
              offset: const Offset(0, DSSpacing.xs),
            ),
          ],
        ),
        child: Icon(icon, size: DSIconSize.lg, color: Theme.of(context).iconTheme.color),
      ),
    );
  }
}
