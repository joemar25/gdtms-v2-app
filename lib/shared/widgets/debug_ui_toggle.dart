// DOCS: docs/development-standards.md
// DOCS: docs/core/settings.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/settings/debug_ui_provider.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/shared/router/router_keys.dart';

/// Floating chip: opens develop shortcuts. Mounted from [MaterialApp.builder].
///
/// Visibility follows [debugToolsProvider] (not [showDebugUiProvider]) so the
/// chip still appears when chrome is off — including release + developer mode
/// with a previously hidden preference.
///
/// Fixed footprint so DEBUG / UI labels never reflow the hit target. Drag to
/// park it anywhere on screen (clamped to safe area); tap opens shortcuts.
///
/// **Navigator note:** this widget is a *sibling* of the router `child` inside
/// `MaterialApp.builder`, so it has no Navigator ancestor. Sheets and route
/// jumps must use [rootNavigatorKey] (not the chip's own context).
class DebugUiToggle extends ConsumerStatefulWidget {
  const DebugUiToggle({super.key});

  /// Wide enough for "DEBUG"; same size when label is "UI".
  static const double chipWidth = DSSpacing.huge + DSSpacing.md; // 80

  /// Comfortable tap target without dominating the corner.
  static const double chipHeight = DSSpacing.xl + DSSpacing.xs; // 36

  @override
  ConsumerState<DebugUiToggle> createState() => _DebugUiToggleState();
}

class _DebugUiToggleState extends ConsumerState<DebugUiToggle> {
  /// Top-left of chip in the full-screen [Stack]. Null until first drag or
  /// first layout uses the default corner.
  Offset? _pos;
  bool _dragging = false;

  Offset _defaultPos(MediaQueryData mq) =>
      Offset(DSSpacing.sm + mq.padding.left, mq.padding.top + DSSpacing.sm);

  Offset _clamp(Offset pos, Size size, EdgeInsets padding) {
    final minX = padding.left;
    final minY = padding.top;
    final maxX = size.width - DebugUiToggle.chipWidth - padding.right;
    final maxY = size.height - DebugUiToggle.chipHeight - padding.bottom;
    return Offset(
      pos.dx.clamp(minX, maxX < minX ? minX : maxX),
      pos.dy.clamp(minY, maxY < minY ? minY : maxY),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tools = ref.watch(debugToolsProvider);
    if (!tools) return const SizedBox.shrink();

    final chromeOn = ref.watch(debugUiProvider);
    final label = chromeOn ? 'DEBUG' : 'UI';
    final bg = chromeOn
        ? DSColors.warning
        : DSColors.black.withValues(alpha: 0.55);

    final mq = MediaQuery.of(context);
    final pos = _clamp(_pos ?? _defaultPos(mq), mq.size, mq.padding);

    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: GestureDetector(
        onPanStart: (_) {
          HapticFeedback.selectionClick();
          setState(() {
            _dragging = true;
            // Seed from rendered pos so first delta is relative to default.
            _pos ??= pos;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            final next = (_pos ?? pos) + details.delta;
            _pos = _clamp(next, mq.size, mq.padding);
          });
        },
        onPanEnd: (_) => setState(() => _dragging = false),
        onPanCancel: () => setState(() => _dragging = false),
        onTap: () {
          HapticFeedback.selectionClick();
          _openDevShortcuts(ref);
        },
        child: AnimatedOpacity(
          duration: DSAnimations.dFast,
          opacity: _dragging ? 0.92 : 1,
          child: Material(
            color: bg,
            elevation: _dragging ? DSStyles.elevationMD : DSStyles.elevationXS,
            shadowColor: DSColors.black.withValues(alpha: DSStyles.alphaMuted),
            borderRadius: DSStyles.fullRadius,
            child: SizedBox(
              width: DebugUiToggle.chipWidth,
              height: DebugUiToggle.chipHeight,
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: DSTypography.label(color: DSColors.white).copyWith(
                    fontSize: DSTypography.sizeSm,
                    fontWeight: FontWeight.w800,
                    letterSpacing: DSTypography.lsWide,
                    height: DSStyles.heightTight,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Context *under* the app [Navigator] (overlay), not the Navigator itself.
///
/// [GlobalKey.currentContext] on a Navigator key is the Navigator widget's
/// own element. [Navigator.of] only walks *ancestors*, so that context cannot
/// push/pop. Overlay is a descendant — sheets and [GoRouter] work from there.
BuildContext? _navHostContext() {
  final nav = rootNavigatorKey.currentState;
  if (nav == null) return null;
  // Prefer overlay (child of Navigator); fall back to any mounted nav context
  // that already has an ancestor Navigator (e.g. unit-test hosts).
  final overlayCtx = nav.overlay?.context;
  if (overlayCtx != null && overlayCtx.mounted) return overlayCtx;
  final ctx = rootNavigatorKey.currentContext;
  if (ctx != null && ctx.mounted && Navigator.maybeOf(ctx) != null) {
    return ctx;
  }
  return null;
}

void _go(String location) {
  final ctx = _navHostContext();
  if (ctx == null) return;
  GoRouter.of(ctx).go(location);
}

void _openDevShortcuts(WidgetRef ref) {
  final sheetHost = _navHostContext();
  if (sheetHost == null) {
    // Navigator / overlay not ready yet (very early boot).
    debugPrint('[DebugUiToggle] no Navigator host context for sheet');
    return;
  }

  final chromeOn = ref.read(debugUiProvider);
  final authed = ref.read(authProvider).isAuthenticated;

  showModalBottomSheet<void>(
    context: sheetHost,
    useRootNavigator: true,
    backgroundColor: DSColors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
      final surface = isDark ? DSColors.cardElevatedDark : DSColors.cardLight;
      final label = isDark ? DSColors.labelPrimaryDark : DSColors.labelPrimary;
      final muted = isDark
          ? DSColors.labelSecondaryDark
          : DSColors.labelSecondary;

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DSSpacing.md,
            DSSpacing.sm,
            DSSpacing.md,
            DSSpacing.md,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(DSStyles.radiusSheet),
              border: Border.all(
                color: isDark
                    ? DSColors.white.withValues(alpha: 0.08)
                    : DSColors.separatorLight,
                width: DSStyles.borderWidth,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DSSpacing.md,
                    DSSpacing.md,
                    DSSpacing.md,
                    DSSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DEV SHORTCUTS',
                        style: DSTypography.label(color: muted).copyWith(
                          fontSize: DSTypography.sizeXs,
                          fontWeight: FontWeight.w800,
                          letterSpacing: DSTypography.lsWide,
                        ),
                      ),
                      DSSpacing.hXs,
                      Text(
                        'Hard-to-reach screens for develop only',
                        style: DSTypography.caption(
                          color: muted,
                        ).copyWith(fontSize: DSTypography.sizeSm),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: DSStyles.borderWidth,
                  thickness: DSStyles.borderWidth,
                  color: isDark
                      ? DSColors.separatorDark
                      : DSColors.separatorLight,
                ),
                _DevShortcutTile(
                  icon: Icons.auto_awesome_motion_rounded,
                  label: 'Splash screen',
                  subtitle: 'Cold start / brand gate',
                  enabled: true,
                  labelColor: label,
                  mutedColor: muted,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _go('/splash');
                  },
                ),
                _DevShortcutTile(
                  icon: Icons.sync_rounded,
                  label: 'Initial sync',
                  subtitle: authed
                      ? 'Post-login bootstrap gate'
                      : 'Sign in required',
                  enabled: authed,
                  labelColor: label,
                  mutedColor: muted,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _go('/initial-sync');
                  },
                ),
                _DevShortcutTile(
                  icon: Icons.manage_accounts_rounded,
                  label: 'Edit profile',
                  subtitle: authed ? 'Profile edit form' : 'Sign in required',
                  enabled: authed,
                  labelColor: label,
                  mutedColor: muted,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _go('/profile/edit');
                  },
                ),
                Divider(
                  height: DSStyles.borderWidth,
                  thickness: DSStyles.borderWidth,
                  color: isDark
                      ? DSColors.separatorDark
                      : DSColors.separatorLight,
                ),
                _DevShortcutTile(
                  icon: chromeOn
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  label: chromeOn ? 'Hide debug chrome' : 'Show debug chrome',
                  subtitle: 'Toggle labels / API panels on screens',
                  enabled: true,
                  labelColor: label,
                  mutedColor: muted,
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await ref.read(debugUiProvider.notifier).toggle();
                  },
                ),
                DSSpacing.hSm,
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _DevShortcutTile extends StatelessWidget {
  const _DevShortcutTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.enabled,
    required this.labelColor,
    required this.mutedColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool enabled;
  final Color labelColor;
  final Color mutedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = enabled
        ? (Theme.of(context).brightness == Brightness.dark
              ? DSColors.primaryDark
              : DSColors.primary)
        : mutedColor;

    return Material(
      color: DSColors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : DSStyles.alphaDisabled,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DSSpacing.md,
              vertical: DSSpacing.sm + 2,
            ),
            child: Row(
              children: [
                Container(
                  width: DSIconSize.heroSm,
                  height: DSIconSize.heroSm,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: DSStyles.alphaSubtle),
                    borderRadius: DSStyles.cardRadius,
                  ),
                  child: Icon(icon, size: DSIconSize.md, color: accent),
                ),
                DSSpacing.wMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: DSTypography.body(color: labelColor).copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: DSTypography.sizeMd,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: DSTypography.caption(
                          color: mutedColor,
                        ).copyWith(fontSize: DSTypography.sizeSm),
                      ),
                    ],
                  ),
                ),
                if (enabled)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: DSIconSize.md,
                    color: mutedColor,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
