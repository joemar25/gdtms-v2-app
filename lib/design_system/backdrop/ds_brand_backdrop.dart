// DOCS: docs/development-standards.md
// DOCS: docs/design-system.md
//
// Public widget only. Presets live in [ds_backdrop_config.dart].

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/backdrop/ds_backdrop_config.dart';
import 'package:fsi_courier_app/design_system/backdrop/ds_backdrop_painter.dart';
import 'package:fsi_courier_app/design_system/backdrop/ds_backdrop_variant.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_colors.dart';

/// Scenic brand background.
///
/// ```dart
/// DsBrandBackdrop(variant: DsBackdrop.shell) // main app
/// DsBrandBackdrop(variant: DsBackdrop.auth)  // login
/// DsBrandBackdrop(variant: DsBackdrop.gate)  // splash / permissions
/// DsBrandBackdrop(config: DsBrandBackdropConfig.shell.copyWith(...))
/// ```
class DsBrandBackdrop extends StatefulWidget {
  const DsBrandBackdrop({super.key, this.variant, this.config});

  /// Preferred API: [DsBackdrop.shell] / [.gate] / [.auth] / …
  final DsBackdrop? variant;

  /// Full override (rare one-offs). Wins over [variant].
  final DsBrandBackdropConfig? config;

  DsBrandBackdropConfig get resolved =>
      config ?? DsBrandBackdropConfig.forVariant(variant ?? DsBackdrop.auth);

  @override
  State<DsBrandBackdrop> createState() => _DsBrandBackdropState();
}

class _DsBrandBackdropState extends State<DsBrandBackdrop>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  DsBrandBackdropConfig get _cfg => widget.resolved;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncController();
  }

  @override
  void didUpdateWidget(covariant DsBrandBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController();
  }

  // Starts/stops the repeating ticker to match whether the backdrop should
  // actually be animating right now. Must also check reduce-motion here (not
  // just in build()) — otherwise the ticker keeps scheduling frames forever
  // even while paint is skipped, which burns battery and makes
  // tester.pumpAndSettle() hang on every screen that shows this backdrop.
  void _syncController() {
    final shouldAnimate =
        _cfg.animate &&
        _cfg.variant != DsBackdrop.none &&
        !MediaQuery.disableAnimationsOf(context);

    if (!shouldAnimate) {
      _controller?.dispose();
      _controller = null;
      return;
    }

    if (_controller == null || _controller!.duration != _cfg.loopDuration) {
      _controller?.dispose();
      _controller = AnimationController(
        vsync: this,
        duration: _cfg.loopDuration,
      )..repeat();
    }
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

    if (cfg.variant == DsBackdrop.none) {
      return ColoredBox(
        color: isDark ? DSColors.scaffoldDark : DSColors.scaffoldLight,
      );
    }

    final canAnimate = cfg.animate && !reduceMotion && _controller != null;

    if (!canAnimate) {
      return CustomPaint(
        painter: DsBackdropPainter(progress: 0, isDark: isDark, config: cfg),
        size: Size.infinite,
      );
    }

    return AnimatedBuilder(
      animation: _controller!,
      builder: (context, _) {
        return CustomPaint(
          painter: DsBackdropPainter(
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
