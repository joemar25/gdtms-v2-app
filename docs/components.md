<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/components/header.dart
    lib/components/styled_drop_down.dart
    lib/components/styled_text_box.dart

  Update this document whenever you change any of those files.
  Each of those files carries a header comment: "DOCS: docs/components.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Components

Low-level UI primitives in `lib/components/`. These are building blocks used by both shared widgets and feature screens.

## Files

| File | Widget | Purpose |
|------|--------|---------|
| `header.dart` | `AppHeader` | Branded page header used inside screen bodies |
| `styled_drop_down.dart` | `StyledDropDown` | Consistently styled dropdown selector |
| `styled_text_box.dart` | `StyledTextBox` | Consistently styled text input field |

---

## Notes

- These components enforce the app's design language (colors from `color_styles.dart`, typography from `text_styles.dart`).
- Do not add business logic here — keep them purely presentational.
- Prefer using these over raw Flutter `TextField` / `DropdownButton` in feature screens.
