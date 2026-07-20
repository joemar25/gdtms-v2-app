# Architecture Coupling TODO (plan only — no code changed)

Prepared 2026-07-20 from a graphify deep-dive of the knowledge graph
(`graphify-out/`) plus source review of submit paths and `_AutoSyncListener`.

**Companion to** [`SYNC_PERFORMANCE_TODO.md`](./SYNC_PERFORMANCE_TODO.md):

| Document | Focus |
| -------- | ----- |
| `SYNC_PERFORMANCE_TODO.md` | Bootstrap / API / SQLite **speed** (measured RTTs, paging, N+1) |
| **This file** | **Coupling** of auth ↔ connectivity ↔ sync ↔ submit ↔ global refresh |

Accuracy constraints from the performance plan still apply: never weaken
Rules 1–4 in `lib/core/sync/delivery_bootstrap_service.dart`. These items are
about structure, thrash, and maintainability — not about changing truth rules.

---

## Graph evidence (why this exists)

### God nodes (most connected symbols)

| Symbol | Edges | Home community (label) | Role |
| ------ | ----- | ---------------------- | ---- |
| `authProvider` | 44 | Sync Manager Core | Session gate for almost everything |
| `apiClientProvider` | 39 | Auth Login AutoSync | Raw HTTP used from many screens |
| `syncManagerProvider` | 29 | Bagsakan Screen 2 | Offline queue + push |
| `isOnlineProvider` | 28 | Auth Login AutoSync | Online gate for submit + auto-sync |
| `connectionStatusProvider` | 27 | Bagsakan Screen 2 | Banner / richer connectivity UI |
| `deliveryRefreshProvider` | 21 | Bagsakan Screen 2 | Global “reload all lists” counter |
| `Route /dashboard` | 12 | Dispatch Screen 3 | Shared post-action navigation hub |

### Community that is not really a feature

**Community 11 — “Auth Login AutoSync”** mixes:

- Core: `apiClientProvider`, `isOnlineProvider`, `_AutoSyncListener(State)`
- Auth: login / reset-password state classes
- Features: bagsakan, scan, dashboard, dispatch eligibility, wallet, notifications, profile edit
- Cross-cuts: `TimeEnforcer`, permissions notifier

That is a **cluster of shared infrastructure**, not an auth feature. Louvain
pulled feature screens in because they all hang off the same providers.

### Why `_submit` looked like a bridge

There is **no single** `_submit` function. Several private methods share:

1. **Session / network reads** — `authProvider`, `isOnlineProvider`, `apiClientProvider`
2. **Queue / refresh side effects** — `syncManagerProvider.processQueue()`, `deliveryRefreshProvider.increment()`
3. **Navigation** — often `Route /dashboard`

Example path (EXTRACTED edges):

```
login_screen._submit
  → apiClientProvider (C11 Auth Login AutoSync)
  → _DispatchEligibilityScreenState (also uses API client)
  → DispatchEligibilityScreen

login_screen._submit
  → Route /dashboard (C113)
  → dispatch_eligibility_screen._submitReject
```

Delivery submit wires the full spine in one method
(`lib/features/delivery/delivery_update_screen.dart` ~600–716):

```
authProvider + isOnlineProvider
  → SQLite queue insert + local status update
  → processQueue() if online
  → deliveryRefreshProvider.increment()
  → context.go('/dashboard')
```

---

## What is already good (do not “fix” without need)

- Offline-first queue (`SyncOperationsDao` + `processQueue`) before bootstrap pull. ✔
- Auto-sync triggers documented in `app.dart` (startup, login, reconnect, resume, periodic). ✔
- Debounce (`_kSyncDebounce` 30s) and `_isSyncing` flag to limit overlap. ✔
- Push-before-pull ordering in `_runFullSync` + `waitUntilIdle`. ✔
- Time validation gate on delivery submit. ✔

---

## Prioritized TODOs (architecture)

### A1 — Extract `AutoSyncCoordinator` out of `app.dart` (high impact, medium risk)

`_AutoSyncListenerState` currently owns:

- 5 sync triggers + debounce
- location pings
- push notification init
- unread notification loads
- version-check delay
- three root overlay entries (sync pill, update banner, mandatory update)

**Problem:** app shell is a god object; hard to unit-test trigger policy; graph
shows `app.dart` as top consumer of `authProvider` / `apiClientProvider` /
`isOnlineProvider` / `syncManagerProvider`.

**Plan:**

- Move trigger policy + `_runFullSync` into `lib/core/sync/auto_sync_coordinator.dart`
  (or a Riverpod notifier).
- Keep overlays as thin widgets that only *watch* sync/update state.
- Location pings → stay in `LocationPingService` start/stop API only (no HTTP in UI).

Accuracy: unchanged if `_runFullSync` order stays processQueue → waitUntilIdle →
`syncFromApi` → refresh.

### A2 — One “write completion” helper for feature submits (high impact, low–medium risk)

Today each screen reimplements a variant of:

```
insert queue / call API
→ processQueue? (sometimes await, sometimes unawaited, sometimes never)
→ deliveryRefreshProvider.increment()
→ navigate?
```

Call sites (non-exhaustive): delivery update, bagsakan form / group items / list,
dispatch eligibility, scan, sync screen, sync_now_button, app auto-sync.

**Problem:** inconsistent races (comment in `app.dart` already notes
fire-and-forget `processQueue` from delivery can make auto-sync skip), double
refresh increments, hard to audit offline vs online behavior.

**Plan:**

- Add something like `SubmitSideEffects` / `SyncWriteCoordinator.completeWrite(...)`:
  - optional `kickQueue: bool` (default true when online)
  - `awaitIdle: bool` (default false for UX; true only for auto-sync / Sync screen)
  - `refresh: RefreshScope` (see A3)
- Migrate delivery + bagsakan + dispatch first (highest write volume).

Pairs with **SYNC P1/P4**: faster bootstrap helps less if every submit still
stamps the whole UI and races the coordinator.

### A3 — Replace global `deliveryRefreshProvider` counter with scoped invalidation (high impact, medium risk)

`deliveryRefreshProvider` is a single int. **Any** increment reloads every
listening list (dashboard, status lists, bagsakan, etc.). Graph degree 21 and
many feature communities hang off it.

**Problem:** after one delivery update, unrelated screens rebuild/refetch;
auto-sync after bootstrap increments again → thrash.

**Plan:**

- Prefer domain-scoped signals, e.g.:
  - `deliveryListInvalidationProvider` (barcode set or status filter)
  - bagsakan group id invalidation
  - keep a rare `forceFullRefresh()` for bootstrap / re-login
- Or Riverpod `ref.invalidate(familyProvider(id))` instead of a global counter.

Accuracy: same data; less redundant work (helps perceived performance after P1–P5).

### A4 — `CourierSession` / thin facade over auth + online (medium impact, low risk)

Screens repeatedly do:

```dart
ref.read(authProvider).courier?['id']
ref.read(isOnlineProvider)
ref.read(apiClientProvider)
```

**Plan:**

- `courierSessionProvider` exposing `{ isAuthenticated, courierId, isOnline }`
- Screens that only need courier id / online gate read the facade
- Keep `apiClientProvider` for services/repositories (A5), not every button handler

Reduces accidental coupling into C11-style blobs without a big rewrite.

### A5 — Feature services over raw `apiClientProvider` in UI (medium impact, medium risk)

`apiClientProvider` edges fan into login, reset-password, bagsakan, dashboard,
delivery list, dispatch, scan, wallet, profile, permissions, initial sync, sync_manager.

**Problem:** HTTP paths, parsers, and error handling live in widgets; hard to
mock; graph treats almost every feature as “API community.”

**Plan (incremental):**

- Expand pattern already used by `reportServiceProvider`, `profile` services:
  - `DispatchService.accept/reject`
  - `DeliveryQueryService` for list refresh
  - wallet already partially service-shaped — finish it
- UI calls services; services own `ApiClient`.

Do **not** block SYNC P1–P3 on this; migrate when touching a feature.

### A6 — Unify connectivity reads (`isOnline` vs `connectionStatus`) (low–medium impact)

Graph: `isOnlineProvider` (deg 28) vs `connectionStatusProvider` (deg 27) live
in different communities and are used for different UI, but policy checks mix both.

**Plan:**

- Single source of truth for “may call network”
- Map richer status → banner only
- Document: queue flush / bootstrap require `isOnline == true`; banners use status enum

### A7 — Post-submit navigation policy (low impact, low risk)

Many writes navigate to `Route /dashboard` (login, delivery update, dispatch
flows, etc.). That hub sits in a mislabeled “Dispatch Screen 3” cluster and
hides feature-local UX (e.g. stay on bagsakan group after submit).

**Plan:**

- Explicit navigation intents: `pop`, `goStatusList`, `goDashboard`, `stay`
- Default per feature; avoid hard-coding `/dashboard` in every `_submit`

### A8 — Clarify dual queue kickers (medium impact, low risk)

Documented race:

- Delivery submit: `unawaited(processQueue())`
- Auto-sync: `await processQueue(); await waitUntilIdle()`
- Sync manager: may skip if already syncing

**Plan:**

- Single entry: `SyncManager.requestFlush({priority})`
- Auto-sync always waits; UI kicks are coalesced (no parallel processQueue)
- Metrics/log reason string already used (`startup`, `login`, …) — extend to `submit_delivery`, etc.

Complements **SYNC P1** (less wasted overlapping sync work).

### A9 — Split “theme on AuthState” from auth session (low impact, low risk)

`FsiCourierApp` watches `authProvider` for `themeMode`. That couples full app
rebuilds to auth object identity.

**Plan:** `themeModeProvider` (or settings) separate from login state so auth
token refresh does not rebuild `MaterialApp` theme unnecessarily.

### A10 — Graph hygiene for future refactors (optional, tooling)

- Re-run `/graphify . --update` after large provider moves; watch god-node degrees.
- Prefer fewer direct edges from `lib/features/**` to `apiClientProvider` /
  `authProvider` over time (track in PR checklist).
- Fix misleading community labels only if re-clustering after A1–A3 (labels are
  analysis artifacts, not product truth).

---

## Suggested sequencing (with sync performance plan)

```
SYNC P2 (per_page)          ── quick win, independent
SYNC P1 (parallel sweeps)   ── measured speed
     │
     ├─ A8 (coalesce processQueue)     ── reduce thrash while P1 lands
     ├─ A2 (write completion helper)   ── consistent submit side effects
     └─ A3 (scoped refresh)            ── less UI work after every write

SYNC P4 (no wipe on re-login)
SYNC P3 (bagsakan N+1 API)
     │
     └─ A1 (extract AutoSyncCoordinator) ── once sync body is faster/cleaner

A4 / A5 / A6 / A7 / A9     ── incremental while touching features
A10                        ── ongoing
```

---

## Explicitly out of scope

- No change to reconciliation Rules 1–4.
- No change to which delivery statuses are synced (see SYNC plan).
- No big-bang “Clean Architecture rewrite” of the whole app — only extract along
  the god-node seams above.
- No requirement to collapse all `_submit` names; private methods can keep
  local names once side effects go through one helper.

---

## Quick reference — files in the hot path

| Concern | Primary files |
| ------- | --------------- |
| Auto-sync orchestration | `lib/app.dart` (`_AutoSyncListener`) |
| Bootstrap / pull | `lib/core/sync/delivery_bootstrap_service.dart` |
| Offline queue | `lib/core/sync/sync_manager.dart`, `lib/core/providers/sync_provider.dart` |
| Session | `lib/core/auth/auth_provider.dart`, `auth_storage.dart` |
| Connectivity | `lib/core/providers/connectivity_provider.dart` |
| Global list refresh | `lib/core/providers/delivery_refresh_provider.dart` |
| Delivery write path | `lib/features/delivery/delivery_update_screen.dart` |
| Login write path | `lib/features/auth/login_screen.dart` |
| Dispatch write path | `lib/features/dispatch/dispatch_eligibility_screen.dart` |

---

## Open questions (decide before A2/A3 implementation)

1. After offline delivery submit, should UI wait for first queue item success
   before leaving the screen, or always optimistic + dashboard?
2. Should auto-sync on resume still run a full bootstrap if a submit flush is
   already in flight (today: debounce + waitUntilIdle)?
3. Is bagsakan-only invalidation enough for A3 v1, or do status lists need
   per-status providers first?
