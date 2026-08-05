// DOCS: docs/development-standards.md

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/shared/widgets/update_card_widget.dart';

/// App update gate — reachable from login when a new version is required.
///
/// Quiet gate shell + glass card (same family as permissions / auth).
class UpdateScreen extends StatelessWidget {
  const UpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark
        ? DSColors.labelPrimaryDark
        : DSColors.labelPrimary;
    final muted = isDark
        ? DSColors.labelSecondaryDark
        : DSColors.labelSecondary;

    return DSGateShell(
      showThemeToggle: true,
      backdrop: DsBackdrop.gate,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/login');
                }
              },
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: DSIconSize.md,
                color: titleColor,
              ),
            ),
          ).animate().fadeIn(duration: DSAnimations.dFast),

          Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: DSColors.warning.withValues(
                      alpha: DSStyles.alphaSubtle,
                    ),
                    borderRadius: BorderRadius.circular(DSStyles.radius2XL),
                    border: Border.all(
                      color: DSColors.warning.withValues(alpha: 0.35),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: DSColors.warning.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.system_update_rounded,
                    size: DSIconSize.xl,
                    color: isDark ? DSColors.warningDark : DSColors.warning,
                  ),
                ),
              )
              .animate()
              .fadeIn(duration: DSAnimations.dNormal)
              .scale(
                begin: const Offset(0.85, 0.85),
                end: const Offset(1, 1),
                duration: DSAnimations.dHero,
                curve: Curves.easeOutBack,
              ),

          DSSpacing.hLg,

          Text(
                'Stay up to date',
                textAlign: TextAlign.center,
                style: DSTypography.heading(color: titleColor).copyWith(
                  fontSize: DSTypography.sizeXl,
                  fontWeight: FontWeight.w700,
                ),
              )
              .animate()
              .fadeIn(delay: 80.ms, duration: DSAnimations.dNormal)
              .slideY(begin: 0.1, end: 0, delay: 80.ms),

          DSSpacing.hSm,

          Text(
            'A new version of the app is ready, with fixes and improvements for deliveries.',
            textAlign: TextAlign.center,
            style: DSTypography.body(color: muted).copyWith(
              fontSize: DSTypography.sizeMd,
              height: DSStyles.heightRelaxed,
            ),
          ).animate().fadeIn(delay: 120.ms, duration: DSAnimations.dNormal),

          DSSpacing.hXl,

          DSGlassCard(child: AppUpdateCard(isDark: isDark))
              .animate()
              .fadeIn(delay: 160.ms, duration: DSAnimations.dSlow)
              .slideY(
                begin: 0.08,
                end: 0,
                delay: 160.ms,
                duration: DSAnimations.dSlow,
                curve: Curves.easeOutCubic,
              ),
        ],
      ),
    );
  }
}
