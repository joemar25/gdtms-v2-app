// DOCS: docs/development-standards.md
// DOCS: docs/design-system.md

import 'package:flutter/foundation.dart';
import 'package:fsi_courier_app/design_system/backdrop/ds_backdrop_variant.dart';

// ═════════════════════════════════════════════════════════════════════════════
// PRESETS — change values here, not on individual screens.
//
//   shell  → Home / Bagsakan / Wallet / Profile / list pages
//   gate   → splash, permissions, terms, update
//   auth   → login, forgot password
// ═════════════════════════════════════════════════════════════════════════════

/// Tunable layers for [DsBrandBackdrop].
@immutable
class DsBrandBackdropConfig {
  const DsBrandBackdropConfig({
    required this.variant,
    this.showOrbs = true,
    this.showWaves = false,
    this.showParticles = false,
    this.animate = true,
    this.opacity = 1.0,
    this.orbAlphaScale = 1.0,
    this.waveAlphaScale = 1.0,
    this.particleCount = 0,
    this.loopDuration = const Duration(seconds: 16),
    this.driftScale = 0.7,
  });

  final DsBackdrop variant;
  final bool showOrbs;
  final bool showWaves;

  /// Sparkle dots. Alone enough — if [particleCount] is 0, painter uses ~14.
  final bool showParticles;
  final bool animate;
  final double opacity;
  final double orbAlphaScale;
  final double waveAlphaScale;

  /// Dot count. 0 + [showParticles] → painter default (~14).
  final int particleCount;
  final Duration loopDuration;
  final double driftScale;

  // ── Presets ──────────────────────────────────────────────────────────────

  static const none = DsBrandBackdropConfig(
    variant: DsBackdrop.none,
    showOrbs: false,
    animate: false,
    opacity: 0,
  );

  /// ★ Main app after login (tabs + DsAppScaffold). Edit this for dashboard bg.
  ///
  /// Modern calm work surface: layered gradient, soft brand orbs, light ambient
  /// dots — not login-level waves. Keep [orbAlphaScale] moderate for readability.
  /// Never set [orbAlphaScale] to 0 — dark mode becomes a pure black void.
  static const shell = DsBrandBackdropConfig(
    variant: DsBackdrop.shell,
    showOrbs: false,
    showWaves: false,
    showParticles: true,
    animate: true,
    opacity: 1.0,
    orbAlphaScale: 0, // 0.9
    particleCount: 15,
    loopDuration: Duration(seconds: 30),
    driftScale: 0.65,
  );

  /// Splash / permissions / terms / update.
  static const gate = DsBrandBackdropConfig(
    variant: DsBackdrop.gate,
    showOrbs: true,
    showWaves: false,
    showParticles: false,
    animate: true,
    opacity: 0.9,
    orbAlphaScale: 0.75,
    loopDuration: Duration(seconds: 16),
    driftScale: 0.6,
  );

  /// Login / forgot password.
  static const auth = DsBrandBackdropConfig(
    variant: DsBackdrop.auth,
    showOrbs: true,
    showWaves: true,
    showParticles: true,
    animate: true,
    opacity: 1.0,
    orbAlphaScale: 1.0,
    waveAlphaScale: 1.0,
    particleCount: 16,
    loopDuration: Duration(seconds: 12),
    driftScale: 1.0,
  );

  static const vivid = DsBrandBackdropConfig(
    variant: DsBackdrop.vivid,
    showOrbs: true,
    showWaves: true,
    showParticles: true,
    animate: true,
    opacity: 1.0,
    orbAlphaScale: 1.2,
    waveAlphaScale: 1.15,
    particleCount: 24,
    loopDuration: Duration(seconds: 9),
    driftScale: 1.2,
  );

  factory DsBrandBackdropConfig.forVariant(DsBackdrop variant) {
    return switch (variant) {
      DsBackdrop.none => none,
      DsBackdrop.shell => shell,
      DsBackdrop.gate => gate,
      DsBackdrop.auth => auth,
      DsBackdrop.vivid => vivid,
    };
  }

  DsBrandBackdropConfig copyWith({
    DsBackdrop? variant,
    bool? showOrbs,
    bool? showWaves,
    bool? showParticles,
    bool? animate,
    double? opacity,
    double? orbAlphaScale,
    double? waveAlphaScale,
    int? particleCount,
    Duration? loopDuration,
    double? driftScale,
  }) {
    return DsBrandBackdropConfig(
      variant: variant ?? this.variant,
      showOrbs: showOrbs ?? this.showOrbs,
      showWaves: showWaves ?? this.showWaves,
      showParticles: showParticles ?? this.showParticles,
      animate: animate ?? this.animate,
      opacity: opacity ?? this.opacity,
      orbAlphaScale: orbAlphaScale ?? this.orbAlphaScale,
      waveAlphaScale: waveAlphaScale ?? this.waveAlphaScale,
      particleCount: particleCount ?? this.particleCount,
      loopDuration: loopDuration ?? this.loopDuration,
      driftScale: driftScale ?? this.driftScale,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DsBrandBackdropConfig &&
        other.variant == variant &&
        other.showOrbs == showOrbs &&
        other.showWaves == showWaves &&
        other.showParticles == showParticles &&
        other.animate == animate &&
        other.opacity == opacity &&
        other.orbAlphaScale == orbAlphaScale &&
        other.waveAlphaScale == waveAlphaScale &&
        other.particleCount == particleCount &&
        other.loopDuration == loopDuration &&
        other.driftScale == driftScale;
  }

  @override
  int get hashCode => Object.hash(
    variant,
    showOrbs,
    showWaves,
    showParticles,
    animate,
    opacity,
    orbAlphaScale,
    waveAlphaScale,
    particleCount,
    loopDuration,
    driftScale,
  );
}
