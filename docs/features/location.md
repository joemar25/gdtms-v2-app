<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/features/location/location_required_screen.dart

  Update this document whenever you change this file.
  This file carries a header comment: "DOCS: docs/features/location.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Feature — Location Required

## File

`lib/features/location/location_required_screen.dart` — Route: `/location-required`

---

## Purpose

Blocking screen shown when the courier has not granted location permission. The app requires GPS to function (for location pings and delivery geo-tagging).

## Flow

1. Router redirects here when `locationProvider` state is `denied`.
2. Screen explains why location is needed.
3. "Grant Permission" button calls `Geolocator.requestPermission()`.
4. On grant: `LocationNotifier` transitions to `granted` → router redirects to the intended destination.
5. On permanent denial: shows "Open Settings" button → `Geolocator.openAppSettings()`.

## Notes

- The router guard in `app_router.dart` re-evaluates on every `locationProvider` change. No manual navigation is needed after permission is granted.
