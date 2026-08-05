// DOCS: docs/development-standards.md
// DOCS: docs/features/auth.md
//
// Deprecated path — prefer DsBrandBackdrop from design_system.
// Kept as a thin alias so old imports still compile.

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/backdrop/backdrop.dart';

/// Alias for [DsBrandBackdrop] with default [DsBackdrop.auth].
@Deprecated('Use DsBrandBackdrop(variant: DsBackdrop.auth)')
class AuthAnimatedBackground extends StatelessWidget {
  const AuthAnimatedBackground({
    super.key,
    this.variant = DsBackdrop.auth,
    this.config,
  });

  final DsBackdrop variant;
  final DsBrandBackdropConfig? config;

  @override
  Widget build(BuildContext context) {
    return DsBrandBackdrop(
      variant: config == null ? variant : null,
      config: config,
    );
  }
}
