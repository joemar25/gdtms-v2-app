import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_styles.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_colors.dart';

/// Backwards-compat shim for legacy UIStyles / ColorStyles usages.
/// Maps old names to the new design-system tokens so transitional files
/// compile until all references are migrated.
class UIStyles {
  // Border radii
  static final BorderRadius cardRadius = DSStyles.cardRadius;
  static final BorderRadius pillRadius = DSStyles.pillRadius;

  // Alpha tokens
  static const double alphaSoft = DSStyles.alphaSoft;
  static const double alphaActiveAccent = DSStyles.alphaActiveAccent;
  static const double alphaBorder = DSStyles.alphaBorder;
  static const double alphaDarkShadow = DSStyles.alphaDarkShadow;
  static const double alphaGlass = DSStyles.alphaGlass;
}

class ColorStyles {
  // Transitional color tokens — choose closest semantic equivalents.
  static const Color grabOrange = Color(0xFFFF6E00);
  static const Color primary = DSColors.primary;
  static const Color scaffoldLight = DSColors.scaffoldLight;
}
