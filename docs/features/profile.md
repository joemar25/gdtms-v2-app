<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/features/profile/profile_screen.dart
    lib/features/profile/profile_edit_screen.dart

  Update this document whenever you change any of those files.
  Each of those files carries a header comment: "DOCS: docs/features/profile.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Feature — Profile

## Files

| File | Route | Purpose |
|------|-------|---------|
| `profile_screen.dart` | `/profile` | View profile, preferences, storage info, logout |
| `profile_edit_screen.dart` | `/profile/edit` | Edit courier details |

---

## `profile_screen.dart`

### Sections

- **Profile info**: name, email, courier ID.
- **Available Storage** tile: shows free GB from `DeviceInfoService.getFreeStorageGb()`.
- **`_StorageBanner`**: shown when free storage is below `kStorageWarningGb` (2 GB). Prompts the courier to free space.
- **Preferences**:
  - Compact mode toggle → updates `compactModeProvider`.
  - Sync history retention (1, 3, 5 days) → updates `AppSettings.syncHistoryDays`.
- **Logout** button → calls `AuthNotifier.logout()`.

### Notes

- Storage tile reads from the platform channel — see `docs/core/device.md`.
- If the storage threshold changes, update `constants.dart` (`kStorageWarningGb`) and this doc.

---

## `profile_edit_screen.dart`

### Fields

- Name, phone number — editable.
- Email — read-only (managed by server).

### Flow

1. Pre-fills from `ProfileService.getProfile()`.
2. On save: calls `ProfileService.updateProfile(payload)`.
3. On success: navigates back and refreshes `ProfileScreen`.
