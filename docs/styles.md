# Design System Styles

This document outlines the design tokens and components used in the GDTMS v2 Mobile App. All UI elements should be built using these tokens to ensure consistency and a premium feel.

> **Composition rules** (shell vs gate, brand-only metric tiles, hold-to-reveal, dashboard motion, sync overlay) live in **[design-system.md](design-system.md)**. Use that doc when aligning Bagsakan / Wallet / Profile / lists to the dashboard language.

## Architecture

The Design System is located in `lib/design_system/` and follows a token-based architecture:

| Directory | Content | Purpose |
|-----------|---------|---------|
| `tokens/` | `DSColors`, `DSTypography`, `DSSpacing`, `DSStyles` | Primitive values (colors, fonts, radii) |
| `widgets/atoms/` | `DSInput`, etc. | Basic standalone components |
| `widgets/molecules/` | `DSCard`, `DSInfoTile`, `DSSectionHeader` | Composite components |

---

## The 5-Tier Gold Standard

To maintain extreme consistency and prevent "token bloat," every configuration category (Typography, Spacing, Elevation, Animations) must adhere to a **3-to-5 tier scale**.

- **XS / SM**: Secondary, compact, or micro-level details.
- **MD**: The standard "Source of Truth" for most UI elements.
- **LG / XL**: Primary headers, prominent CTAs, and high-impact containers.

Developers should **never** add "one-off" tokens (e.g., `spacing23`). If a value doesn't fit the 5-tier scale, the layout should be adjusted to fit the system, rather than the system expanding to fit a specific layout.

---

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

## Layout Patterns

### Integrated Header System

To create a premium, "unified" feel for complex screens (Forms, Tabbed Lists), we use the Integrated Header Pattern.

**Key Components:**
- **`AppHeaderBar`**: Set `showBottomBorder: false` to remove the separation line.
- **Sub-Header Container**: A branded `Container` with the global `primaryColor` and `DSSpacing.xl` bottom-corner rounding.
- **`DSSegmentedSelector`**: Integrated directly into the sub-header with borderless styling and white-alpha unselected states.

**Usage Rules:**
- The sub-header **must** use `Theme.of(context).primaryColor`.
- It **must** have a subtle shadow matching the primary color's tone.
- Unselected text/icons in the selector should use `DSColors.white.withValues(alpha: 0.7)`.

---

## Components

### `DSInput`
Replaces the old `StyledTextBox`. Handles text entry, password visibility toggles, and follows the modern "filled" look.

### `DSCard`
Replaces raw `Container` or `Card` for lists and summaries. Provides consistent rounding and shadows.

### `DSGlass` + `DSGlassCard`
Shared frosted-glass language:

| Tone | Base color | Use |
|------|------------|-----|
| `DSGlassTone.chrome` | **Primary green** frosted, **mode-aware** | Header + bottom nav |
| `DSGlassTone.card` | Neutral elevated (α 0.90) | Auth forms, chips |

**Chrome light vs dark** (same API, different density):

| Mode | Fill α | Blur | Why |
|------|--------|------|-----|
| Light | **0.88** + white sheen | 24 | Pale scaffolds wash green; denser + sheen = brand glass, readable white glyphs |
| Dark | **0.50** | 28 | Thinner frost over dark UI / scenery |

**Requirements for real glass (not solid paint):**
1. `appBarTheme` / `bottomNavigationBarTheme` **transparent** in [DSTheme]
2. Header frost in `AppBar.flexibleSpace` via [DSGlassChrome]
3. Tab roots: `extendBody: true` for nav over content; **do not** combine `extendBodyBehindAppBar` with a manual top inset (double gap)

Use `DSGlass` / `DSGlassChrome` only — no hardcoded bar fills.

| API | Use |
|-----|-----|
| `DSGlass.fill(context, tone: chrome)` | Primary glass bar fill |
| `DSGlass.onChrome` / `onChromeMuted` / `onChromeInactive` | White glyphs on primary chrome |
| `DSGlass.border` / `filter` / `shadow` | Edge, blur, elevation |
| `DSGlass.chromeHeight` | Header / nav height (72) |
| `DSGlassCard` | Card widget; `compact: true` for chips |

**Chrome rule:** header + nav use primary glass + white foreground (not neutral card glass).

### `DSInfoTile`
The standard for displaying key-value pairs (e.g., in Delivery Details).

---

## Usage Rules

1. **Tokens Over Raw Values**: Use `DSColors.primary` instead of `Color(0xFF...)`.
2. **Typography Over Direct Styles**: Use `DSTypography.body()` instead of `TextStyle(...)`.
3. **Consistency**: If a component needs a specific variation, use `.copyWith()` on the existing DS token.
