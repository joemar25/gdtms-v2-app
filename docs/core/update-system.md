# Update System

The application features an in-app update system that allows couriers to download and install new versions of the app without needing to visit an app store. This is particularly useful for internal distribution and ensuring all riders are on compatible versions.

## Architecture

The system is split into three layers:

1.  **`UpdateInfo` (Model)**: Represents the metadata fetched from the server.
2.  **`UpdateService` (Service)**: A singleton handling the technical operations (HTTP GET, file download, checksum verification, and installation triggers).
3.  **`UpdateProvider` (Riverpod)**: Manages the UI state, progress tracking, and user interaction logic.

---

## Remote Manifest (`mobile-version.json`)

The system expects a JSON file at `${apiBaseUrl}/mobile-version.json`.

### Structure

```json
{
  "latest_version": "1.0.5",
  "minimum_version": "1.0.0",
  "download_url": "https://example.com/downloads/app-v1.0.5.apk",
  "release_notes": "Added new delivery status tracking and performance improvements.",
  "file_size_mb": 70.5,
  "checksum_sha256": "a1b2c3d4e5f6..."
}
```

- **`latest_version`**: The newest available version.
- **`minimum_version`**: The lowest version allowed to run. If the app is below this, the update is **Mandatory**.
- **`download_url`**: Direct link to the APK (Android) or informational link.
- **`checksum_sha256`**: (Optional) Used to verify the integrity of the downloaded file.

---

## Workflow

### 1. Version Check

Triggered on app startup in `app.dart` via `ref.read(updateProvider.notifier).checkForUpdate()`.

- It compares the server's `latest_version` with `AppVersionService.version`.
- If a newer version exists, `updateProvider` state is updated with `UpdateInfo`.

### 2. Mandatory vs. Optional

- **Mandatory**: If current version < `minimum_version`. The UI should block navigation or show a non-dismissible overlay.
- **Optional**: If current version >= `minimum_version` but < `latest_version`. Shows a dismissible banner.

### 3. Download & Verify

When the user taps "Update":

1.  The APK is downloaded to the app's temporary directory (`${tmp}/app_update/app-latest.apk`).
2.  Progress is reported via `UpdateState.downloadProgress` (0.0 to 1.0).
3.  Once finished, the `checksum_sha256` (if provided) is verified against the file's SHA-256 hash.
4.  If verification fails, the file is deleted and an error is shown.

### 4. Installation

- **Android**: Uses `open_filex` to launch the system package installer for the downloaded APK.
- **iOS**: Redirects the user to the App Store URL (configured in `UpdateService`), as sideloading is not supported.

---

## UI Components

### `UpdateBannerWidget`

- Listens to `updateProvider`.
- Displays at the top of the Dashboard when `showBanner` is true.
- Shows progress bars during download.

### `ProfileScreen`

- Contains a "Check for Updates" section.
- Allows manual triggering of the check and shows detailed release notes.

---

## Configuration

The manifest URL is derived from the `apiBaseUrl` in `lib/core/config.dart`.

- **Base URL**: `http://YOUR_API_BASE_URL/api/mbl`
- **Manifest**: `http://YOUR_API_BASE_URL/api/mbl/mobile-version.json`

> [!NOTE]
> For local development, ensure your local server serves this JSON file or mock the response in `UpdateService` for testing.
