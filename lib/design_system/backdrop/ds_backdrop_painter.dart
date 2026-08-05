// DOCS: docs/development-standards.md
// DOCS: docs/design-system.md
//
// Paint-only. Not part of the public design_system barrel.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/backdrop/ds_backdrop_config.dart';
import 'package:fsi_courier_app/design_system/backdrop/ds_backdrop_variant.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_colors.dart';

/// Draws the brand scenic layer for a given [DsBrandBackdropConfig].
class DsBackdropPainter extends CustomPainter {
  DsBackdropPainter({
    required this.progress,
    required this.isDark,
    required this.config,
  });

  final double progress;
  final bool isDark;
  final DsBrandBackdropConfig config;

  @override
  void paint(Canvas canvas, Size size) {
    if (config.variant == DsBackdrop.shell) {
      _paintShell(canvas, size);
      return;
    }
    _paintDefault(canvas, size);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHELL — modern post-login work surface (tabs + lists)
  // ═══════════════════════════════════════════════════════════════════════════

  void _paintShell(Canvas canvas, Size size) {
    final t = progress * math.pi * 2;
    final w = size.width;
    final h = size.height;
    final scene = config.opacity.clamp(0.0, 1.5);
    final drift = config.driftScale;

    // 1) Depth gradient — cool charcoal / soft mint, not flat black
    final shift = config.animate ? math.sin(t * 0.6) * 0.04 * drift : 0.0;
    final baseColors = isDark
        ? const [
            Color(0xFF0A0F0C),
            Color(0xFF101612),
            Color(0xFF141A16),
            Color(0xFF0D0D0D),
          ]
        : const [
            Color(0xFFEEF7F0),
            Color(0xFFF7FBF8),
            Color(0xFFFFFFFF),
            Color(0xFFF3F6F4),
          ];
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(w * (0.0 + shift), 0),
          Offset(w * (1.0 - shift), h),
          baseColors,
          const [0.0, 0.35, 0.7, 1.0],
        ),
    );

    // 2) Top brand wash — soft green → clear (reads modern under green app bars)
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, h * 0.42),
          [
            DSColors.primary.withValues(alpha: isDark ? 0.14 : 0.09),
            DSColors.primary.withValues(alpha: isDark ? 0.04 : 0.02),
            DSColors.primary.withValues(alpha: 0),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );

    // 3) Bottom-right gold ambient (brand warmth, low)
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(w * 0.95, h * 1.05),
          size.shortestSide * 0.85,
          [
            DSColors.gold.withValues(alpha: isDark ? 0.10 : 0.06),
            DSColors.gold.withValues(alpha: 0),
          ],
        ),
    );

    if (scene <= 0) return;

    void orb({
      required double cx,
      required double cy,
      required double radius,
      required Color color,
      required double phase,
      double driftPx = 16,
      double pulse = 0.035,
    }) {
      final d = driftPx * drift;
      final dx = math.sin(t + phase) * d;
      final dy = math.cos(t * 0.75 + phase * 1.15) * (d * 0.65);
      final r = radius * (1 + math.sin(t * 0.9 + phase) * pulse);
      final center = Offset(cx + dx, cy + dy);
      final c = color.withValues(
        alpha: (color.a * config.orbAlphaScale * scene).clamp(0.0, 1.0),
      );
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = ui.Gradient.radial(
            center,
            r,
            [c, c.withValues(alpha: c.a * 0.35), c.withValues(alpha: 0)],
            const [0.0, 0.45, 1.0],
          ),
      );
    }

    if (config.showOrbs) {
      // Large primary — upper right (behind header / cards)
      orb(
        cx: w * 0.88,
        cy: h * 0.06,
        radius: size.shortestSide * 0.52,
        color: DSColors.primary.withValues(alpha: isDark ? 0.32 : 0.16),
        phase: 0.2,
        driftPx: 20,
      );
      // Gold — lower left
      orb(
        cx: w * 0.08,
        cy: h * 0.88,
        radius: size.shortestSide * 0.42,
        color: DSColors.gold.withValues(alpha: isDark ? 0.18 : 0.11),
        phase: 1.7,
        driftPx: 15,
      );
      // Soft mint mid — depth without noise
      orb(
        cx: w * 0.55,
        cy: h * 0.45,
        radius: size.shortestSide * 0.28,
        color: (isDark ? DSColors.primaryDark : DSColors.primarySurface)
            .withValues(alpha: isDark ? 0.14 : 0.35),
        phase: 2.9,
        driftPx: 12,
        pulse: 0.05,
      );
    }

    // 4) Soft arc accents (not full route-waves — modern, minimal)
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round
      ..color = DSColors.primary.withValues(
        alpha: (isDark ? 0.10 : 0.07) * scene * config.orbAlphaScale,
      );
    final arcCenter = Offset(w * 0.5, h * 1.15);
    for (var i = 0; i < 3; i++) {
      final r = size.shortestSide * (0.55 + i * 0.12);
      final start = -math.pi * 0.85 + math.sin(t * 0.5 + i) * 0.08 * drift;
      canvas.drawArc(
        Rect.fromCircle(center: arcCenter, radius: r),
        start,
        math.pi * 0.55,
        false,
        arcPaint,
      );
    }

    // 5) Ambient sparkles (sparse)
    _paintParticles(
      canvas,
      size,
      progress: progress,
      t: t,
      scene: scene,
      seed: 11,
      baseAlpha: isDark ? 0.28 : 0.20,
      speedScale: 0.35,
      driftY: 6 * drift,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GATE / AUTH / VIVID — richer onboarding & login
  // ═══════════════════════════════════════════════════════════════════════════

  void _paintDefault(Canvas canvas, Size size) {
    final t = progress * math.pi * 2;
    final w = size.width;
    final h = size.height;
    final scene = config.opacity.clamp(0.0, 1.5);
    final isGate = config.variant == DsBackdrop.gate;

    final shift = config.animate ? math.sin(t) * 0.05 * config.driftScale : 0.0;
    final List<Color> baseColors;
    if (isGate) {
      baseColors = isDark
          ? const [Color(0xFF0E120E), Color(0xFF151C15), Color(0xFF121212)]
          : const [Color(0xFFEAF6EC), Color(0xFFFFFFFF), Color(0xFFF7F5F0)];
    } else {
      baseColors = isDark
          ? const [Color(0xFF0E120E), Color(0xFF151C15), Color(0xFF1A1A1A)]
          : const [Color(0xFFEAF6EC), Color(0xFFFFFFFF), Color(0xFFF8F4EC)];
    }

    final base = Paint()
      ..shader = ui.Gradient.linear(
        Offset(w * (0.05 + shift), 0),
        Offset(w * (0.95 - shift), h),
        baseColors,
        const [0.0, 0.5, 1.0],
      );
    canvas.drawRect(Offset.zero & size, base);

    final veil = Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h * 0.35), [
        DSColors.primary.withValues(alpha: isDark ? 0.12 : 0.08),
        DSColors.primary.withValues(alpha: 0),
      ]);
    canvas.drawRect(Offset.zero & size, veil);

    // Layers independent — showOrbs false must not kill waves/particles.
    if (scene <= 0) return;

    if (config.showOrbs) {
      void orb({
        required double cx,
        required double cy,
        required double radius,
        required Color color,
        required double phase,
        double drift = 28,
        double pulse = 0.04,
      }) {
        final d = drift * config.driftScale;
        final dx = math.sin(t + phase) * d;
        final dy = math.cos(t * 0.85 + phase * 1.1) * (d * 0.7);
        final r = radius * (1 + math.sin(t * 1.2 + phase) * pulse);
        final center = Offset(cx + dx, cy + dy);
        final c = color.withValues(
          alpha: (color.a * config.orbAlphaScale * scene).clamp(0.0, 1.0),
        );
        final paint = Paint()
          ..shader = ui.Gradient.radial(center, r, [c, c.withValues(alpha: 0)]);
        canvas.drawCircle(center, r, paint);
      }

      final primary = DSColors.primary.withValues(alpha: isDark ? 0.36 : 0.20);
      final gold = DSColors.gold.withValues(alpha: isDark ? 0.24 : 0.16);
      final mint = (isDark ? DSColors.primaryDark : DSColors.primarySurface)
          .withValues(alpha: isDark ? 0.22 : 0.5);

      orb(
        cx: w * 0.9,
        cy: h * 0.08,
        radius: size.shortestSide * 0.55,
        color: primary,
        phase: 0.25,
        drift: 30,
      );
      orb(
        cx: w * 0.05,
        cy: h * 0.4,
        radius: size.shortestSide * 0.46,
        color: gold,
        phase: 1.6,
        drift: 24,
      );

      if (config.variant == DsBackdrop.auth ||
          config.variant == DsBackdrop.vivid) {
        orb(
          cx: w * 0.55,
          cy: h * 1.0,
          radius: size.shortestSide * 0.5,
          color: mint,
          phase: 2.6,
          drift: 26,
        );
        orb(
          cx: w * 0.75,
          cy: h * 0.55,
          radius: size.shortestSide * 0.24,
          color: primary.withValues(alpha: isDark ? 0.2 : 0.12),
          phase: 3.8,
          drift: 16,
          pulse: 0.08,
        );
      }
    }

    if (config.showWaves && config.waveAlphaScale > 0) {
      final wavePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = DSColors.primary.withValues(
          alpha: ((isDark ? 0.12 : 0.09) * config.waveAlphaScale * scene).clamp(
            0.0,
            1.0,
          ),
        );
      final waveCount = config.variant == DsBackdrop.vivid ? 4 : 3;
      for (var i = 0; i < waveCount; i++) {
        final path = Path();
        final yBase = h * (0.62 + i * 0.08);
        final amp = (16.0 + i * 5) * config.driftScale;
        final phase = t + i * 0.9;
        path.moveTo(-20, yBase);
        for (double x = -20; x <= w + 20; x += 14) {
          final y =
              yBase +
              math.sin((x / w) * math.pi * 2 + phase) * amp +
              math.cos((x / w) * math.pi * 3 - phase * 0.5) * (amp * 0.3);
          path.lineTo(x, y);
        }
        canvas.drawPath(path, wavePaint);
      }
    }

    _paintParticles(
      canvas,
      size,
      progress: progress,
      t: t,
      scene: scene,
      seed: 7,
      baseAlpha: isDark ? 0.32 : 0.24,
      speedScale: 1.0,
      driftY: 8 * config.driftScale,
    );
  }

  /// Shared sparkle dots. [showParticles: true] alone enough —
  /// falls back to default count when [particleCount] is 0.
  void _paintParticles(
    Canvas canvas,
    Size size, {
    required double progress,
    required double t,
    required double scene,
    required int seed,
    required double baseAlpha,
    required double speedScale,
    required double driftY,
  }) {
    if (!config.showParticles) return;

    final count = config.particleCount > 0
        ? config.particleCount
        : _defaultParticleCount;
    if (count <= 0 || scene <= 0) return;

    final w = size.width;
    final h = size.height;
    final rng = math.Random(seed);
    final core = Paint()..style = PaintingStyle.fill;
    final glow = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < count; i++) {
      final seedX = rng.nextDouble();
      final seedY = rng.nextDouble();
      final speed = (0.35 + rng.nextDouble() * 0.7) * speedScale;
      final phase = rng.nextDouble() * math.pi * 2;
      final px = (seedX + progress * speed) % 1.0 * w;
      final py = seedY * h + math.sin(t + i + phase) * driftY;
      // Soft twinkle so dots read as motion, not static noise.
      final twinkle = 0.55 + 0.45 * (0.5 + 0.5 * math.sin(t * 1.4 + phase + i));
      final r = 1.6 + (i % 3) * 0.9;
      final a = (baseAlpha * scene * twinkle).clamp(0.0, 1.0);
      final color = i.isEven ? DSColors.primary : DSColors.gold;

      glow.color = color.withValues(alpha: a * 0.35);
      canvas.drawCircle(Offset(px, py), r * 2.2, glow);
      core.color = color.withValues(alpha: a);
      canvas.drawCircle(Offset(px, py), r, core);
    }
  }

  static const int _defaultParticleCount = 14;

  @override
  bool shouldRepaint(covariant DsBackdropPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.isDark != isDark ||
      oldDelegate.config != config;
}
