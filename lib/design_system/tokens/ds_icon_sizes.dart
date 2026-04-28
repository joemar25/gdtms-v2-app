import 'package:fsi_courier_app/design_system/tokens/ds_typography.dart';

/// Design-system icon size tokens.
/// 
/// Linked to [DSTypography] scale to ensure visual rhythm
/// when icons are paired with text.
class DSIconSize {
  /// Extra-extra-small (micro badges, inline indicators)
  /// ~10.2px
  static const double xxs = DSTypography.sizeXs * 0.85;

  /// Extra-small (secondary metadata indicators)
  /// 12.0px
  static const double xs = DSTypography.sizeXs;

  /// Small (subtitles, list item secondary actions)
  /// 16.0px
  static const double sm = DSTypography.sizeSm + 2;

  /// Medium (body icons, standard action icons)
  /// 18.0px
  static const double md = DSTypography.sizeMd * 1.125;

  /// Large (header icons, primary action buttons)
  /// 22.0px
  static const double lg = DSTypography.sizeXl + 2;

  /// Extra-large (prominent header icons, avatars)
  /// 24.0px
  static const double xl = DSTypography.sizeXl * 1.2;

  /// Double-extra-large (hero avatars, success/error states)
  /// 32.0px
  static const double xxl = DSTypography.sizeXl * 1.6;

  /// Hero (empty state icons, large banners)
  /// 48.0px
  static const double hero = DSTypography.sizeXl * 2.4;

  /// Massive Hero (security gates, critical failure screens)
  /// 64.0px
  static const double heroLarge = DSTypography.sizeXl * 3.2;
}
