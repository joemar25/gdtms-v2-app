import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/shared/widgets/empty_state.dart';

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
                  EmptyState(
                    message: 'sync.empty.all_caught_up'.tr(),
                    subMessage: 'sync.empty.no_pending'.tr(),
                    icon: Icons.check_circle_rounded,
                    iconColor: DSColors.success,
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
