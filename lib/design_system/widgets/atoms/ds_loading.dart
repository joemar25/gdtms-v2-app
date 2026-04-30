// DOCS: docs/development-standards.md
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_colors.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_icon_sizes.dart';

/// DSLoading - Branded loading indicator atom.
///
/// Uses [SpinKitThreeBounce] to provide a consistent "premium" loading feel
/// across the application, replacing the generic [CircularProgressIndicator].
class DSLoading extends StatelessWidget {
  const DSLoading({
    super.key,
    this.size = DSIconSize.md,
    this.color = DSColors.primary,
  });

  /// The size of the loading indicator. Defaults to [DSIconSize.md].
  final double size;

  /// The color of the loading indicator. Defaults to [DSColors.primary].
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SpinKitThreeBounce(color: color, size: size);
  }
}
