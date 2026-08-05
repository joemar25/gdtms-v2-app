<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  Canonical post-login UI language for the FSI courier app.

  Sources of truth in code:
    lib/design_system/          — tokens, layout, glass, backdrop
    lib/shared/widgets/stat_widgets.dart — StatCard, ScanButton
    lib/features/dashboard/     — reference composition (default + new-feel)
    lib/features/initial_sync/widgets/sync_ai_visuals.dart — sync loader

  Update this file when shell UI patterns change. Tokens detail: styles.md
  ══════════════════════════════════════════════════════════════════════════════
-->

# Design System — Post-login shell language

This document captures the **UI language established on the dashboard and
related shells**, so every other tab and list page can match without inventing
one-off styles.

Token primitives (colors, type, spacing) remain in [styles.md](styles.md).
This file is about **composition rules** — which widget, which palette, which
motion.

---

## 1. Screen roles (pick one shell)

| Role                           | Wrapper                                            | Backdrop                                | Examples                                               |
| ------------------------------ | -------------------------------------------------- | --------------------------------------- | ------------------------------------------------------ |
| **Tab root**                   | Transparent `Scaffold` inside `ScaffoldWithNavBar` | `DsBackdrop.shell` (once, in nav shell) | Dashboard, Bagsakan, Wallet, Profile                   |
| **Pushed list / detail**       | **`DsAppScaffold`**                                | `shell` automatic                       | Dispatch list, deliveries, sync history, payout detail |
| **Auth**                       | `AuthShell`                                        | `auth`                                  | Login                                                  |
| **Gate**                       | `DSGateShell`                                      | `gate`                                  | Splash, permissions, update, terms                     |
| **Loader / full-screen focus** | Custom `Scaffold` + `DsBrandBackdrop`              | `auth`-like or custom                   | Initial sync, **Sync Now overlay**                     |
| **Camera / immersive**         | Plain `Scaffold`                                   | none                                    | Scan, signature                                        |

**Rules**

- Never paint a second brand backdrop under a tab that already has shell.
- Never use solid rainbow scaffolds for post-login work screens.
- Prefer `DsAppScaffold` over bare `Scaffold` for every pushed route.

**Gap (apply next):** Bagsakan / Wallet / Profile still use bare `Scaffold` on
tab roots — OK if transparent + shell parent; audit for solid backgrounds that
kill the scenery.

---

## 2. Brand palette (work UI)

Dashboard metric tiles and primary CTAs use **only**:

| Token                 | Use                                                              |
| --------------------- | ---------------------------------------------------------------- |
| `DSColors.primary`    | Default accent, most tiles, POD scan, success chrome             |
| `DSColors.gold`       | Highlight primary _work_ (dispatch accept / scan dispatch)       |
| Neutral card surfaces | `cardLight` / `cardElevatedDark` + soft primary wash when active |

**Do not** use status rainbow (`error` / `pending` / `returned` / `accent`) as
_decorative_ tile colors on overview grids.

Status colors **are** correct for:

- Delivery status badges in lists
- Connectivity dots (online / API / offline)
- Error text, destructive actions, validation

### Accent hierarchy (dashboard reference)

1. **Gold** — “start work” (pending dispatch, scan dispatch)
2. **Primary green** — everything else in the grid + scan POD
3. **Neutral** — empty / zero tiles (`subdued: true`)

---

## 3. Surfaces & chrome

| Surface             | API                                               | Notes                                          |
| ------------------- | ------------------------------------------------- | ---------------------------------------------- |
| Shell scenery       | `DsBrandBackdrop` / `DsBrandBackdropConfig.shell` | One painter; intensity only in config          |
| Header + bottom nav | `DSGlass` / `DSGlassChrome`                       | Primary frosted chrome; theme bars transparent |
| Content cards       | Solid elevated cards (not glass for work metrics) | `StatCard`, `DSCard`                           |
| Glass cards         | `DSGlassCard`                                     | Auth / marketing only — not metric grids       |

**Card box rules (`StatCard` / `ScanButton`)**

- **Fixed height** (not soft min-only that collapses on reverse face).
- Radius: `DSStyles.radius2XL`.
- Soft shadow; active = light primary border wash.
- Left **3px brand accent bar** on metric tiles.

---

## 4. Section headers

Standard pattern (dashboard default + new-feel):

```dart
Text(
  'section.key'.tr().toUpperCase(),
  style: DSTypography.caption(color: labelSecondary).copyWith(
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  ),
)
```

- Shared i18n keys across layouts (no hardcoded “Today” / “Quick scan”).
- Optional motion: fade + slight `slideX` on section titles.
- `DSSectionHeader` exists but is **primary-colored**; for shell grids prefer
  **secondary label** caption (dashboard style) so gold/green CTAs stay louder.

---

## 5. Metric tiles — `StatCard`

**File:** `lib/shared/widgets/stat_widgets.dart`

| Concern | Rule                                                    |
| ------- | ------------------------------------------------------- |
| Color   | `primary` or `gold` only                                |
| Empty   | `subdued: true` when count is 0                         |
| Details | Pass `details:` for hold-to-reveal                      |
| Height  | Lock with `minHeight` (dashboard uses **132**)          |
| Entry   | `.dsDashboardCardEntry(delay: DSAnimations.stagger(n))` |

**Hold-to-reveal (NBA 2K pattern)**

1. Hold → reverse face **stays open**
2. Tap **✕** → hide details only
3. Tap rest of card → `onTap` (navigate)
4. Face shows “Hold for details”; reverse shows full blurb + “Tap card to open”

**In-card motion (respect reduced motion)**

- Count-up `0 → N`
- Icon pulse + accent bar pulse when active
- OPEN chip scale-in

Reuse `StatCard` on Wallet summary, Bagsakan stats, Profile counters — do **not**
rebuild rainbow tiles.

---

## 6. Scan / primary CTAs — `ScanButton`

| Concern | Rule                                          |
| ------- | --------------------------------------------- |
| Color   | Gold = dispatch path; primary = POD / default |
| Height  | Fixed (**128** on dashboard)                  |
| Details | Hold-to-reveal same as `StatCard`             |
| Entry   | `.dsDashboardCtaEntry(delay: …)`              |
| Face    | Large centered icon + label + hold hint       |
| Reverse | Same fixed box; never collapse                |

---

## 7. Motion system

| Preset          | Extension                 | Use                       |
| --------------- | ------------------------- | ------------------------- |
| Card grid entry | `dsDashboardCardEntry`    | Stat grids                |
| CTA entry       | `dsDashboardCtaEntry`     | Scan / filled CTAs        |
| Generic card    | `dsCardEntry`             | Lists, forms              |
| Generic CTA     | `dsCtaEntry`              | Buttons outside dashboard |
| Stagger         | `DSAnimations.stagger(n)` | 80 ms default step        |

**Do not** invent random durations; use `dMicro` / `dFast` / `dNormal` / `dHero`.

Always honor `MediaQuery.disableAnimationsOf(context)`.

---

## 8. Sync UX (one visual language)

| Context                               | UI                                                                      |
| ------------------------------------- | ----------------------------------------------------------------------- |
| Post-login bootstrap                  | `InitialSyncScreen` + `sync_ai_visuals.dart`                            |
| Manual Sync Now (dashboard / history) | `showSyncOverlay` → same orb, phase rail, status stream, brand backdrop |

Shared pieces:

- `SyncAiOrb`
- `SyncAiPhaseRail` (Start → Load → Sort → Done)
- `SyncAiStatusStream`
- `syncPhaseFromProgress` / `syncPhaseFromQueueProgress`

**Forbidden:** dark full-screen dialog + spinner-only for queue flush.

---

## 9. Copy rules (courier-facing)

- Plain delivery English (EN + FIL via easy_localization).
- No “AI / engine / workspace / fetch index” jargon on loader screens.
- Section titles and button labels shared between default and new-feel layouts.

---

## 10. Apply map — other dashboard-area pages

Priority for **standardization** (highest first):

| Page                | Shell                                               | Cards / color                                  | Motion                                | Notes                        |
| ------------------- | --------------------------------------------------- | ---------------------------------------------- | ------------------------------------- | ---------------------------- |
| **Bagsakan** tab    | Ensure transparent + shell; no solid opaque full bg | Stat-like summaries → `StatCard` brand palette | `dsDashboardCardEntry` on group cards | Replace rainbow chips if any |
| **Wallet** tab      | Same                                                | Earnings / pending tiles → primary/gold only   | Stagger entry                         | Keep SecureView for PII      |
| **Profile** tab     | Same                                                | Prefer `DSCard` + section caption style        | `dsCardEntry`                         | Already partial DS           |
| **Dispatch list**   | `DsAppScaffold` ✓                                   | List rows stay status-colored badges           | `dsCardEntry` on rows                 | OK semantic status           |
| **Deliveries list** | `DsAppScaffold` ✓                                   | Status badges OK                               | Stagger                               |                              |
| **Sync history**    | `DsAppScaffold` ✓                                   | Header Sync Now uses overlay ✓                 |                                       | Overlay already aligned      |
| **Notifications**   | `DsAppScaffold` ✓                                   | Error accent OK for alerts                     | `dsCardEntry`                         |                              |
| **Scan**            | Immersive                                           | N/A                                            | N/A                                   | Keep camera-first            |

### Checklist per screen

1. [ ] Correct shell wrapper (tab vs `DsAppScaffold`)
2. [ ] No second backdrop / no solid white full-bleed killing shell
3. [ ] Glass chrome header (`AppHeaderBar`) unless immersive
4. [ ] Section titles = uppercase caption secondary (or shared key)
5. [ ] Metric tiles = `StatCard` + primary/gold only
6. [ ] Primary CTAs = brand green or gold solid (not random Material blue)
7. [ ] Entry motion = DS presets + stagger
8. [ ] Status colors only for **status**, not decoration
9. [ ] i18n for all courier strings
10. [ ] Reduced-motion safe

---

## 11. Code map (quick import)

```
lib/design_system/
  design_system.dart          // barrel
  tokens/ds_colors.dart
  tokens/ds_animations.dart   // dashboardCardEntry / dashboardCtaEntry
  layout/ds_app_scaffold.dart
  backdrop/                   // shell / gate / auth
  widgets/molecules/ds_card.dart
  widgets/molecules/ds_glass_*.dart

lib/shared/widgets/
  stat_widgets.dart           // StatCard, ScanButton
  app_header_bar.dart
  bottom_nav_bar.dart

lib/features/dashboard/widgets/dashboard_components.dart  // composition reference
lib/features/sync/widgets/sync_now_button.dart             // SyncOverlay
lib/features/initial_sync/widgets/sync_ai_visuals.dart
```

---

## 12. What not to do

- Rainbow overview tiles (red/orange/purple/blue per metric)
- Glass metric cards on the work dashboard (hard to read outdoors)
- Soft `minHeight` only on hold-reveal tiles (causes collapse / overflow)
- Hold-to-show that **hides on release** (unreadable)
- Separate “old spinner” sync UI vs initial sync
- Hardcoded English section titles when new-feel already has keys
- Nested `DsBrandBackdrop` under shell tabs
