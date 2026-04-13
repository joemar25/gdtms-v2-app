<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/features/auth/login_screen.dart
    lib/features/auth/reset_password_screen.dart

  Update this document whenever you change any of those files.
  Each of those files carries a header comment: "DOCS: docs/features/auth.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Feature — Auth

## Files

| File | Route | Purpose |
|------|-------|---------|
| `lib/features/auth/login_screen.dart` | `/login` | Email + password login form |
| `lib/features/auth/reset_password_screen.dart` | `/reset-password` | Request password reset email |

---

## `login_screen.dart`

### Flow

1. Courier enters email and password.
2. Calls `AuthService.login(email, password)`.
3. On success: `AuthNotifier.login(token)` → router redirects to `/dashboard`.
4. On `ApiUnauthorized`: shows "Invalid credentials" inline error.
5. On `ApiNetworkError`: shows offline snackbar.

### Notes

- Does not redirect to `/initial-sync` — that is handled by the router redirect logic after `authProvider` transitions to `authenticated`.
- "Forgot password?" link navigates to `/reset-password`.

---

## `reset_password_screen.dart`

### Flow

1. Courier enters registered email.
2. Calls `AuthService.resetPassword(email)`.
3. On success: shows confirmation message; courier checks email.
4. On error: inline error display.

### Notes

- This screen does **not** handle the reset token link — that is a web flow handled by the backend.
