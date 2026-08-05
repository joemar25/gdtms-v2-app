<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  This file documents:
    lib/features/initial_sync/initial_sync_screen.dart
    lib/features/initial_sync/widgets/sync_ai_visuals.dart

  Update this document whenever you change those files.
  Header on sources: "DOCS: docs/features/initial-sync.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Feature — Initial Sync

## Files

| File | Role |
|------|------|
| `lib/features/initial_sync/initial_sync_screen.dart` | Route `/initial-sync` — bootstrap logic + composition |
| `lib/features/initial_sync/widgets/sync_ai_visuals.dart` | AI-sync visuals: orb, phase rail, status stream |

---

## Purpose

Shown after first login (or when local delivery data must be reseeded). Blocks dashboard until enough data is ready (FOR_DELIVERY first; remainder can finish in background).

## Flow

1. Mount → full or delta sync via `DeliveryBootstrapService` (`needsFullResync`).
2. `onProgress` messages drive status stream + phase rail.
3. Early continue when FOR_DELIVERY is ready.
4. Orb success animation → Continue countdown → `markInitialSyncCompleted()`.

## Visual language (≠ splash)

| Splash | Initial sync |
|--------|----------------|
| Brand logo + feature chips | Orbital loader + step rail |
| Marketing tagline | Plain courier progress lines |

Phases (courier-facing labels): **Start → Load → Sort → Done**

### Copy rules

All courier-visible strings must be plain delivery language (no “workspace”,
“sync engine”, “index”, “AI”, “fetch”). Progress messages live in
`DeliveryBootstrapService` and are shown on this screen.

## Notes

- Sync logic is independent of UI widgets — do not couple bootstrap service to paint code.
- Reduced motion freezes orb spin; success path still completes the completer.
