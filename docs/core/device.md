<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/core/device/device_info.dart
    android/app/src/main/kotlin/.../MainActivity.kt  (platform channel: fsi_courier/storage)
    ios/Runner/AppDelegate.swift                      (platform channel: fsi_courier/storage)

  Update this document whenever you change any of those files.
  Each of those files carries a header comment: "DOCS: docs/core/device.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Core — Device Info

## Files

| File | Role |
|------|------|
| `lib/core/device/device_info.dart` | Dart-side `DeviceInfoService` |
| `android/.../MainActivity.kt` | Platform channel handler — free disk space via `StatFs` |
| `ios/Runner/AppDelegate.swift` | Platform channel handler — free disk space via `FileManager` |

---

## `DeviceInfoService`

Collects device metadata for eligibility checks, bug reports, and profile display.

### Methods

| Method | Returns | Notes |
|--------|---------|-------|
| `getDeviceInfo()` | `Map<String, dynamic>` | OS version, model, app version |
| `getFreeStorageGb()` | `double` | Calls platform channel `fsi_courier/storage` |

---

## Platform channel: `fsi_courier/storage`

**Method**: `getFreeDiskSpaceGb` → `double` (GB available)

Implemented without an external package because `disk_space 0.2.x` is incompatible with AGP 8.0+ (missing namespace declaration).

### Android (`MainActivity.kt`)

```kotlin
StatFs(Environment.getDataDirectory().path)
// freeBlocksLong * blockSizeLong / 1_073_741_824.0
```

### iOS (`AppDelegate.swift`)

```swift
FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
// [.systemFreeSize] / 1_073_741_824.0
```

---

## Storage banner rule

`ProfileScreen` shows `_StorageBanner` when free storage drops below **2 GB**.  
`DispatchEligibilityScreen` attaches free storage to the eligibility request so the server can block dispatch on low-storage devices.

> If you change the 2 GB threshold, update both `profile_screen.dart` and this document.
