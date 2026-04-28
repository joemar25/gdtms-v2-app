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
  static const Duration dFast   = Duration(milliseconds: 250);
  static const Duration dNormal = Duration(milliseconds: 400);
  static const Duration dSlow   = Duration(milliseconds: 600);
  static const Duration dHero   = Duration(milliseconds: 800);

  // ── Stagger step sizes ─────────────────────────────────────────────────────
  /// 15 ms — tight lists (e.g. notification rows).
  static const Duration staggerFine   = Duration(milliseconds: 15);
  /// 50 ms — section labels and sub-headings.
  static const Duration staggerNormal = Duration(milliseconds: 50);
  /// 100 ms — cards, form fields, primary content.
  static const Duration staggerCoarse = Duration(milliseconds: 100);

  /// Returns `n × step` so that `stagger(1)` is one full step.
  static Duration stagger(int n, {Duration step = staggerCoarse}) => step * n;

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
}

/// Widget extension for applying DS animation presets inline.
extension DSAnimationsX on Widget {
  /// Avatar / hero image pop-in (fadeIn + scale 90→100%).
  Widget dsHeroEntry({Duration? delay, Duration? duration}) =>
      animate(effects: DSAnimations.heroEntry(delay: delay, duration: duration));

  /// Form field slide-in from right (fadeIn + slideX).
  Widget dsFieldEntry({Duration? delay, Duration? duration}) =>
      animate(effects: DSAnimations.fieldEntry(delay: delay, duration: duration));

  /// Card / section slide-up from below (fadeIn + slideY).
  Widget dsCardEntry({Duration? delay, Duration? duration}) =>
      animate(effects: DSAnimations.cardEntry(delay: delay, duration: duration));

  /// Primary CTA button entrance (fadeIn + scaleXY 95→100%).
  Widget dsCtaEntry({Duration? delay, Duration? duration}) =>
      animate(effects: DSAnimations.ctaEntry(delay: delay, duration: duration));

  /// Plain fade-in for labels, spinners, and misc elements.
  Widget dsFadeEntry({Duration? delay, Duration? duration}) =>
      animate(effects: DSAnimations.fadeEntry(delay: delay, duration: duration));
}
