// DOCS: docs/development-standards.md
// DOCS: docs/features/bagsakan.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:go_router/go_router.dart';

class BagsakanScreen extends ConsumerStatefulWidget {
  const BagsakanScreen({super.key});

  @override
  ConsumerState<BagsakanScreen> createState() => _BagsakanScreenState();
}

class _BagsakanScreenState extends ConsumerState<BagsakanScreen> {
  double _horizontalDrag = 0.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) => _horizontalDrag += details.delta.dx,
      onHorizontalDragEnd: (details) {
        final dx = _horizontalDrag;
        _horizontalDrag = 0.0;
        final velocity = details.primaryVelocity ?? 0.0;
        if (dx.abs() > 60 || velocity.abs() > 300) {
          if (dx < 0 || velocity < 0) {
            // swipe left → Wallet
            context.go('/wallet', extra: {'_swipe': 'left'});
          } else {
            // swipe right → Home
            context.go('/dashboard', extra: {'_swipe': 'right'});
          }
        }
      },
      child: Scaffold(
        backgroundColor: isDark
            ? DSColors.scaffoldDark
            : DSColors.scaffoldLight,
        appBar: AppHeaderBar(
          title: 'nav.bagsakan'.tr(),
          pageIcon: Icons.inventory_2_rounded,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(DSSpacing.xl),
                decoration: BoxDecoration(
                  color: DSColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  size: DSIconSize.heroLg,
                  color: DSColors.primary,
                ),
              ),
              DSSpacing.hLg,
              Text(
                'Bagsakan',
                style: DSTypography.heading(
                  color: isDark
                      ? DSColors.labelPrimaryDark
                      : DSColors.labelPrimary,
                ),
              ),
              DSSpacing.hSm,
              Text(
                'Under Development',
                style: DSTypography.body(
                  color: isDark
                      ? DSColors.labelSecondaryDark
                      : DSColors.labelSecondary,
                ),
              ),
              DSSpacing.hXl,
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DSSpacing.lg,
                  vertical: DSSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: isDark ? DSColors.cardDark : DSColors.cardLight,
                  borderRadius: DSStyles.cardRadius,
                  border: Border.all(
                    color:
                        (isDark
                                ? DSColors.separatorDark
                                : DSColors.separatorLight)
                            .withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: DSIconSize.sm,
                      color: DSColors.primary,
                    ),
                    DSSpacing.wSm,
                    Text(
                      'This feature is coming soon!',
                      style: DSTypography.caption(
                        color: isDark
                            ? DSColors.labelSecondaryDark
                            : DSColors.labelSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
