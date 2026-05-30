// DOCS: docs/development-standards.md
// DOCS: docs/design-system.md — update that file when you edit this one.

import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Design-system animation tokens and presets.
///
/// All screen-entry animations are expressed through five named presets:
///   • heroEntry  — avatar / image pop-in (fadeIn + scale 90→100%)
///   • fieldEntry — form field slide-in from right (fadeIn + slideX)
///   • cardEntry  — card / section slide-in from below (fadeIn + slideY)
///   • ctaEntry   — primary button entrance (fadeIn + scaleXY 95→100%)
///   • fadeEntry  — plain fade for labels, spinners, misc
///
/// Stagger helpers produce consistent per-item delays:
///   DSAnimations.stagger(n)                      → n × 100 ms (forms, cards)
///   DSAnimations.stagger(n, step: staggerFine)   → n × 15 ms  (dense lists)
///   DSAnimations.stagger(n, step: staggerNormal) → n × 50 ms  (section labels)
class DSAnimations {
  DSAnimations._();

  // ── Standard durations ─────────────────────────────────────────────────────
  static const Duration dMicro = Duration(milliseconds: 150); // scale-in
  static const Duration dFast = Duration(milliseconds: 250); // fade-in
  static const Duration dNormal = Duration(milliseconds: 400); // fade-in-up
  static const Duration dSlow = Duration(
    milliseconds: 500,
  ); // shake, slide-down
  static const Duration dHero = Duration(milliseconds: 600); // scale-bounce

  // ── Stagger step sizes ─────────────────────────────────────────────────────
  /// 10 ms — micro transitions (e.g. checkbox check).
  static const Duration staggerMicro = Duration(milliseconds: 10);

  /// 15 ms — tight lists (e.g. notification rows).
  static const Duration staggerFine = Duration(milliseconds: 15);

  /// 50 ms — section labels and sub-headings.
  static const Duration staggerNormal = Duration(milliseconds: 50);

  /// 80 ms — cards, form fields, primary content (spec default).
  static const Duration staggerCoarse = Duration(milliseconds: 80);

  /// 200 ms — wide sections or major page blocks.
  static const Duration staggerWide = Duration(milliseconds: 200);

  // ── Standard Offsets ───────────────────────────────────────────────────────
  static const Offset slideXOffset = Offset(0.1, 0);
  static const Offset slideYOffset = Offset(0, 0.05);
  static const Offset scaleOffsetSmall = Offset(0.95, 0.95);
  static const Offset shadowOffsetHero = Offset(0, 16);

  // ── Standard Scale & Opacity ──────────────────────────────────────────────
  static const double scalePressed = 0.95;
  static const double scaleNormal = 1.0;
  static const double scaleActive = 1.15;

  static const double opacityHidden = 0.0;
  static const double opacityMuted = 0.55;
  static const double opacityVisible = 1.0;

  static const Duration staggerLong = Duration(milliseconds: 1000);

  // ── Duration Multipliers (Calculations in Config) ─────────────────────────
  static const Duration dHeroX2 = Duration(milliseconds: 1600);
  static const Duration dHeroX3 = Duration(milliseconds: 2400);
  static const Duration dHeroX4 = Duration(milliseconds: 3200);

  /// Returns `n × step` so that `stagger(1)` is one full step.
  static Duration stagger(int n, {Duration step = staggerCoarse}) => step * n;

  // ── Named curves ──────────────────────────────────────────────────────────
  /// Elastic snap for a sliding selection pill (DSSegmentedSelector).
  static const Curve curveElasticPill = Curves.elasticOut;

  /// Icon pop on activation inside a selector.
  static const Curve curveIconPop = Curves.easeOutBack;

  // ── Effect-list presets ────────────────────────────────────────────────────

  /// Fade-in + scale from 90% → use for avatars and hero images.
  static List<Effect> heroEntry({Duration? delay, Duration? duration}) {
    final d = duration ?? dNormal;
    return [
      FadeEffect(duration: d, delay: delay ?? Duration.zero),
      ScaleEffect(
        begin: const Offset(0.9, 0.9),
        end: const Offset(1.0, 1.0),
        duration: d,
        delay: delay ?? Duration.zero,
      ),
    ];
  }

  /// Fade-in + slide in from the right → use for form fields.
  static List<Effect> fieldEntry({Duration? delay, Duration? duration}) => [
    FadeEffect(duration: duration, delay: delay ?? Duration.zero),
    SlideEffect(
      begin: const Offset(0.1, 0),
      end: Offset.zero,
      duration: duration,
      delay: delay ?? Duration.zero,
    ),
  ];

  /// Fade-in + slide up from below → use for cards and section groups.
  static List<Effect> cardEntry({Duration? delay, Duration? duration}) => [
    FadeEffect(duration: duration, delay: delay ?? Duration.zero),
    SlideEffect(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
      duration: duration,
      delay: delay ?? Duration.zero,
    ),
  ];

  /// Fade-in + scale from 95% → use for primary CTA buttons.
  static List<Effect> ctaEntry({Duration? delay, Duration? duration}) => [
    FadeEffect(duration: duration, delay: delay ?? Duration.zero),
    ScaleEffect(
      begin: const Offset(0.95, 0.95),
      end: const Offset(1.0, 1.0),
      duration: duration,
      delay: delay ?? Duration.zero,
    ),
  ];

  /// Plain fade-in → use for labels, spinners, and secondary text.
  static List<Effect> fadeEntry({Duration? delay, Duration? duration}) => [
    FadeEffect(duration: duration, delay: delay ?? Duration.zero),
  ];

  /// Scale 0.75 → 1 in 150 ms → use for popping in badges or icons.
  static List<Effect> scaleIn({Duration? delay, Duration? duration}) => [
    ScaleEffect(
      begin: const Offset(0.75, 0.75),
      end: const Offset(1.0, 1.0),
      duration: duration ?? dMicro,
      delay: delay ?? Duration.zero,
      curve: Curves.easeOut,
    ),
  ];

  /// Scale 0.6 → 1.08 → 1 in 600 ms → use for success confirmations.
  static List<Effect> scaleBounce({Duration? delay, Duration? duration}) => [
    ScaleEffect(
      begin: const Offset(0.6, 0.6),
      end: const Offset(1.0, 1.0),
      duration: duration ?? dHero,
      delay: delay ?? Duration.zero,
      curve: Curves.elasticOut,
    ),
  ];

  /// Horizontal shake + slight rotate → use for validation errors.
  static List<Effect> shake({Duration? delay, Duration? duration}) => [
    ShakeEffect(
      duration: duration ?? dSlow,
      delay: delay ?? Duration.zero,
      hz: 4,
      offset: const Offset(6, 0),
      rotation: 0.02,
    ),
  ];

  /// Fade-in + slide down from -8 px → use for banners, toasts.
  static List<Effect> slideDown({Duration? delay, Duration? duration}) => [
    FadeEffect(duration: duration ?? dNormal, delay: delay ?? Duration.zero),
    SlideEffect(
      begin: const Offset(0, -0.05),
      end: Offset.zero,
      duration: duration ?? dNormal,
      delay: delay ?? Duration.zero,
    ),
  ];
}

/// Widget extension for applying DS animation presets inline.
extension DSAnimationsX on Widget {
  /// Avatar / hero image pop-in (fadeIn + scale 90→100%).
  Widget dsHeroEntry({Duration? delay, Duration? duration}) => animate(
    effects: DSAnimations.heroEntry(delay: delay, duration: duration),
  );

  /// Form field slide-in from right (fadeIn + slideX).
  Widget dsFieldEntry({Duration? delay, Duration? duration}) => animate(
    effects: DSAnimations.fieldEntry(delay: delay, duration: duration),
  );

  /// Card / section slide-up from below (fadeIn + slideY).
  Widget dsCardEntry({Duration? delay, Duration? duration}) => animate(
    effects: DSAnimations.cardEntry(delay: delay, duration: duration),
  );

  /// Primary CTA button entrance (fadeIn + scaleXY 95→100%).
  Widget dsCtaEntry({Duration? delay, Duration? duration}) => animate(
    effects: DSAnimations.ctaEntry(delay: delay, duration: duration),
  );

  /// Plain fade-in for labels, spinners, and misc elements.
  Widget dsFadeEntry({Duration? delay, Duration? duration}) => animate(
    effects: DSAnimations.fadeEntry(delay: delay, duration: duration),
  );

  /// Scale 0.75 → 1 pop-in for badges and icons.
  Widget dsScaleIn({Duration? delay, Duration? duration}) => animate(
    effects: DSAnimations.scaleIn(delay: delay, duration: duration),
  );

  /// Elastic scale-bounce for success confirmations.
  Widget dsScaleBounce({Duration? delay, Duration? duration}) => animate(
    effects: DSAnimations.scaleBounce(delay: delay, duration: duration),
  );

  /// Horizontal shake for validation errors.
  Widget dsShake({Duration? delay, Duration? duration}) => animate(
    effects: DSAnimations.shake(delay: delay, duration: duration),
  );

  /// Slide down from above for banners and toasts.
  Widget dsSlideDown({Duration? delay, Duration? duration}) => animate(
    effects: DSAnimations.slideDown(delay: delay, duration: duration),
  );
}
