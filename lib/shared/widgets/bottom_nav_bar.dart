// DOCS: docs/development-standards.md
// DOCS: docs/shared/widgets.md — update that file when you edit this one.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fsi_courier_app/core/providers/update_provider.dart';

class AppBottomNavBar extends ConsumerWidget {
  const AppBottomNavBar({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Primary glass bar + white sliding pill (active) + primary icons on pill.
    final pillColor = DSColors.white;
    final activeColor = DSColors.primary;
    final inactiveColor = DSGlass.onChromeInactive(context);

    // Watch update state to show badge on Profile tab
    final hasUpdate = ref.watch(updateProvider.select((s) => s.hasUpdate));

    // Use padding to create the floating effect
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          DSSpacing.lg,
          0,
          DSSpacing.lg,
          bottomPadding > 0 ? bottomPadding : DSSpacing.md,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SizedBox(
            height: DSGlass.chromeHeight,
            child: DSGlassChrome(
              edge: DSGlassChromeEdge.floating,
              borderRadius: DSStyles.circularRadius,
              showBorder: true,
              boxShadow: true,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final currentIdx = navigationShell.currentIndex;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // ── Elastic Sliding Pill ──────────────────────────
                      AnimatedAlign(
                        alignment: Alignment(
                          -1.0 + (2.0 * currentIdx / (4 - 1)),
                          0,
                        ),
                        duration: DSAnimations.dNormal,
                        curve: DSAnimations.curveElasticPill,
                        child: FractionallySizedBox(
                          widthFactor: 1 / 4,
                          heightFactor: 1.0,
                          child: Padding(
                            padding: EdgeInsets.all(DSSpacing.sm),
                            child: AnimatedContainer(
                              duration: DSAnimations.dFast,
                              decoration: BoxDecoration(
                                color: pillColor,
                                borderRadius: DSStyles.cardRadius,
                                boxShadow: [
                                  BoxShadow(
                                    color: DSColors.black.withValues(
                                      alpha: DSStyles.alphaSubtle,
                                    ),
                                    blurRadius: DSStyles.radiusMD,
                                    offset: const Offset(0, DSSpacing.xs),
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
                          _NavBarItem(
                            index: 0,
                            selectedIndex: currentIdx,
                            icon: Icons.home_outlined,
                            activeIcon: Icons.home_rounded,
                            label: 'nav.home'.tr(),
                            activeColor: activeColor,
                            inactiveColor: inactiveColor,
                            onTap: () => _onTap(0),
                          ),
                          _NavBarItem(
                            index: 1,
                            selectedIndex: currentIdx,
                            icon: Icons.inventory_2_outlined,
                            activeIcon: Icons.inventory_2_rounded,
                            label: 'nav.bagsakan'.tr(),
                            activeColor: activeColor,
                            inactiveColor: inactiveColor,
                            onTap: () => _onTap(1),
                          ),
                          _NavBarItem(
                            index: 2,
                            selectedIndex: currentIdx,
                            icon: Icons.account_balance_wallet_outlined,
                            activeIcon: Icons.account_balance_wallet_rounded,
                            label: 'nav.wallet'.tr(),
                            activeColor: activeColor,
                            inactiveColor: inactiveColor,
                            onTap: () => _onTap(2),
                          ),
                          _NavBarItem(
                            index: 3,
                            selectedIndex: currentIdx,
                            icon: Icons.person_outline_rounded,
                            activeIcon: Icons.person_rounded,
                            label: 'nav.profile'.tr(),
                            activeColor: activeColor,
                            inactiveColor: inactiveColor,
                            showBadge: hasUpdate,
                            onTap: () => _onTap(3),
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
    );
  }

  void _onTap(int index) {
    if (index != navigationShell.currentIndex) {
      HapticFeedback.selectionClick();
      navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );
    }
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.index,
    required this.selectedIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
    this.showBadge = false,
  });

  final int index;
  final int selectedIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;
  final bool showBadge;

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
            Stack(
              clipBehavior: Clip.none,
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
                if (showBadge)
                  Positioned(
                    top: -2,
                    right: -2,
                    child:
                        Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: DSColors.error,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? DSColors.white
                                      : DSGlass.fill(
                                          context,
                                          tone: DSGlassTone.chrome,
                                        ),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: DSColors.error.withValues(
                                      alpha: DSStyles.alphaMuted,
                                    ),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            )
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .scale(
                              begin: const Offset(1, 1),
                              end: const Offset(1.2, 1.2),
                              duration: const Duration(milliseconds: 1200),
                              curve: Curves.easeInOut,
                            ),
                  ),
              ],
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
