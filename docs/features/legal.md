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
| `terms_screen.dart` | `/terms` | Terms of Service (static content) |
| `privacy_screen.dart` | `/privacy` | Privacy Policy (static content) |

---

## Notes

- Both screens display static markdown/HTML content loaded from assets or a remote URL.
- Linked from the login screen footer and Profile.
- If the content source changes (asset vs. remote), update both screens and this doc.
