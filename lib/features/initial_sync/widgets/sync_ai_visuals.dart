// DOCS: docs/development-standards.md
// DOCS: docs/features/initial-sync.md — update that file when you edit this one.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

/// Loading visuals for post-login setup — friendly labels for couriers.
///
/// Splash = brand welcome. Sync = “getting deliveries ready on your phone.”

// ── Phase model ──────────────────────────────────────────────────────────────

enum SyncAiPhase {
  init, // start / clear / check
  fetch, // download deliveries
  organize, // bagsakan / tidy
  ready,
}

extension SyncAiPhaseX on SyncAiPhase {
  /// Short labels on the step rail — plain English for couriers.
  String get label => switch (this) {
    SyncAiPhase.init => 'Start',
    SyncAiPhase.fetch => 'Load',
    SyncAiPhase.organize => 'Sort',
    SyncAiPhase.ready => 'Done',
  };

  int get index => SyncAiPhase.values.indexOf(this);
}

/// Map progress strings → phase (best-effort).
///
/// Used by [InitialSyncScreen] (bootstrap) and [SyncOverlay] (queue flush).
SyncAiPhase syncPhaseFromProgress(String message, {required bool done}) {
  if (done) return SyncAiPhase.ready;
  final s = message.toLowerCase();
  if (s.contains('bag') ||
      s.contains('tidy') ||
      s.contains('clean') ||
      s.contains('almost') ||
      s.contains('finaliz') ||
      s.contains('sort') ||
      s.contains('wrap')) {
    return SyncAiPhase.organize;
  }
  if (s.contains('download') ||
      s.contains('latest') ||
      s.contains('updat') ||
      s.contains('deliver') ||
      s.contains('fetch') ||
      s.contains('load') ||
      s.contains('upload') ||
      s.contains('queue') ||
      s.contains('send') ||
      s.contains('flush') ||
      s.contains('push')) {
    return SyncAiPhase.fetch;
  }
  // start / fresh / check / prepar / syncing
  return SyncAiPhase.init;
}

/// Phase for manual "Sync Now" queue flush when only counters are available.
SyncAiPhase syncPhaseFromQueueProgress({
  required bool done,
  required String? message,
  required int processed,
  required int total,
}) {
  if (done) return SyncAiPhase.ready;
  final msg = message?.trim() ?? '';
  if (msg.isNotEmpty) {
    final fromMsg = syncPhaseFromProgress(msg, done: false);
    if (fromMsg != SyncAiPhase.init) return fromMsg;
  }
  if (total > 0) {
    final ratio = processed / total;
    if (ratio >= 0.85) return SyncAiPhase.organize;
    if (processed > 0) return SyncAiPhase.fetch;
  }
  return SyncAiPhase.init;
}

// ── Orbital AI core ──────────────────────────────────────────────────────────

/// Rotating multi-ring orb with core glow. [done] morphs to success check.
class SyncAiOrb extends StatefulWidget {
  const SyncAiOrb({
    super.key,
    required this.done,
    this.size = 168,
    this.onSuccessComplete,
  });

  final bool done;
  final double size;
  final VoidCallback? onSuccessComplete;

  @override
  State<SyncAiOrb> createState() => _SyncAiOrbState();
}

class _SyncAiOrbState extends State<SyncAiOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;
  bool _successNotified = false;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant SyncAiOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.done && !oldWidget.done) {
      _spin.stop();
    }
    if (!widget.done && oldWidget.done) {
      _successNotified = false;
      _spin.repeat();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final size = widget.size;

    if (widget.done) {
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size * 0.72,
              height: size * 0.72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    DSColors.success.withValues(alpha: isDark ? 0.35 : 0.22),
                    DSColors.success.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
            Icon(
                  Icons.check_rounded,
                  size: size * 0.38,
                  color: DSColors.success,
                )
                .animate(
                  onComplete: (_) {
                    if (!_successNotified) {
                      _successNotified = true;
                      widget.onSuccessComplete?.call();
                    }
                  },
                )
                .scale(
                  begin: const Offset(0.4, 0.4),
                  end: const Offset(1, 1),
                  duration: DSAnimations.dHero,
                  curve: Curves.easeOutBack,
                )
                .fadeIn(duration: DSAnimations.dFast),
          ],
        ),
      );
    }

    final painter = AnimatedBuilder(
      animation: _spin,
      builder: (context, _) {
        return CustomPaint(
          size: Size(size, size),
          painter: _OrbPainter(
            progress: reduceMotion ? 0 : _spin.value,
            isDark: isDark,
          ),
        );
      },
    );

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft outer bloom
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: DSColors.primary.withValues(
                    alpha: isDark ? 0.35 : 0.18,
                  ),
                  blurRadius: 48,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
          painter,
          // Core node
          Container(
                width: size * 0.28,
                height: size * 0.28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      isDark ? DSColors.primaryDark : DSColors.primary,
                      DSColors.primary.withValues(alpha: 0.85),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: DSColors.primary.withValues(alpha: 0.55),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.hub_outlined,
                  size: size * 0.12,
                  color: DSColors.white,
                ),
              )
              .animate(
                onPlay: reduceMotion ? null : (c) => c.repeat(reverse: true),
              )
              .scale(
                begin: const Offset(1, 1),
                end: reduceMotion
                    ? const Offset(1, 1)
                    : const Offset(1.08, 1.08),
                duration: DSAnimations.dHeroX2,
                curve: Curves.easeInOut,
              ),
        ],
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({required this.progress, required this.isDark});

  final double progress;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final t = progress * math.pi * 2;

    void ring({
      required double radius,
      required double stroke,
      required Color color,
      required double sweep,
      required double phase,
      bool reverse = false,
    }) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color;
      final start = (reverse ? -t : t) + phase;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
    }

    final primary = DSColors.primary.withValues(alpha: isDark ? 0.85 : 0.75);
    final gold = DSColors.gold.withValues(alpha: isDark ? 0.7 : 0.55);
    final faint = DSColors.primary.withValues(alpha: isDark ? 0.18 : 0.12);

    // Track rings
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = faint;
    canvas.drawCircle(c, size.width * 0.38, track);
    canvas.drawCircle(c, size.width * 0.30, track);
    canvas.drawCircle(c, size.width * 0.22, track);

    ring(
      radius: size.width * 0.38,
      stroke: 3.2,
      color: primary,
      sweep: math.pi * 1.15,
      phase: 0.4,
    );
    ring(
      radius: size.width * 0.30,
      stroke: 2.4,
      color: gold,
      sweep: math.pi * 0.85,
      phase: 1.2,
      reverse: true,
    );
    ring(
      radius: size.width * 0.22,
      stroke: 2.0,
      color: primary.withValues(alpha: 0.9),
      sweep: math.pi * 0.55,
      phase: 2.1,
    );

    // Satellite nodes
    final nodePaint = Paint()..color = DSColors.gold;
    for (var i = 0; i < 6; i++) {
      final a = t * (i.isEven ? 1 : -1) + i * (math.pi / 3);
      final r = size.width * (0.22 + (i % 3) * 0.08);
      final p = Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r);
      canvas.drawCircle(
        p,
        i.isEven ? 3.2 : 2.2,
        nodePaint
          ..color = (i.isEven ? DSColors.primary : DSColors.gold).withValues(
            alpha: 0.9,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isDark != isDark;
}

// ── Phase rail ───────────────────────────────────────────────────────────────

class SyncAiPhaseRail extends StatelessWidget {
  const SyncAiPhaseRail({super.key, required this.active});

  final SyncAiPhase active;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final phases = SyncAiPhase.values;

    return Row(
      children: [
        for (var i = 0; i < phases.length; i++) ...[
          if (i > 0)
            Expanded(
              child: AnimatedContainer(
                duration: DSAnimations.dFast,
                height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: i <= active.index
                    ? DSColors.primary.withValues(alpha: 0.85)
                    : (isDark
                          ? DSColors.white.withValues(alpha: 0.08)
                          : DSColors.primary.withValues(alpha: 0.12)),
              ),
            ),
          _PhaseDot(
            phase: phases[i],
            state: i < active.index
                ? _PhaseDotState.done
                : i == active.index
                ? _PhaseDotState.active
                : _PhaseDotState.idle,
          ),
        ],
      ],
    );
  }
}

enum _PhaseDotState { idle, active, done }

class _PhaseDot extends StatelessWidget {
  const _PhaseDot({required this.phase, required this.state});

  final SyncAiPhase phase;
  final _PhaseDotState state;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = switch (state) {
      _PhaseDotState.done => DSColors.success,
      _PhaseDotState.active => DSColors.primary,
      _PhaseDotState.idle =>
        isDark ? DSColors.labelTertiaryDark : DSColors.labelTertiary,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: DSAnimations.dFast,
          width: state == _PhaseDotState.active ? 28 : 22,
          height: state == _PhaseDotState.active ? 28 : 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: state == _PhaseDotState.idle
                ? (isDark
                      ? DSColors.cardElevatedDark
                      : DSColors.secondarySurfaceLight)
                : accent.withValues(alpha: 0.15),
            border: Border.all(
              color: accent.withValues(
                alpha: state == _PhaseDotState.idle ? 0.35 : 1,
              ),
              width: state == _PhaseDotState.active ? 2 : 1.2,
            ),
            boxShadow: state == _PhaseDotState.active
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            state == _PhaseDotState.done ? Icons.check_rounded : Icons.circle,
            size: state == _PhaseDotState.done ? 14 : 6,
            color: accent,
          ),
        ),
        DSSpacing.hXs,
        Text(
          phase.label,
          style: DSTypography.label(color: accent).copyWith(
            fontSize: DSTypography.sizeXs,
            fontWeight: state == _PhaseDotState.active
                ? FontWeight.w700
                : FontWeight.w500,
            letterSpacing: DSTypography.lsWide,
          ),
        ),
      ],
    );
  }
}

// ── Stream status line ───────────────────────────────────────────────────────

class SyncAiStatusStream extends StatelessWidget {
  const SyncAiStatusStream({
    super.key,
    required this.message,
    required this.done,
  });

  final String message;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark
        ? DSColors.labelSecondaryDark
        : DSColors.labelSecondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: DSSpacing.md,
        vertical: DSSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? DSColors.black.withValues(alpha: 0.35)
            : DSColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(DSStyles.radiusXL),
        border: Border.all(
          color: isDark
              ? DSColors.white.withValues(alpha: 0.08)
              : DSColors.primary.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        children: [
          // Live indicator
          if (!done)
            Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: DSColors.primary,
                    boxShadow: [
                      BoxShadow(
                        color: DSColors.primary.withValues(alpha: 0.55),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .fade(begin: 0.35, end: 1, duration: DSAnimations.dSlow)
          else
            Icon(
              Icons.verified_rounded,
              size: DSIconSize.sm,
              color: DSColors.success,
            ),
          DSSpacing.wSm,
          Expanded(
            child: AnimatedSwitcher(
              duration: DSAnimations.dFast,
              switchInCurve: Curves.easeOut,
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.centerLeft,
                children: [...previous, ?current],
              ),
              child: Text(
                message,
                key: ValueKey(message),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: DSTypography.body(color: muted).copyWith(
                  fontSize: DSTypography.sizeMd,
                  height: DSTypography.lineHeightDefault,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
