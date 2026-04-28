// DOCS: docs/development-standards.md
import 'package:fsi_courier_app/design_system/tokens/ds_typography.dart';

/// Design-system icon size tokens.
///
/// STABILITY RULE: Only 3 to 5 standard tiers allowed per category.
/// REJECT any new tier requests that exceed this scale.
class DSIconSize {
  /// Extra-small (micro badges, inline indicators)
  static const double xs = DSTypography.sizeXs; // 12.0

  /// Small (subtitles, list item secondary actions)
  static const double sm = DSTypography.sizeSm; // 14.0

  /// Medium (body icons, standard action icons)
  static const double md = DSTypography.sizeMd; // 16.0

  /// Large (header icons, primary action buttons)
  static const double lg = DSTypography.sizeLg; // 18.0

  /// Extra-large (hero icons, success/error states, avatars)
  static const double xl = DSTypography.sizeXl; // 20.0

  // ── Hero Variants (Calculations in Config) ──────────────────────────────
  static const double heroSm = 48.0;
  static const double heroMd = 80.0;
  static const double heroLg = 240.0; // Splash only
}
