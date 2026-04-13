<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/styles/color_styles.dart
    lib/styles/text_styles.dart

  Update this document whenever you change any of those files.
  Each of those files carries a header comment: "DOCS: docs/styles.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Styles

Centralized design tokens for the app.

## Files

| File | Purpose |
|------|---------|
| `lib/styles/color_styles.dart` | All color constants |
| `lib/styles/text_styles.dart` | All text style constants |

---

## `color_styles.dart`

All color values used in the app live here. Do not use hardcoded hex colors in screens or widgets — always reference a named constant from this file.

Key colors:

| Constant | Usage |
|----------|-------|
| `AppColors.primary` | Brand primary (buttons, active states) |
| `AppColors.success` | Success states, delivered status |
| `AppColors.error` | Error states, failed status |
| `AppColors.warning` | Warning states, storage banner |
| `AppColors.syncPending` | "PENDING SYNC" badge color |
| `AppColors.surface` | Card/tile background |
| `AppColors.textPrimary` | Primary text |
| `AppColors.textSecondary` | Secondary/hint text |

---

## `text_styles.dart`

All `TextStyle` constants. Do not define `TextStyle` inline in screens — reference from here.

Key styles:

| Constant | Usage |
|----------|-------|
| `AppTextStyles.heading1` | Screen titles |
| `AppTextStyles.heading2` | Section headers |
| `AppTextStyles.body` | Standard body text |
| `AppTextStyles.caption` | Small labels, timestamps |
| `AppTextStyles.badge` | Status badge text |

---

## Adding new tokens

1. Add the constant to the appropriate file.
2. Document it in the table above.
3. Never duplicate — search before adding.
