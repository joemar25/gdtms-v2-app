// DOCS: docs/development-standards.md
// DOCS: docs/shared/widgets.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

/// Wraps [child] and overlays a semi-transparent loading spinner when
/// [isLoading] is true. Used on screens that perform async operations
/// (e.g. profile save, payout submit) to block interaction during the request.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  final bool isLoading;
  final Widget child;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: DSColors.black.withValues(alpha: DSStyles.alphaDisabled),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: DSIconSize.heroSm,
                    height: DSIconSize.heroSm,
                    child: SpinKitFadingCircle(
                      color: DSColors.white,
                      size: DSIconSize.heroSm,
                    ),
                  ),
                  if (message != null) ...[
                    DSSpacing.hMd,
                    Text(
                      message!,
                      style: DSTypography.body(color: DSColors.white).copyWith(
                        fontSize: DSTypography.sizeMd,
                        fontWeight: FontWeight.w600,
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
