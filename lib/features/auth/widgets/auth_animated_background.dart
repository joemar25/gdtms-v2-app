// DOCS: docs/development-standards.md
// DOCS: docs/features/auth.md — update that file when you edit this one.

export 'package:fsi_courier_app/design_system/widgets/ds_brand_backdrop.dart'
    show DsBackdropIntensity, DsBrandBackdropConfig, DsBrandBackdrop;

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/widgets/ds_brand_backdrop.dart';

/// Auth-facing alias for [DsBrandBackdrop].
///
/// Prefer configuring intensity per screen — login ≠ splash:
/// ```dart
/// AuthAnimatedBackground(intensity: DsBackdropIntensity.standard) // login
/// AuthAnimatedBackground(intensity: DsBackdropIntensity.quiet)    // splash
/// AuthAnimatedBackground(
///   config: DsBrandBackdropConfig.standard.copyWith(showParticles: false),
/// )
/// ```
class AuthAnimatedBackground extends StatelessWidget {
  const AuthAnimatedBackground({super.key, this.intensity, this.config})
    : assert(
        config == null || intensity == null,
        'Pass config OR intensity, not both.',
      );

  /// Preset. Defaults to [DsBackdropIntensity.standard] (login-level).
  final DsBackdropIntensity? intensity;

  /// Full layer control. Prefer presets unless you need a custom mix.
  final DsBrandBackdropConfig? config;

  @override
  Widget build(BuildContext context) {
    return DsBrandBackdrop(
      intensity: config == null
          ? (intensity ?? DsBackdropIntensity.standard)
          : null,
      config: config,
    );
  }
}
