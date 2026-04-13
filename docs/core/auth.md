<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/core/auth/auth_provider.dart
    lib/core/auth/auth_storage.dart
    lib/services/auth_service.dart

  Update this document whenever you change any of those files.
  Each of those files carries a header comment: "DOCS: docs/core/auth.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Core — Auth

## Files

| File | Role |
|------|------|
| `lib/core/auth/auth_provider.dart` | Riverpod `StateNotifier` for auth state |
| `lib/core/auth/auth_storage.dart` | Secure-storage read/write for the bearer token |
| `lib/services/auth_service.dart` | Login/logout API calls |

---

## `auth_provider.dart`

Exposes `authProvider` — a `StateNotifierProvider<AuthNotifier, AuthState>`.

### `AuthState` values

| Value | Meaning |
|-------|---------|
| `AuthState.unknown` | Initial state before storage is checked |
| `AuthState.authenticated` | Valid token found in secure storage |
| `AuthState.unauthenticated` | No token or token was cleared |

### Key methods on `AuthNotifier`

- `restoreSession()` — reads from `AuthStorage`; called by `SplashScreen`.
- `login(token)` — writes token to `AuthStorage`, transitions to `authenticated`.
- `logout()` — clears token from `AuthStorage`, transitions to `unauthenticated`, navigates to `/login`.

### Router integration

`_RouterNotifier` in `app_router.dart` listens to `authProvider` and calls `router.refresh()` whenever state changes, triggering the redirect logic.

---

## `auth_storage.dart`

Thin wrapper around `flutter_secure_storage`.

- `saveToken(String token)` — stores bearer token.
- `getToken()` → `String?` — retrieves token; `null` means no session.
- `clearToken()` — called on logout.

**No expiry logic is implemented here.** The server returns `401` when the token is expired; `ApiClient` maps that to `ApiUnauthorized`, and `AuthNotifier.logout()` is called.

---

## `auth_service.dart`

Handles the login and reset-password network calls.

- `login(email, password)` → `ApiResult` — POST to `/auth/login`.
- `resetPassword(email)` → `ApiResult` — POST to `/auth/forgot-password`.

Does **not** persist the token — that is `AuthNotifier.login(token)`'s job.
