# Update System

The app checks a remote version manifest on startup and prompts the courier
to update when a newer version is available, deep-linking to the platform
app store listing (Play Store on Android, App Store on iOS).

## Architecture

The system is split into three layers:

1.  **`UpdateInfo` (Model)**: Represents the metadata fetched from the server.
2.  **`UpdateService` (Service)**: A singleton handling the version check and
    opening the store listing.
3.  **`UpdateProvider` (Riverpod)**: Manages UI state (`updateInfo`,
    `isDismissed`) and exposes `checkForUpdate()` / `openUpdate()`.

---

## Remote Manifest (`mobile-version.json`)

The system expects a JSON file at `${apiBaseUrl}/mobile-version.json`.

### Structure

```json
{
  "latest_version": "1.0.5",
  "minimum_version": "1.0.0",
  "release_notes": "Added new delivery status tracking and performance improvements.",
  "force_update": false
}
```

- **`latest_version`**: The newest available version.
- **`minimum_version`**: The lowest version allowed to run. If the app is below this, the update is **Mandatory**.
- **`force_update`**: Optional override that forces the Mandatory state regardless of version.

The backend may still serve `android_download_url` / `ios_store_url` /
`file_size_mb` / `checksum_sha256` fields for other consumers, but the app no
longer reads them — see "Direct APK distribution (removed)" below.

---

## Workflow

### 1. Version Check

Triggered on app startup in `app.dart` via `ref.read(updateProvider.notifier).checkForUpdate()`.

- It compares the server's `latest_version` with `AppVersionService.version`.
- If a newer version exists, `updateProvider` state is updated with `UpdateInfo`.

### 2. Mandatory vs. Optional

- **Mandatory**: If current version < `minimum_version` (or `force_update` is true). `_MandatoryUpdateOverlay` in `app.dart` shows a non-dismissible full-screen overlay.
- **Optional**: Otherwise. `UpdateBannerOverlay` shows a dismissible banner.

Both route the user to `/update` (`UpdateScreen` → `AppUpdateCard`).

### 3. Opening the store

Tapping the update CTA calls `UpdateNotifier.openUpdate()` →
`UpdateService.launchStoreListing()`:

- **Android**: Opens `https://play.google.com/store/apps/details?id=<packageName>`
  when `kIsPlayStoreDistribution` (see `lib/core/config.dart`) is true.
- **iOS**: Opens the configured App Store URL (`_kIosAppStoreUrl` in `UpdateService`).

There is no in-app download/progress/install step — the store handles the
binary transfer and installation.

---

## Direct APK distribution (removed)

Earlier versions of this app downloaded the APK directly from
`android_download_url` and installed it via the `open_filex` plugin
(`UpdateService.downloadUpdate` / `verifyChecksum` / `installUpdate`). That
mechanism was removed because:

1. `open_filex` declares `android.permission.REQUEST_INSTALL_PACKAGES` in its
   own library manifest, which Gradle's manifest merger injects into the
   built app **regardless of the app's own AndroidManifest.xml** — removing
   the `<uses-permission>` line alone does not remove it from a build that
   still depends on `open_filex`.
2. Google Play only approves this permission for apps whose core purpose is
   installing other apps (browsers, app stores, file managers, MDM); a
   courier delivery app doesn't qualify, so shipping it risked Play Store
   rejection/suspension.

If direct/internal APK distribution (outside Play Store) is needed again,
re-add the `open_filex` dependency and the removed service methods (see git
history for the commit that removed them) on a build meant only for that
channel — not by flipping `kIsPlayStoreDistribution`, which only controls
the harmless Play Store deep-link and cannot restore a working installer
inside a build that no longer bundles `open_filex`.

---

## UI Components

### `UpdateBannerOverlay` / `_MandatoryUpdateOverlay`

- Root `OverlayEntry`s in `app.dart`, route-aware (hidden on `/profile`, `/update`, `/splash`, etc).
- Tap navigates to `/update`.

### `AppUpdateCard` (`update_card_widget.dart`)

- Shows current vs. latest version, Required/Optional badge, collapsible release notes.
- Single "Update on Play Store" button calling `openUpdate()`.

### `ProfileScreen`

- Contains a "Check for Updates" section using the same `AppUpdateCard`.

---

## Configuration

The manifest URL is derived from the `apiBaseUrl` in `lib/core/config.dart`.

- **Base URL**: `http://YOUR_API_BASE_URL/api/mbl`
- **Manifest**: `http://YOUR_API_BASE_URL/api/mbl/mobile-version.json`

> [!NOTE]
> For local development, ensure your local server serves this JSON file or mock the response in `UpdateService` for testing.
