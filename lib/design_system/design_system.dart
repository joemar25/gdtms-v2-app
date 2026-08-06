// DOCS: docs/development-standards.md
// Design System barrel — import this file for tokens, layouts, and scenery.
//
// Folder map:
//   tokens/     → colors, spacing, type, motion, glass
//   backdrop/   → DsBackdrop variants + DsBrandBackdrop (scenery only)
//   layout/     → DsAppScaffold, DSGateShell
//   widgets/    → atoms / molecules (cards, inputs, …)

// Tokens
export 'tokens/ds_colors.dart';
export 'tokens/ds_styles.dart';
export 'tokens/ds_spacing.dart';
export 'tokens/ds_typography.dart';
export 'tokens/ds_icon_sizes.dart';
export 'tokens/ds_animations.dart';
export 'tokens/ds_glass.dart';

// Theme
export 'ds_theme.dart';

// Backdrop (scenery)
export 'backdrop/backdrop.dart';

// Layout shells
export 'layout/layout.dart';

// Atoms
export 'widgets/atoms/ds_input.dart';
export 'widgets/atoms/ds_loading.dart';
export 'widgets/atoms/ds_form_action_link.dart';

// Molecules
export 'widgets/molecules/ds_card.dart';
export 'widgets/molecules/ds_glass_card.dart';
export 'widgets/molecules/ds_glass_chrome.dart';
export 'widgets/molecules/ds_section_header.dart';
export 'widgets/molecules/ds_integrated_sub_header.dart';
export 'widgets/molecules/ds_bottom_action_bar.dart';
export 'widgets/molecules/ds_info_tile.dart';
export 'widgets/molecules/ds_detail_tile.dart';
export 'widgets/molecules/ds_switch_tile.dart';
export 'widgets/molecules/ds_hero_card.dart';
export 'widgets/molecules/ds_secure_view.dart';
export 'widgets/molecules/ds_slide_to_confirm.dart';
