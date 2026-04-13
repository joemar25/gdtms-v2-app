<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/shared/router/app_router.dart
    lib/shared/router/router_keys.dart

  Update this document whenever you change any of those files.
  Each of those files carries a header comment: "DOCS: docs/shared/router.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Shared — Router

## Files

| File | Purpose |
|------|---------|
| `lib/shared/router/app_router.dart` | GoRouter definition, guards, transitions |
| `lib/shared/router/router_keys.dart` | `GlobalKey<NavigatorState>` constants for shell routes |

---

## `app_router.dart`

### Route table (full)

| Route | Screen | Auth required | Location required |
|-------|--------|---------------|-------------------|
| `/splash` | `SplashScreen` | No | No |
| `/login` | `LoginScreen` | No | No |
| `/reset-password` | `ResetPasswordScreen` | No | No |
| `/location-required` | `LocationRequiredScreen` | Yes | No |
| `/initial-sync` | `InitialSyncScreen` | Yes | Yes |
| `/dashboard` | `DashboardScreen` | Yes | Yes |
| `/deliveries` | `DeliveryStatusListScreen` | Yes | Yes |
| `/deliveries/:barcode` | `DeliveryDetailScreen` | Yes | Yes |
| `/deliveries/:barcode/update` | `DeliveryUpdateScreen` | Yes | Yes |
| `/dispatch/eligibility` | `DispatchEligibilityScreen` | Yes | Yes |
| `/dispatch/list` | `DispatchListScreen` | Yes | Yes |
| `/wallet` | `WalletScreen` | Yes | Yes |
| `/wallet/payout/:id` | `PayoutDetailScreen` | Yes | Yes |
| `/wallet/payout/request` | `PayoutRequestScreen` | Yes | Yes |
| `/profile` | `ProfileScreen` | Yes | Yes |
| `/profile/edit` | `ProfileEditScreen` | Yes | Yes |
| `/scan` | `ScanScreen` | Yes | Yes |
| `/history` | `SyncScreen` | Yes | Yes |
| `/notifications` | `NotificationsScreen` | Yes | Yes |
| `/report` | `ReportIssueScreen` | Yes | Yes |
| `/error-logs` | `ErrorLogsScreen` | Yes | Yes |
| `/terms` | `TermsScreen` | No | No |
| `/privacy` | `PrivacyScreen` | No | No |

### Redirect logic

`_RouterNotifier` listens to both `authProvider` and `locationProvider`. On any change it calls `router.refresh()`, which re-evaluates the `redirect` callback:

1. If `AuthState.unauthenticated` → `/login` (unless already on `/login` or `/reset-password` or legal pages).
2. If `AuthState.authenticated` + location `denied` → `/location-required`.
3. Otherwise → allow.

### Tab transitions

Bottom-nav tabs use `_tabTransitionPage()` — a 380ms fade + horizontal slide (`Curves.easeOutQuart`). Do not use the default `GoRoute` transition for tab-level routes.

---

## `router_keys.dart`

Holds `GlobalKey<NavigatorState>` instances for shell route navigators. Required by `GoRouter` when using nested navigation (bottom nav). Do not remove keys that are referenced in `app_router.dart`.
