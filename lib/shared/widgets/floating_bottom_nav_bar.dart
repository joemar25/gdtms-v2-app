// DOCS: docs/development-standards.md
// DOCS: docs/shared/widgets.md — update that file when you edit this one.

import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

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

    // iOS-style glass: semi-transparent bg layered over blur
    final glassBg = isDark
        ? DSColors.cardDark.withValues(alpha: DSStyles.alphaDisabled)
        : DSColors.white.withValues(alpha: DSStyles.alphaDisabled);

    final borderColor = isDark
        ? DSColors.white.withValues(alpha: DSStyles.alphaSoft)
        : DSColors.white.withValues(alpha: DSStyles.alphaMuted);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          DSSpacing.md,
          0,
          DSSpacing.md,
          DSSpacing.sm,
        ),
        child: ClipRRect(
          borderRadius: DSStyles.circularRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                color: glassBg,
                borderRadius: DSStyles.circularRadius,
                border: Border.all(
                  color: borderColor,
                  width: DSStyles.borderWidth,
                ),
                boxShadow: [
                  BoxShadow(
                    color: DSColors.black.withValues(
                      alpha: isDark ? 0.35 : 0.10,
                    ),
                    blurRadius: DSStyles.radiusXL * 1.33,
                    spreadRadius: -4,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: DSSpacing.sm,
                  horizontal: DSSpacing.sm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label: 'Home',
                      isSelected: _index == 0,
                      onTap: () => context.go('/dashboard'),
                    ),
                    _NavItem(
                      icon: Icons.account_balance_wallet_outlined,
                      activeIcon: Icons.account_balance_wallet_rounded,
                      label: 'Wallet',
                      isSelected: _index == 1,
                      onTap: () => context.go('/wallet'),
                    ),
                    _NavItem(
                      icon: Icons.person_outline,
                      activeIcon: Icons.person_rounded,
                      label: 'Profile',
                      isSelected: _index == 2,
                      onTap: () => context.go('/profile'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.88,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _controller.forward();

  void _onTapUp(TapUpDetails _) {
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final color = widget.isSelected
        ? DSColors.primary
        : DSColors.labelSecondary;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(
            horizontal: DSSpacing.lg,
            vertical: DSSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? DSColors.primary.withValues(alpha: DSStyles.alphaSubtle)
                : DSColors.transparent,
            borderRadius: DSStyles.cardRadius,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(
                  widget.isSelected ? widget.activeIcon : widget.icon,
                  key: ValueKey(widget.isSelected),
                  color: color,
                  size: DSIconSize.xl,
                ),
              ),
              DSSpacing.hXs,
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: DSTypography.label().copyWith(
                  fontSize: DSTypography.sizeXs,
                  fontWeight: widget.isSelected
                      ? FontWeight.w700
                      : FontWeight.w400,
                  color: color,
                ),
                child: Text(widget.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
