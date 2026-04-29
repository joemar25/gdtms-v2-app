// DOCS: docs/development-standards.md
// DOCS: docs/shared/widgets.md — update that file when you edit this one.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:easy_localization/easy_localization.dart';

/// A modern, premium floating navigation bar with a sliding pill indicator.
///
/// This version is used for manual navigation path management.
/// For StatefulNavigationShell integration, use [AppBottomNavBar].
class FloatingBottomNavBar extends StatelessWidget {
  const FloatingBottomNavBar({super.key, required this.currentPath});

  final String currentPath;

  int get _index {
    if (currentPath.startsWith('/wallet')) return 1;
    if (currentPath.startsWith('/profile')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? DSColors.cardDark : DSColors.cardLight;
    final borderColor = isDark
        ? DSColors.separatorDark
        : DSColors.separatorLight;
    final activeColor = DSColors.primary;
    final inactiveColor = isDark
        ? DSColors.labelSecondaryDark
        : DSColors.labelSecondary;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          DSSpacing.lg,
          0,
          DSSpacing.lg,
          MediaQuery.paddingOf(context).bottom + DSSpacing.md,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: DSColors.black.withValues(
                    alpha: isDark ? DSStyles.alphaMuted : DSStyles.alphaSoft,
                  ),
                  blurRadius: DSSpacing.lg,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: DSStyles.circularRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: backgroundColor.withValues(
                      alpha: isDark ? DSStyles.alphaSoft : DSStyles.alphaOpaque,
                    ),
                    borderRadius: DSStyles.circularRadius,
                    border: Border.all(
                      color: borderColor.withValues(
                        alpha: DSStyles.alphaSubtle,
                      ),
                      width: DSStyles.borderWidth,
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final tabWidth = constraints.maxWidth / 3;
                      final currentIdx = _index;

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // ── Elastic Sliding Pill ──────────────────────────
                          AnimatedAlign(
                            alignment: Alignment(
                              -1.0 + (2.0 * currentIdx / (3 - 1)),
                              0,
                            ),
                            duration: DSAnimations.dNormal,
                            curve: DSAnimations.curveElasticPill,
                            child: FractionallySizedBox(
                              widthFactor: 1 / 3,
                              heightFactor: 1.0,
                              child: Padding(
                                padding: EdgeInsets.all(DSSpacing.sm),
                                child: AnimatedContainer(
                                  duration: DSAnimations.dFast,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        activeColor,
                                        activeColor.withValues(
                                          alpha: DSStyles.alphaOpaque,
                                        ),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: DSStyles.cardRadius,
                                    boxShadow: [
                                      BoxShadow(
                                        color: activeColor.withValues(
                                          alpha: DSStyles.alphaMuted,
                                        ),
                                        blurRadius: DSStyles.radiusMD,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // ── Nav Items ──────────────────────────────────────
                          Row(
                            children: [
                              _NavItem(
                                index: 0,
                                currentIndex: currentIdx,
                                icon: Icons.home_outlined,
                                activeIcon: Icons.home_rounded,
                                label: 'nav.home'.tr(),
                                activeColor: DSColors.white,
                                inactiveColor: inactiveColor,
                                onTap: () =>
                                    _handleNavigation(context, '/dashboard', 0),
                              ),
                              _NavItem(
                                index: 1,
                                currentIndex: currentIdx,
                                icon: Icons.account_balance_wallet_outlined,
                                activeIcon:
                                    Icons.account_balance_wallet_rounded,
                                label: 'nav.wallet'.tr(),
                                activeColor: DSColors.white,
                                inactiveColor: inactiveColor,
                                onTap: () =>
                                    _handleNavigation(context, '/wallet', 1),
                              ),
                              _NavItem(
                                index: 2,
                                currentIndex: currentIdx,
                                icon: Icons.person_outline_rounded,
                                activeIcon: Icons.person_rounded,
                                label: 'nav.profile'.tr(),
                                activeColor: DSColors.white,
                                inactiveColor: inactiveColor,
                                onTap: () =>
                                    _handleNavigation(context, '/profile', 2),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleNavigation(BuildContext context, String route, int index) {
    if (index != _index) {
      HapticFeedback.selectionClick();
      context.go(route);
    }
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = index == currentIndex;
    final color = isSelected ? activeColor : inactiveColor;

    return Expanded(
      child: InkWell(
        onTap: isSelected ? null : onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isSelected
                  ? DSAnimations.scaleActive
                  : DSAnimations.scaleNormal,
              duration: DSAnimations.dFast,
              curve: DSAnimations.curveIconPop,
              child: Icon(
                isSelected ? activeIcon : icon,
                color: color,
                size: isSelected ? DSIconSize.xl : DSIconSize.lg,
              ),
            ),
            AnimatedContainer(
              duration: DSAnimations.dFast,
              height: isSelected ? 0 : 16,
              child: AnimatedOpacity(
                duration: DSAnimations.dFast,
                opacity: isSelected ? 0.0 : 1.0,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: AnimatedDefaultTextStyle(
                    duration: DSAnimations.dFast,
                    style: DSTypography.label(color: color).copyWith(
                      fontSize: DSTypography.sizeXs,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                    child: Text(label),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
