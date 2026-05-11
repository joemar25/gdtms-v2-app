# Typography Guide – FSI Design System

## Overview

The FSI Design System uses **Montserrat** (from Google Fonts) for all typography. The system is optimized for performance and consistency across the app.

---

## Font Family

- **Primary Font**: [Montserrat](https://fonts.google.com/specimen/Montserrat) (Variable weight via Google Fonts)
- **Font Weights Available**: 100–900 (we use 400, 600, 700, 800, 900)

---

## Type Scale (5 Standard Tiers)

| Size | Value | Use Case | Example |
|------|-------|----------|---------|
| **XS** | 10px | Labels, badges, micro text | Badge labels, nav hints |
| **Sm** | 12px | Captions, timestamps, meta | Timestamps, subtitles |
| **Md** | 14px | Body text (default) | List items, form inputs |
| **Lg** | 16px | Section titles | Subtitles, secondary headings |
| **Xl** | 18px | Headings, display | Page titles, main headings |

### Specialty Sizes

- **Hero** (28px): Large display text for important metrics
- **DisplayHero** (42px): Premium display (e.g., wallet balances, big numbers)

---

## Typography Styles

### Display & Heading

```dart
// Hero display with tight line height
DSTypography.display(color: Colors.black)
// Weight: 900 | Letter spacing: -0.5 | Size: 18px

// Section headings
DSTypography.heading(color: Colors.black)
// Weight: 800 | Letter spacing: -1.0 | Size: 18px

// Subsection headings
DSTypography.title(color: Colors.black)
// Weight: 700 | Letter spacing: -0.5 | Size: 16px
```

### Body & Content

```dart
// Main body text
DSTypography.body(color: Colors.black)
// Weight: 400 | Letter spacing: 0 | Size: 14px

// Smaller secondary text
DSTypography.caption(color: Colors.grey)
// Weight: 400 | Letter spacing: 0 | Size: 12px

// Subtitles / Secondary headings
DSTypography.subTitle(color: Colors.black)
// Weight: 600 | Letter spacing: -0.5 | Size: 14px
```

### Interactive Elements

```dart
// Button text
DSTypography.button(color: Colors.white)
// Weight: 700 | Letter spacing: +0.3 | Size: 14px

// Labels & tags
DSTypography.label(color: Colors.black)
// Weight: 700 | Letter spacing: +0.8 | Size: 10px
```

---

## Letter Spacing

| Level | Value | Use Case |
|-------|-------|----------|
| **Extra Loose** | +0.8px | Labels, caps |
| **Loose** | +0.3px | Buttons, CTAs |
| **None** | 0px | Body, captions |
| **Slightly Tight** | -0.5px | Headings, titles |
| **Tight** | -1.0px | Display, large headings |

---

## Line Height

| Level | Value | Use Case |
|-------|-------|----------|
| **Tight** | 1.2 | Headings, buttons |
| **Default** | 1.5 | Body text, labels |
| **Loose** | 1.75 | Long-form content |

---

## Usage Examples

### In Widgets

```dart
// Custom Text with typography
Text(
  'Hello Courier',
  style: DSTypography.heading(color: Colors.black),
)

// With custom sizing
Text(
  'Order Details',
  style: DSTypography.title(
    color: Colors.black,
    fontSize: 18.0,
    fontWeight: FontWeight.w700,
  ),
)
```

### In Theme (Auto-Applied)

All Material widgets (Text, AppBar, ListTile, etc.) automatically use the proper typography:

```dart
// AppBar automatically uses heading style
AppBar(title: Text('My Title'))

// Button automatically uses button style
ElevatedButton(
  onPressed: () {},
  child: Text('Click Me'), // Uses button typography
)
```

---

## Performance Notes

✅ **Optimized for Performance:**
- Font family is cached at compile-time (`_montserratFamily`)
- No runtime lookups on each TextStyle creation
- Google Fonts integrated via `pub` (no network calls after build)

✅ **Tree-Shaking:**
- Icons (Montserrat doesn't use icons, so no icon font bloat)
- Only used font weights are included in the build

---

## Customization

To override typography for a specific widget:

```dart
// Override just the color
Text(
  'Hello',
  style: DSTypography.body(color: Colors.red),
)

// Override size & weight
Text(
  'Important',
  style: DSTypography.body(
    fontSize: 16.0,
    fontWeight: FontWeight.w700,
    color: Colors.red,
  ),
)
```

---

## Constraints (Design System Stability)

⚠️ **DO NOT:**
- Add new font families without Design System approval
- Create more than 5 size tiers
- Use font sizes outside the defined scale
- Apply inline font customization without DSTypography

✅ **DO:**
- Use DSTypography methods for all text
- Request new variants through design review
- Keep typography consistent across screens
