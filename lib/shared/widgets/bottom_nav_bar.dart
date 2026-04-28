// DOCS: docs/shared/widgets.md — update that file when you edit this one.

import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

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

    // Use padding to create the floating effect
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          DSSpacing.lg,
          0,
          DSSpacing.lg,
          bottomPadding > 0 ? bottomPadding : DSSpacing.base,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: DSColors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                  blurRadius: DSSpacing.lg,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: DSStyles.circularRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: backgroundColor.withValues(
                      alpha: isDark ? 0.85 : 0.92,
                    ),
                    borderRadius: DSStyles.circularRadius,
                    border: Border.all(
                      color: borderColor.withValues(
                        alpha: DSStyles.alphaBorder,
                      ),
                      width: 0.5,
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final tabWidth = constraints.maxWidth / 3;
                      final currentIdx = navigationShell.currentIndex;

                      return Stack(
                        children: [
                          // ── Sliding Indicator (Pill) ───────────────────────
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutQuart,
                            left: tabWidth * currentIdx + (tabWidth * 0.1),
                            top: 8,
                            child: Container(
                              width: tabWidth * 0.8,
                              height: 48,
                              decoration: BoxDecoration(
                                color: activeColor.withValues(
                                  alpha: DSStyles.alphaSoft,
                                ),
                                borderRadius: DSStyles.cardRadius,
                              ),
                            ),
                          ),

                          // ── Nav Items ──────────────────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _NavBarItem(
                                index: 0,
                                selectedIndex: currentIdx,
                                icon: Icons.home_outlined,
                                selectedIcon: Icons.home_rounded,
                                label: 'Home',
                                activeColor: activeColor,
                                inactiveColor: inactiveColor,
                                onTap: () => _onTap(0),
                              ),
                              _NavBarItem(
                                index: 1,
                                selectedIndex: currentIdx,
                                icon: Icons.account_balance_wallet_outlined,
                                selectedIcon:
                                    Icons.account_balance_wallet_rounded,
                                label: 'Wallet',
                                activeColor: activeColor,
                                inactiveColor: inactiveColor,
                                onTap: () => _onTap(1),
                              ),
                              _NavBarItem(
                                index: 2,
                                selectedIndex: currentIdx,
                                icon: Icons.person_outline_rounded,
                                selectedIcon: Icons.person_rounded,
                                label: 'Profile',
                                activeColor: activeColor,
                                inactiveColor: inactiveColor,
                                onTap: () => _onTap(2),
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

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.index,
    required this.selectedIndex,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final int index;
  final int selectedIndex;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = index == selectedIndex;
    final color = isSelected ? activeColor : inactiveColor;

    return Expanded(
      child: InkWell(
        onTap: isSelected ? null : onTap,
        splashColor: DSColors.transparent,
        highlightColor: DSColors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSelected ? selectedIcon : icon, color: color, size: DSTypography.sizeLg * 1.5),
            const SizedBox(height: 4),
            Text(
              label,
              style: DSTypography.caption(color: color).copyWith(
                fontSize: DSTypography.sizeSm,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
