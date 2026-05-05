import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/widgets/update_card_widget.dart';
import 'package:go_router/go_router.dart';

class UpdateScreen extends StatelessWidget {
  const UpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? DSColors.scaffoldDark : DSColors.scaffoldLight,
      appBar: AppHeaderBar(
        title: 'App Update',
        pageIcon: Icons.system_update_rounded,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/login');
            }
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(DSSpacing.md),
        children: [
          const SizedBox(height: DSSpacing.lg),
          Center(
            child: Icon(
              Icons.system_update_rounded,
              size: DSIconSize.heroMd,
              color: isDark ? DSColors.warningDark : DSColors.warning,
            ),
          ),
          const SizedBox(height: DSSpacing.xl),
          Text(
            'Stay Up to Date',
            style: DSTypography.heading(
              color: isDark ? DSColors.white : DSColors.labelPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DSSpacing.sm),
          Text(
            'We have released a new version of the FSI Courier app with improvements and bug fixes.',
            style: DSTypography.body(
              color: isDark
                  ? DSColors.labelSecondaryDark
                  : DSColors.labelSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DSSpacing.xl),
          AppUpdateCard(isDark: isDark),
        ],
      ),
    );
  }
}
