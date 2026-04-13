// DOCS: docs/shared/widgets.md — update that file when you edit this one.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/styles/color_styles.dart';

class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? ColorStyles.appBarDark
        : ColorStyles.appBarLight;
    final borderColor = isDark
        ? ColorStyles.separatorDark
        : ColorStyles.separatorLight;
    final activeColor = ColorStyles.grabGreen;
    final inactiveColor = isDark
        ? ColorStyles.labelSecondaryDark
        : ColorStyles.labelSecondary;

    // Use padding to create the floating effect
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          bottomPadding > 0 ? bottomPadding : 16,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: backgroundColor.withValues(
                      alpha: isDark ? 0.85 : 0.92,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: borderColor.withValues(alpha: 0.5),
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
                                color: activeColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
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
        splashColor: ColorStyles.transparent,
        highlightColor: ColorStyles.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSelected ? selectedIcon : icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
