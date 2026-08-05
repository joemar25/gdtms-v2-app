// DOCS: docs/development-standards.md
//
// Backdrop module barrel — import via design_system.dart or this file.
//
// Layout:
//   ds_backdrop_variant.dart  → enum DsBackdrop
//   ds_backdrop_config.dart   → presets (shell / gate / auth) ★ edit shell here
//   ds_backdrop_painter.dart  → paint logic
//   ds_brand_backdrop.dart    → Flutter widget
//
// Layout wrappers (separate):
//   layout/ds_app_scaffold.dart  → post-login list/detail pages
//   layout/ds_gate_shell.dart    → pre-dashboard gates
//   features/auth/.../auth_layout.dart → AuthShell (login)

export 'ds_backdrop_variant.dart';
export 'ds_backdrop_config.dart';
export 'ds_brand_backdrop.dart';
