// DOCS: docs/shared/widgets.md — update that file when you edit this one.

import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

/// Displays a bottom sheet for the FAB with two scan action options.
void showScanModeSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    // useRootNavigator: true ensures the modal is pushed onto the root
    // navigator and its barrier covers the entire screen — including the
    // floating bottom nav bar which lives in ScaffoldWithNavBar's
    // bottomNavigationBar (outside the branch navigator).
    useRootNavigator: true,
    backgroundColor: DSColors.transparent,
    // Use the builder's context (sheetCtx) for navigation so we never
    // touch the caller's potentially-deactivated context inside callbacks.
    builder: (sheetCtx) => _ScanModeSheet(
      onDispatch: () {
        sheetCtx.pop();
        sheetCtx.push('/scan', extra: {'mode': 'dispatch'});
      },
      onPod: () {
        sheetCtx.pop();
        sheetCtx.push('/scan', extra: {'mode': 'pod'});
      },
    ),
  );
}

class _ScanModeSheet extends StatelessWidget {
  const _ScanModeSheet({required this.onDispatch, required this.onPod});

  final VoidCallback onDispatch;
  final VoidCallback onPod;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? DSColors.cardDark : DSColors.cardLight;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DSStyles.radiusSheet),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        DSSpacing.xl,
        DSSpacing.md,
        DSSpacing.xl,
        DSSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: DSIconSize.heroSm,
              height: DSSpacing.xs,
              margin: EdgeInsets.only(bottom: DSSpacing.lg),
              decoration: BoxDecoration(
                color: isDark
                    ? DSColors.labelSecondaryDark.withValues(alpha: DSStyles.alphaMuted)
                    : DSColors.separatorLight,
                borderRadius: DSStyles.pillRadius,
              ),
            ),
          ),
          Text(
            'CHOOSE ACTION',
            style:
                DSTypography.label(
                  color: isDark
                      ? DSColors.labelSecondaryDark
                      : DSColors.labelSecondary,
                ).copyWith(
                  fontSize: DSTypography.sizeSm,
                  fontWeight: FontWeight.w700,
                  letterSpacing: DSTypography.lsExtraLoose,
                ),
          ),
          DSSpacing.hMd,
          _ActionTile(
            icon: Icons.qr_code_scanner_rounded,
            iconColor: DSColors.primary,
            title: 'Accept incoming dispatch',
            subtitle: 'Scan or enter a dispatch code',
            onTap: onDispatch,
          ),
          DSSpacing.hSm,
          _ActionTile(
            icon: Icons.inventory_2_outlined,
            iconColor: DSColors.error,
            title: 'Scan POD',
            subtitle: 'Scan a barcode to update status',
            onTap: onPod,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: DSColors.transparent,
      child: InkWell(
        borderRadius: DSStyles.cardRadius,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: DSSpacing.md,
            vertical: DSSpacing.md,
          ),
          decoration: BoxDecoration(
            color: isDark ? DSColors.cardElevatedDark : DSColors.cardLight,
            borderRadius: DSStyles.cardRadius,
          ),
          child: Row(
            children: [
              Container(
                width: DSSpacing.xs,
                height: DSSpacing.xs,
                decoration: BoxDecoration(
                  color: iconColor.withValues(
                    alpha: DSStyles.alphaSubtle,
                  ),
                  borderRadius: DSStyles.cardRadius,
                ),
                child: Icon(icon, color: iconColor, size: DSIconSize.lg),
              ),
              DSSpacing.wMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: DSTypography.label().copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: DSTypography.sizeMd,
                      ),
                    ),
                    DSSpacing.hXs,
                    Text(
                      subtitle,
                      style: DSTypography.caption(
                        color: isDark
                            ? DSColors.labelSecondaryDark
                            : DSColors.labelSecondary,
                      ).copyWith(fontSize: DSTypography.sizeSm),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: DSIconSize.xs,
                color: isDark
                    ? DSColors.labelSecondaryDark
                    : DSColors.labelSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
