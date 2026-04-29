import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:lottie/lottie.dart';

import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

class SyncEmptyState extends StatefulWidget {
  const SyncEmptyState({super.key, required this.isSyncing});

  final bool isSyncing;

  @override
  State<SyncEmptyState> createState() => _SyncEmptyStateState();
}

class _SyncEmptyStateState extends State<SyncEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onLoaded(LottieComposition composition) {
    if (_loaded) return;
    _loaded = true;
    _controller.duration = composition.duration;
    _controller.forward().whenComplete(() {
      if (mounted) {
        _controller.value = 1.0;
      }
    });
  }

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
                if (widget.isSyncing) ...[
                  const SpinKitDoubleBounce(
                    color: DSColors.primary,
                    size: DSIconSize.heroMd,
                  ),
                  DSSpacing.hMd,
                  Text(
                    'sync.actions.syncing'.tr(),
                    style: DSTypography.heading().copyWith(
                      fontSize: DSTypography.sizeMd,
                    ),
                  ),
                ] else ...[
                  Lottie.asset(
                    AppAssets.animSuccess,
                    width: DSIconSize.lg,
                    height: DSIconSize.heroMd * 2.0,
                    controller: _controller,
                    onLoaded: _onLoaded,
                  ),
                  DSSpacing.hMd,
                  Text(
                    'sync.empty.all_caught_up'.tr(),
                    style: DSTypography.heading().copyWith(
                      fontSize: DSTypography.sizeMd,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  DSSpacing.hSm,
                  Text(
                    'sync.empty.no_pending'.tr(),
                    style: DSTypography.body(
                      color: DSColors.labelTertiary,
                    ),
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
