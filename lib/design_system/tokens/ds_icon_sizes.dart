// DOCS: docs/development-standards.md

/// Design-system icon size tokens.
///
/// STABILITY RULE: Only 3 to 5 standard tiers allowed per category.
/// REJECT any new tier requests that exceed this scale.
class DSIconSize {
  /// Extra-small (micro badges, inline indicators)
  static const double xs = 14.0;

  /// Small (subtitles, list item secondary actions)
  static const double sm = 16.0;

  /// Medium (body icons, standard action icons)
  static const double md = 20.0;

  /// Large (header icons, primary action buttons)
  static const double lg = 24.0;

  /// Extra-large (hero icons, success/error states, avatars)
  static const double xl = 32.0;

  // ── Hero Variants (Calculations in Config) ──────────────────────────────
  static const double heroSm = 48.0;
  static const double heroMd = 80.0;
  static const double heroLg = 240.0; // Splash only
}
