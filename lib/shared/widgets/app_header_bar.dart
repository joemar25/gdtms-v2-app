// DOCS: docs/development-standards.md
// DOCS: docs/shared/widgets.md — update that file when you edit this one.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/config.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/providers/notifications_provider.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/shared/widgets/scan_mode_sheet.dart';
import 'package:fsi_courier_app/utils/formatters.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
    this.showProfileAvatar = false,
    this.isPersonalized = false,
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
  final bool showProfileAvatar;
  final bool isPersonalized;

  @override
  Size get preferredSize =>
      Size.fromHeight(72 + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(notificationsUnreadCountProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerColor = backgroundColor ??
        (isDark ? DSColors.cardDark : DSColors.white);
    final courier = ref.watch(authProvider).courier ?? {};
    final profileUrlStr = courier['profile_picture_url']?.toString();
    final profileUrl = (profileUrlStr == null || profileUrlStr == 'null')
        ? null
        : profileUrlStr;

    final appBar = AppBar(
      scrolledUnderElevation: 0,
      elevation: 0,
      backgroundColor: backgroundColor ?? DSColors.transparent,
      surfaceTintColor: DSColors.transparent,
      titleSpacing: (leading == null && !context.canPop()) ? 16 : 0,
      centerTitle: centerTitle,
      leading: leading ??
          (context.canPop()
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  iconSize: DSIconSize.lg,
                  color: isDark
                      ? DSColors.labelPrimaryDark
                      : DSColors.labelPrimary,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    context.pop();
                  },
                ).animate().fadeIn(duration: DSAnimations.dFast)
              : null),
      leadingWidth: 56,
      title:
          titleWidget ??
          (isPersonalized
              ? _PersonalizedTitle(
                  title: title ?? '',
                  name: _formatName(courier),
                  isDark: isDark,
                )
              : Text(
                  title ?? '',
                  overflow: TextOverflow.ellipsis,
                  style: DSTypography.heading(
                    color: isDark
                        ? DSColors.labelPrimaryDark
                        : DSColors.labelPrimary,
                  ).copyWith(letterSpacing: DSTypography.lsSlightlyTight),
                ).animate().fadeIn(duration: DSAnimations.dFast)),
      toolbarHeight: 72,
      bottom: bottom,
      actions: [
        ...(actions ?? []),
        if (showNotificationBell)
          NotificationBell(
            unreadCount: unreadCount,
            onTap: () => context.push('/notifications'),
          ),
        if (showProfileAvatar && !isPersonalized) ...[
          DSSpacing.wSm,
          _HeaderProfileAvatar(profileUrl: profileUrl),
        ],
        ...(trailingActions ?? []),
        DSSpacing.wMd,
      ],
    );

    final content = heroTag != null
        ? Hero(
            tag: heroTag!,
            child: Material(color: DSColors.transparent, child: appBar),
          )
        : appBar;

    return Container(
      decoration: BoxDecoration(
        color: headerColor,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? DSColors.separatorDark.withValues(alpha: DSStyles.alphaMuted)
                : DSColors.separatorLight.withValues(alpha: DSStyles.alphaDisabled),
            width: 0.5,
          ),
        ),
        boxShadow: [
          if (backgroundColor != null &&
              backgroundColor != DSColors.transparent)
            BoxShadow(
              color: DSColors.black.withValues(alpha: DSStyles.alphaSoft),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: content,
    );
  }

  String _formatName(Map<String, dynamic> courier) {
    final firstName = courier['first_name']?.toString();
    final lastName = courier['last_name']?.toString();
    final nameStr = [
      if (firstName != null && firstName != 'null') firstName,
      if (lastName != null && lastName != 'null') lastName,
    ].join(' ').trim();

    return nameStr.isEmpty ? 'dashboard.profile.default_name'.tr() : nameStr;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label: 'nav.notifications'.tr(),
      value: hasUnread
          ? 'notifications.unread_count'.tr(namedArgs: {'count': label})
          : 'notifications.none'.tr(),
      button: true,
      child: _HeaderIconButton(
        icon: hasUnread
            ? Icons.notifications_rounded
            : Icons.notifications_outlined,
        onTap: onTap,
        iconColor: isDark ? DSColors.labelPrimaryDark : DSColors.labelPrimary,
        badge: hasUnread ? label : null,
        isFlat: true,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isSingle = label.length == 1;

    return Container(
      height: DSIconSize.sm,
      constraints: const BoxConstraints(minWidth: DSIconSize.sm),
      padding: EdgeInsets.symmetric(
        horizontal: isSingle ? 0 : DSSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: DSColors.error,
        borderRadius: BorderRadius.circular(DSStyles.radiusSM),
        boxShadow: [
          BoxShadow(
            color: DSColors.error.withValues(alpha: DSStyles.alphaMuted),
            blurRadius: DSStyles.radiusXS,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: DSTypography.label(color: DSColors.white).copyWith(
          fontSize: DSTypography.sizeXs - 1,
          fontWeight: FontWeight.w800,
          height: 1.1,
          letterSpacing: -0.2,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = ref.watch(authProvider);
    final courier = auth.courier ?? {};
    final firstName = courier['first_name']?.toString();
    final lastName = courier['last_name']?.toString();
    final nameStr = [
      if (firstName != null && firstName != 'null') firstName,
      if (lastName != null && lastName != 'null') lastName,
    ].join(' ').trim();

    final name = nameStr.isEmpty
        ? 'dashboard.profile.default_name'.tr()
        : nameStr;

    // mar-note: this is necessary change since not all courier has email and to be considered all as FREELANCE COURIER
    // final email = courier['email']?.toString();
    // final role = email != null && email.isNotEmpty
    //     ? email
    //     : 'Freelance Courier';
    final role = 'dashboard.profile.role_freelance'.tr();
    final profileUrlStr = courier['profile_picture_url']?.toString();
    final profileUrl = (profileUrlStr == null || profileUrlStr == 'null')
        ? null
        : profileUrlStr;
    final unreadCount = ref.watch(notificationsUnreadCountProvider);

    final headerColor = isDark ? DSColors.cardDark : DSColors.white;

    return Container(
      decoration: BoxDecoration(
        color: headerColor,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? DSColors.separatorDark.withValues(alpha: DSStyles.alphaMuted)
                : DSColors.separatorLight.withValues(alpha: DSStyles.alphaDisabled),
            width: 0.5,
          ),
        ),
      ),
      child: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: DSColors.transparent,
        surfaceTintColor: DSColors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        toolbarHeight: 72,
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
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
        IconButton(
          icon: const Icon(Icons.close_rounded),
          iconSize: DSIconSize.xl,
          color: cs.onSurface,
          onPressed: onCollapse,
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
                hintText: 'dashboard.search.placeholder'.tr(),
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
                    color: DSColors.primary.withValues(
                      alpha: DSStyles.alphaDisabled,
                    ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        // ── Avatar ─────────────────────────────────────────────────
        _HeaderAvatar(profileUrl: profileUrl),
        DSSpacing.wMd,

        // ── Name + role ─────────────────────────────────────────────
        Expanded(
          child: _PersonalizedTitle(
            title: AppFormatters.greeting(),
            name: name,
            isDark: isDark,
          ),
        ),

        // ── Search icon ──────────────────────────────────────────────
        if (kEnableGlobalSearch) ...[
          _HeaderIconButton(
            icon: Icons.search_rounded,
            onTap: () {
              HapticFeedback.lightImpact();
              onSearchTap();
            },
          ),
          DSSpacing.wSm,
        ],

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

class _HeaderProfileAvatar extends StatelessWidget {
  const _HeaderProfileAvatar({required this.profileUrl});

  final String? profileUrl;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/profile'),
      child: Container(
        width: DSIconSize.xl,
        height: DSIconSize.xl,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).brightness == Brightness.dark
              ? DSColors.secondarySurfaceDark
              : DSColors.secondarySurfaceLight,
          border: Border.all(
            color: DSColors.primary.withValues(alpha: DSStyles.alphaMuted),
            width: 1.0,
          ),
        ),
        child: ClipOval(
          child: profileUrl != null && profileUrl!.isNotEmpty
              ? Image.network(
                  profileUrl!,
                  width: DSIconSize.xl,
                  height: DSIconSize.xl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.person_rounded,
                    size: DSIconSize.lg,
                    color: DSColors.labelSecondary,
                  ),
                )
              : const Icon(
                  Icons.person_rounded,
                  size: DSIconSize.lg,
                  color: DSColors.labelSecondary,
                ),
        ),
      ),
    ).animate().fadeIn(duration: DSAnimations.dFast);
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.badge,
    this.isFlat = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  final String? badge;
  final bool isFlat;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: DSIconSize.heroSm,
        height: DSIconSize.heroSm,
        decoration: isFlat
            ? null
            : BoxDecoration(
                color: isDark ? DSColors.cardElevatedDark : DSColors.cardLight,
                borderRadius: BorderRadius.circular(DSStyles.radiusMD),
                boxShadow: DSStyles.shadowXS(context),
              ),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Icon(
                icon,
                size: DSIconSize.lg,
                color: iconColor ??
                    (isDark ? DSColors.labelPrimaryDark : DSColors.labelPrimary),
              ),
            ),
            if (badge != null)
              Positioned(
                top: isFlat ? 4 : 2,
                right: isFlat ? 4 : 2,
                child: _Badge(label: badge!)
                    .animate(onPlay: (c) => c.repeat())
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.12, 1.12),
                      duration: 1000.ms,
                      curve: Curves.easeInOut,
                    )
                    .then()
                    .scale(
                      begin: const Offset(1.12, 1.12),
                      end: const Offset(1, 1),
                      duration: 1000.ms,
                      curve: Curves.easeInOut,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  const _HeaderAvatar({required this.profileUrl});

  final String? profileUrl;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
                  errorBuilder: (_, _, _) => const Icon(
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
    );
  }
}

class _PersonalizedTitle extends StatelessWidget {
  const _PersonalizedTitle({
    required this.title,
    required this.name,
    required this.isDark,
  });

  final String title;
  final String name;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style:
              DSTypography.caption(
                color: isDark
                    ? DSColors.labelSecondaryDark
                    : DSColors.labelSecondary,
              ).copyWith(
                fontWeight: FontWeight.w500,
                letterSpacing: DSTypography.lsLoose,
              ),
        ).animate().fadeIn(duration: DSAnimations.dFast),
        DSSpacing.hXs,
        Text(
          name,
          style: DSTypography.heading(
            color: isDark ? DSColors.labelPrimaryDark : DSColors.labelPrimary,
          ).copyWith(height: DSStyles.heightTight),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ).animate().fadeIn(duration: DSAnimations.dFast, delay: 50.ms),
      ],
    );
  }
}