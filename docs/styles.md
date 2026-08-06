# Design System Styles

This document outlines the design tokens and components used in the GDTMS v2 Mobile App. All UI elements should be built using these tokens to ensure consistency and a premium feel.

> **Composition rules** (shell vs gate, brand-only metric tiles, hold-to-reveal, dashboard motion, sync overlay) live in **[design-system.md](design-system.md)**. Use that doc when aligning Bagsakan / Wallet / Profile / lists to the dashboard language.

## Architecture

The Design System is located in `lib/design_system/` and follows a token-based architecture:

| Directory            | Content                                             | Purpose                                 |
| -------------------- | --------------------------------------------------- | --------------------------------------- |
| `tokens/`            | `DSColors`, `DSTypography`, `DSSpacing`, `DSStyles` | Primitive values (colors, fonts, radii) |
| `widgets/atoms/`     | `DSInput`, etc.                                     | Basic standalone components             |
| `widgets/molecules/` | `DSCard`, `DSInfoTile`, `DSSectionHeader`           | Composite components                    |

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

| Method       | Usage                                      |
| ------------ | ------------------------------------------ |
| `heading()`  | Large screen titles (w800)                 |
| `title()`    | Standard titles (w700)                     |
| `subTitle()` | Section headers or secondary titles (w600) |
| `body()`     | Regular paragraph text (w400)              |
| `button()`   | Button labels (w700)                       |
| `caption()`  | Small details, timestamps (w400)           |
| `label()`    | Small uppercase metadata headers (w700)    |

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

### Integrated Header System (continuous chrome)

Complex screens (delivery **update**, failed-delivery filters, bagsakan form) treat the sub-header as a **header extension** — one solid FSI green unit from status bar through segment strip.

**Always pair:**

```dart
AppHeaderBar(showBottomBorder: false, ...)  // solid brand AppBar
DsIntegratedSubHeader(
  child: DsIntegratedSubHeader.segment(...), // shared look, own options
)
```

| Token / rule | Value |
|--------------|--------|
| Brand fill | `DSColors.primary` `#307539` (dark: `primaryDark`) — **exact**, not seed |
| AppBar continuous | Opaque brand, `forceMaterialTransparency: false` |
| Status bar | Solid brand (`DsShellSystemUi.shell`) — **never transparent** (black void) |
| Strip | Solid brand, bottom radius only |
| Segment height | `segmentHeight` = **48**, horizontal icon+label, `pillInset` = 4 |
| Selected glyph | Exact primary on white pill |
| Unselected glyph | White α ~0.90 |

**Decoupled:** features own options/state/callbacks; only share `DsIntegratedSubHeader.segment`.

**Tests (do not delete):** `test/design_system/ds_continuous_chrome_test.dart` — anti-black + solid primary regressions.

Full rules: [design-system.md](design-system.md) § Continuous chrome.

---

## Components

### `DSInput`

Replaces the old `StyledTextBox`. Handles text entry, password visibility toggles, and follows the modern "filled" look.

### `DSCard`

Replaces raw `Container` or `Card` for lists and summaries. Provides consistent rounding and shadows.

### `DSGlass` + `DSGlassCard`

Shared frosted-glass language:

| Tone                 | Base color                                | Use                 |
| -------------------- | ----------------------------------------- | ------------------- |
| `DSGlassTone.chrome` | **Primary green** frosted, **mode-aware** | Header + bottom nav |
| `DSGlassTone.card`   | Neutral elevated (α 0.90)                 | Auth forms, chips   |

**Chrome light vs dark** (rich brand green glass — translucent, not pale mint):

| Mode  | Green α | White frost | Blur | Why                                                                 |
| ----- | ------- | ----------- | ---- | ------------------------------------------------------------------- |
| Light | **0.72** | **0.04**   | 28   | Rich FSI green over white lists; low frost so not mint              |
| Dark  | **0.74** | **0.03**   | 36   | Stronger green over dark cards; blur still shows UI structure       |

Combined baseline stays glass (blur of real UI + green wash). Do **not** re-add a
post-blur brightness `ColorFilter` on chrome — it washed FSI green to pale sage.

`DSGlass.headerShadow()` / floating `shadow()` use a strong primary ambient glow
so chrome still reads brand-green when the blurred backdrop is pale.

**Header vs glass (anti dark-spot rule):**

| Surface | Paint | Why |
|---------|--------|-----|
| **AppHeaderBar** (all brand screens) | **Solid** `DSColors.primary` / `primaryDark` | Square bottom — no L/R radius |
| Continuous header | Solid brand + `DsIntegratedSubHeader` foot | One unit |
| **Floating bottom nav** | `DSGlassChrome` frost | Real glass OK on pill (full rim, no header corner bug) |

**Never:** transparent brand AppBar, `forceMaterialTransparency` on headers, header box shadows under rounded corners.

Use `DSGlass` / `DSGlassChrome` only — no hardcoded bar fills. Edge: `header` | `floating` | `strip`.

| API                                                       | Use                                    |
| --------------------------------------------------------- | -------------------------------------- |
| `DSGlass.fill(context, tone: chrome)`                     | Primary glass bar fill                 |
| `DSGlass.onChrome` / `onChromeMuted` / `onChromeInactive` | White glyphs on primary chrome         |
| `DSGlass.border` / `filter` / `shadow`                    | Edge, blur, elevation                  |
| `DSGlass.chromeHeight`                                    | Header / nav height (72)               |
| `DSGlassCard`                                             | Card widget; `compact: true` for chips |

**Chrome rule:** header + nav use primary glass + white foreground (not neutral card glass).

### `DSInfoTile`

The standard for displaying key-value pairs (e.g., in Delivery Details).

---

## Usage Rules

1. **Tokens Over Raw Values**: Use `DSColors.primary` instead of `Color(0xFF...)`.
2. **Typography Over Direct Styles**: Use `DSTypography.body()` instead of `TextStyle(...)`.
3. **Consistency**: If a component needs a specific variation, use `.copyWith()` on the existing DS token.
