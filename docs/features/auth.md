<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/features/auth/login_screen.dart
    lib/features/auth/reset_password_screen.dart
    lib/features/auth/widgets/auth_layout.dart
    lib/features/auth/widgets/auth_illustration.dart

  Update this document whenever you change any of those files.
  Each of those files carries a header comment: "DOCS: docs/features/auth.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Feature — Auth

## Files

| File | Route | Purpose |
|------|-------|---------|
| `lib/features/auth/login_screen.dart` | `/login` | Phone + password login |
| `lib/features/auth/reset_password_screen.dart` | `/reset-password` | Forgot password (unauth) |
| `lib/features/auth/reset_password_screen.dart` | `/change-password` | Change password (auth) |
| `lib/features/auth/widgets/auth_layout.dart` | — | Shell, form card, header, icon badge, CTA, strength meter |
| `lib/features/auth/widgets/auth_animated_background.dart` | — | Soft drifting brand orbs (reduced-motion aware) |
| `lib/features/auth/widgets/auth_illustration.dart` | — | Brand SVG/PNG loader (`AuthLogoMark`) |

---

## Brand assets

| Constant | Path | Use |
|----------|------|-----|
| `AppAssets.fsiIcon` | `assets/images/fsi_icon.svg` | Login logo mark |
| `AppAssets.fsiLogo` | `assets/images/fsi_logo.svg` | Wider wordmark placements |

UI chrome that is **not** brand art uses Material icons only:
- Secure session → `Icons.verified_user_outlined`
- Contact admin → `Icons.support_agent_rounded`
- Reset / change password → `Icons.lock_reset_rounded` / `Icons.shield_rounded` via `AuthIconBadge`
- Theme toggle → light/dark mode icons

---

## `login_screen.dart`

### Flow

1. Courier enters **phone number** and password.
2. `POST /login` with device metadata.
3. On success: store token + courier, session fingerprint check, navigate via `goToDashboardAfterSubmit`.
4. Errors: validation inline, unauthorized/network/rate-limit snackbars; update banner can disable Sign In.

### UI

- `AuthShell` + `DsBrandBackdrop` at **standard** intensity (login-level scenery)
- Logo only (`AppAssets.fsiIcon`) — no filler subtitle / secure-session copy
- Floating labels on fields, glass form card, compact contact + version footer

### Backdrop intensity (DX)

Scenic chrome is **not** one-size-fits-all. Use presets from
`lib/design_system/widgets/ds_brand_backdrop.dart`:

| Preset | Use |
|--------|-----|
| `DsBackdropIntensity.none` | Dense tools / no scenery |
| `DsBackdropIntensity.quiet` | Splash, permissions, update, terms, change-password |
| `DsBackdropIntensity.standard` | Login / forgot-password (`AuthShell`) |
| `DsBackdropIntensity.vivid` | Marketing peaks only |

Shared gate chrome:
- `DSGateShell` — quiet shell for non-auth gates (permissions, update)
- `DSGlassCard` — frosted cards (also used by `AuthFormCard`)
- `DSFormActionLink` + form rhythm tokens for form stacks

```dart
// Login
AuthShell(child: ...)

// Permissions / update
DSGateShell(backdropIntensity: DsBackdropIntensity.quiet, child: ...)
```
- **Debug UI chrome** (when `showDebugUiProvider` is true): API host panel + **View splash screen**. Global top-left **DEBUG** chip toggles chrome (see `docs/core/settings.md`)

---

## `reset_password_screen.dart`

| Mode | Entry | API | Success |
|------|-------|-----|---------|
| Unauthenticated | Login → Forgot password | `POST /reset-password` | → `/login` |
| Authenticated | Profile → Change password | `POST /change-password` | → dashboard |

UI: icon badge header (no custom illustration SVG), form card, password strength meter, min 8 chars client check.

**Unauthenticated only:** DS callout above courier-code field — if code unknown, contact admin or manager (`auth.reset_password.courier_code_hint`). Uses `Icons.support_agent_rounded` + primary surface tokens (same contact chrome as login).
