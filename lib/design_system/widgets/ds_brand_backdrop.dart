// DOCS: docs/development-standards.md
// DOCS: docs/design-system.md — update that file when you edit this one.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_colors.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Brand backdrop — shared scenic layer for splash, auth, and future screens.
//
// DX contract:
//   • Pick a [DsBackdropIntensity] preset per screen (quiet / standard / vivid).
//   • Or pass a custom [DsBrandBackdropConfig] to toggle layers independently.
//   • Not every page should look like login — splash is quieter by design.
// ═════════════════════════════════════════════════════════════════════════════

/// Named intensity tiers. Prefer these over hand-tuning unless you need a
/// one-off (then use [DsBrandBackdropConfig.copyWith]).
enum DsBackdropIntensity {
  /// Solid scaffold colors only — no scenery (lists, modals, dense tools).
  none,

  /// Soft gradient + faint orbs. No waves/particles. Short loop.
  /// Good for: splash, brief transitions, offline placeholders.
  quiet,

  /// Full brand scenery (orbs + waves + particles). Default for login/reset.
  standard,

  /// Louder motion / higher contrast — marketing moments only.
  vivid,
}

/// Layered configuration for [DsBrandBackdrop].
///
/// Use [DsBrandBackdropConfig.forIntensity] for presets, or construct / copyWith
/// when a screen needs a unique mix (e.g. orbs on, waves off).
@immutable
class DsBrandBackdropConfig {
  const DsBrandBackdropConfig({
    this.intensity = DsBackdropIntensity.standard,
    this.showOrbs = true,
    this.showWaves = true,
    this.showParticles = true,
    this.animate = true,
    this.opacity = 1.0,
    this.orbAlphaScale = 1.0,
    this.waveAlphaScale = 1.0,
    this.particleCount = 18,
    this.loopDuration = const Duration(seconds: 12),
    this.driftScale = 1.0,
  });

  /// Semantic tier this config represents (for debugging / docs).
  final DsBackdropIntensity intensity;

  final bool showOrbs;
  final bool showWaves;
  final bool showParticles;

  /// When false, paints a frozen frame (also forced by reduce-motion).
  final bool animate;

  /// Multiplies overall scenery alpha (0–1). Base gradient still draws.
  final double opacity;

  /// Scales orb color alpha relative to the intensity default.
  final double orbAlphaScale;

  final double waveAlphaScale;
  final int particleCount;
  final Duration loopDuration;

  /// Scales orb drift distance (1 = standard, 0.5 = calmer).
  final double driftScale;

  // ── Presets ──────────────────────────────────────────────────────────────

  /// No scenery — plain scaffold fill.
  static const none = DsBrandBackdropConfig(
    intensity: DsBackdropIntensity.none,
    showOrbs: false,
    showWaves: false,
    showParticles: false,
    animate: false,
    opacity: 0,
    particleCount: 0,
  );

  /// Splash / brief gate screens — brand present, not competing with content.
  static const quiet = DsBrandBackdropConfig(
    intensity: DsBackdropIntensity.quiet,
    showOrbs: true,
    showWaves: false,
    showParticles: false,
    animate: true,
    opacity: 0.72,
    orbAlphaScale: 0.55,
    waveAlphaScale: 0,
    particleCount: 0,
    loopDuration: Duration(seconds: 16),
    driftScale: 0.55,
  );

  /// Login / reset / unauthenticated marketing moments.
  static const standard = DsBrandBackdropConfig(
    intensity: DsBackdropIntensity.standard,
    showOrbs: true,
    showWaves: true,
    showParticles: true,
    animate: true,
    opacity: 1.0,
    orbAlphaScale: 1.0,
    waveAlphaScale: 1.0,
    particleCount: 18,
    loopDuration: Duration(seconds: 12),
    driftScale: 1.0,
  );

  /// High-energy moments only.
  static const vivid = DsBrandBackdropConfig(
    intensity: DsBackdropIntensity.vivid,
    showOrbs: true,
    showWaves: true,
    showParticles: true,
    animate: true,
    opacity: 1.0,
    orbAlphaScale: 1.25,
    waveAlphaScale: 1.2,
    particleCount: 28,
    loopDuration: Duration(seconds: 9),
    driftScale: 1.25,
  );

  factory DsBrandBackdropConfig.forIntensity(DsBackdropIntensity intensity) {
    return switch (intensity) {
      DsBackdropIntensity.none => none,
      DsBackdropIntensity.quiet => quiet,
      DsBackdropIntensity.standard => standard,
      DsBackdropIntensity.vivid => vivid,
    };
  }

  DsBrandBackdropConfig copyWith({
    DsBackdropIntensity? intensity,
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
      intensity: intensity ?? this.intensity,
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
        other.intensity == intensity &&
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
    intensity,
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

/// Brand scenic backdrop. Pass [config] or [intensity] — never hardcode
/// login-level motion onto every screen.
class DsBrandBackdrop extends StatefulWidget {
  const DsBrandBackdrop({super.key, this.config, this.intensity})
    : assert(
        config == null || intensity == null,
        'Pass config OR intensity, not both.',
      );

  /// Explicit layer config. Wins over [intensity] when both would be set
  /// (assert forbids both).
  final DsBrandBackdropConfig? config;

  /// Preset shortcut — maps via [DsBrandBackdropConfig.forIntensity].
  final DsBackdropIntensity? intensity;

  DsBrandBackdropConfig get resolved =>
      config ??
      DsBrandBackdropConfig.forIntensity(
        intensity ?? DsBackdropIntensity.standard,
      );

  @override
  State<DsBrandBackdrop> createState() => _DsBrandBackdropState();
}

class _DsBrandBackdropState extends State<DsBrandBackdrop>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  DsBrandBackdropConfig get _cfg => widget.resolved;

  @override
  void initState() {
    super.initState();
    _syncController();
  }

  @override
  void didUpdateWidget(covariant DsBrandBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resolved.loopDuration != _cfg.loopDuration ||
        oldWidget.resolved.animate != _cfg.animate) {
      _controller?.dispose();
      _controller = null;
      _syncController();
    }
  }

  void _syncController() {
    if (!_cfg.animate || _cfg.intensity == DsBackdropIntensity.none) return;
    _controller = AnimationController(vsync: this, duration: _cfg.loopDuration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final cfg = _cfg;

    if (cfg.intensity == DsBackdropIntensity.none) {
      return ColoredBox(
        color: isDark ? DSColors.scaffoldDark : DSColors.scaffoldLight,
      );
    }

    final canAnimate = cfg.animate && !reduceMotion && _controller != null;

    if (!canAnimate) {
      return CustomPaint(
        painter: _DsBackdropPainter(progress: 0, isDark: isDark, config: cfg),
        size: Size.infinite,
      );
    }

    return AnimatedBuilder(
      animation: _controller!,
      builder: (context, _) {
        return CustomPaint(
          painter: _DsBackdropPainter(
            progress: _controller!.value,
            isDark: isDark,
            config: cfg,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _DsBackdropPainter extends CustomPainter {
  _DsBackdropPainter({
    required this.progress,
    required this.isDark,
    required this.config,
  });

  final double progress;
  final bool isDark;
  final DsBrandBackdropConfig config;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * math.pi * 2;
    final w = size.width;
    final h = size.height;
    final scene = config.opacity.clamp(0.0, 1.5);

    // ── Base gradient ────────────────────────────────────────────────────
    // dart:ui Gradient requires colorStops when colors.length != 2.
    final shift = config.animate ? math.sin(t) * 0.08 * config.driftScale : 0.0;
    final baseColors = isDark
        ? const [Color(0xFF0E120E), Color(0xFF151C15), Color(0xFF1A1A1A)]
        : const [Color(0xFFEAF6EC), Color(0xFFFFFFFF), Color(0xFFF8F4EC)];
    final base = Paint()
      ..shader = ui.Gradient.linear(
        Offset(w * (0.1 + shift), 0),
        Offset(w * (0.9 - shift), h),
        baseColors,
        const [0.0, 0.5, 1.0],
      );
    canvas.drawRect(Offset.zero & size, base);

    if (scene <= 0) return;

    void orb({
      required double cx,
      required double cy,
      required double radius,
      required Color color,
      required double phase,
      double drift = 28,
      double pulse = 0.06,
    }) {
      final d = drift * config.driftScale;
      final dx = math.sin(t + phase) * d;
      final dy = math.cos(t * 0.9 + phase * 1.2) * (d * 0.75);
      final r = radius * (1 + math.sin(t * 1.4 + phase) * pulse);
      final center = Offset(cx + dx, cy + dy);
      final c = color.withValues(
        alpha: (color.a * config.orbAlphaScale * scene).clamp(0.0, 1.0),
      );
      final paint = Paint()
        ..shader = ui.Gradient.radial(center, r, [c, c.withValues(alpha: 0)]);
      canvas.drawCircle(center, r, paint);
    }

    if (config.showOrbs) {
      final primary = DSColors.primary.withValues(alpha: isDark ? 0.38 : 0.22);
      final gold = DSColors.gold.withValues(alpha: isDark ? 0.26 : 0.18);
      final mint = (isDark ? DSColors.primaryDark : DSColors.primarySurface)
          .withValues(alpha: isDark ? 0.28 : 0.65);

      orb(
        cx: w * 0.92,
        cy: h * 0.06,
        radius: size.shortestSide * 0.58,
        color: primary,
        phase: 0.3,
        drift: 34,
        pulse: 0.08,
      );
      orb(
        cx: w * -0.02,
        cy: h * 0.38,
        radius: size.shortestSide * 0.48,
        color: gold,
        phase: 1.7,
        drift: 26,
      );
      // Quiet: fewer orbs — skip bottom + accent for calmer frames.
      if (config.intensity != DsBackdropIntensity.quiet) {
        orb(
          cx: w * 0.55,
          cy: h * 1.02,
          radius: size.shortestSide * 0.55,
          color: mint,
          phase: 2.8,
          drift: 30,
        );
        orb(
          cx: w * 0.78,
          cy: h * 0.58,
          radius: size.shortestSide * 0.26,
          color: primary.withValues(alpha: isDark ? 0.22 : 0.14),
          phase: 4.1,
          drift: 18,
          pulse: 0.1,
        );
      }
    }

    if (config.showWaves && config.waveAlphaScale > 0) {
      final wavePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = DSColors.primary.withValues(
          alpha: ((isDark ? 0.14 : 0.10) * config.waveAlphaScale * scene).clamp(
            0.0,
            1.0,
          ),
        );

      final waveCount = config.intensity == DsBackdropIntensity.vivid ? 4 : 3;
      for (var i = 0; i < waveCount; i++) {
        final path = Path();
        final yBase = h * (0.62 + i * 0.08);
        final amp = (18.0 + i * 6) * config.driftScale;
        final phase = t + i * 0.9;
        path.moveTo(-20, yBase);
        for (double x = -20; x <= w + 20; x += 12) {
          final y =
              yBase +
              math.sin((x / w) * math.pi * 2 + phase) * amp +
              math.cos((x / w) * math.pi * 3 - phase * 0.6) * (amp * 0.35);
          path.lineTo(x, y);
        }
        canvas.drawPath(path, wavePaint);
      }
    }

    if (config.showParticles && config.particleCount > 0) {
      final rng = math.Random(7);
      final dotPaint = Paint()..style = PaintingStyle.fill;
      for (var i = 0; i < config.particleCount; i++) {
        final seedX = rng.nextDouble();
        final seedY = rng.nextDouble();
        final speed = 0.4 + rng.nextDouble() * 0.8;
        final px = (seedX + progress * speed) % 1.0 * w;
        final py = seedY * h + math.sin(t + i) * 10 * config.driftScale;
        final r = 1.2 + (i % 3) * 0.7;
        final alpha = ((isDark ? 0.18 : 0.14) * scene).clamp(0.0, 1.0);
        dotPaint.color = (i.isEven ? DSColors.primary : DSColors.gold)
            .withValues(alpha: alpha);
        canvas.drawCircle(Offset(px, py), r, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DsBackdropPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.isDark != isDark ||
      oldDelegate.config != config;
}
