<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/features/legal/terms_screen.dart
    lib/features/legal/privacy_screen.dart

  Update this document whenever you change any of those files.
  Each of those files carries a header comment: "DOCS: docs/features/legal.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Feature — Legal

## Files

| File | Route | Purpose |
|------|-------|---------|
| `terms_screen.dart` | `/terms` | Terms of Service (static content, bundled asset) |
| `privacy_screen.dart` | `/privacy` | Privacy Policy (backend-managed, fetched from API) |
| `user_guide_screen.dart` | `/user-guide` | User Guide (static content, bundled asset) |

---

## Notes

- `terms_screen.dart` and `user_guide_screen.dart` load static markdown from bundled assets (`assets/legal/terms.md`, `assets/legal/user_guide.md`) via `rootBundle.loadString`.
- `privacy_screen.dart` fetches its content from `GET /privacy-policy` (no auth required) instead of a bundled asset, so the backend/web team can edit the policy without an app release. The response is cached in SharedPreferences (`privacy_policy_cache_v1`) so the screen still renders offline after the first successful load; on a failed refresh it keeps showing the cached copy with a `ConnectionStatusBanner`, and only shows a retry error state if no cache exists yet.
- All three screens render their markdown with the shared `LegalMarkdownText` widget (defined in `terms_screen.dart`).
- Linked from Profile → Legal section. `/terms` is also the forced acceptance gate the router redirects to via `terms_accepted_version` in SharedPreferences (see `app_router.dart`).
