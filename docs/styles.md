# Design System Styles

This document outlines the design tokens and components used in the GDTMS v2 Mobile App. All UI elements should be built using these tokens to ensure consistency and a premium feel.

## Architecture

The Design System is located in `lib/design_system/` and follows a token-based architecture:

| Directory | Content | Purpose |
|-----------|---------|---------|
| `tokens/` | `DSColors`, `DSTypography`, `DSSpacing`, `DSStyles` | Primitive values (colors, fonts, radii) |
| `widgets/atoms/` | `DSInput`, etc. | Basic standalone components |
| `widgets/molecules/` | `DSCard`, `DSInfoTile`, `DSSectionHeader` | Composite components |

---

## Typography (`DSTypography`)

We use the **Montserrat** font family for all text. The system automatically maps all 18 font weights registered in `pubspec.yaml`.

**Key Styles:**

| Method | Usage |
|--------|-------|
| `heading()` | Large screen titles (w800) |
| `title()` | Standard titles (w700) |
| `subTitle()` | Section headers or secondary titles (w600) |
| `body()` | Regular paragraph text (w400) |
| `button()` | Button labels (w700) |
| `caption()` | Small details, timestamps (w400) |
| `label()` | Small uppercase metadata headers (w700) |

---

## Colors (`DSColors`)

Single source of truth for all color values. **Never hardcode hex values.**

**Brand Colors:**
- `primary`: FSI Green (#00B14F)
- `systemBlue`: iOS-style blue for interactivity
- `red`: Error/System red

**Status Colors:**
- `success`: Same as primary
- `error`: High-visibility red (#E53935)
- `warning`: Alert amber (#FFB300)
- `pending`: Attention orange (#FF6E00)

**Semantic Helpers:**
- `statusColor(String status)`: Returns the appropriate color for a given delivery status.

---

## Components

### `DSInput`
Replaces the old `StyledTextBox`. Handles text entry, password visibility toggles, and follows the modern "filled" look.

### `DSCard`
Replaces raw `Container` or `Card` for lists and summaries. Provides consistent rounding and shadows.

### `DSInfoTile`
The standard for displaying key-value pairs (e.g., in Delivery Details).

---

## Usage Rules

1. **Tokens Over Raw Values**: Use `DSColors.primary` instead of `Color(0xFF...)`.
2. **Typography Over Direct Styles**: Use `DSTypography.body()` instead of `TextStyle(...)`.
3. **Consistency**: If a component needs a specific variation, use `.copyWith()` on the existing DS token.
