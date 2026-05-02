import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:fsi_courier_app/design_system/design_system.dart';

class SyncEmptyState extends StatelessWidget {
  const SyncEmptyState({super.key, required this.isSyncing});

  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    // Must be scrollable for RefreshIndicator to work.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: DSSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSyncing) ...[
                  const SpinKitDoubleBounce(
                    color: DSColors.primary,
                    size: DSIconSize.heroMd,
                  ),
                  DSSpacing.hMd,
                  Text(
                    'sync.actions.syncing'.tr(),
                    style: DSTypography.heading(fontSize: DSTypography.sizeMd),
                  ),
                ] else ...[
                  Icon(
                        Icons.check_circle_rounded,
                        color: DSColors.success,
                        size: DSIconSize.heroMd,
                      )
                      .animate()
                      .scale(duration: 500.ms, curve: Curves.easeOutBack)
                      .fadeIn(),
                  DSSpacing.hMd,
                  Text(
                    'sync.empty.all_caught_up'.tr(),
                    style: DSTypography.heading(
                      fontSize: DSTypography.sizeMd,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  DSSpacing.hSm,
                  Text(
                    'sync.empty.no_pending'.tr(),
                    style: DSTypography.body(color: DSColors.labelTertiary),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
