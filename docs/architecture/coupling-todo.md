# Architecture Coupling TODO

> Hub: [README.md](./README.md) · [system-map.md](./system-map.md) · [accuracy-and-scale.md](./accuracy-and-scale.md)

Prepared 2026-07-20 from a graphify deep-dive of the knowledge graph
(`graphify-out/`) plus source review of submit paths and `_AutoSyncListener`.

## Production rollout notes (safe subset)

Shipped / safe to ship without changing courier-visible operations:

| Item                                  | Status   | Ops impact                                                              |
| ------------------------------------- | -------- | ----------------------------------------------------------------------- |
| A8 `requestFlush` coalescing          | **Done** | Same queue content; fewer dropped concurrent kicks                      |
| A2 `completeWrite` helper             | **Done** | Same offline-first write → flush → refresh pattern                      |
| A6 connectivity gate consistency      | **Done** | Bagsakan screens match app-wide `isOnlineProvider` gate policy          |
| A9 theme/auth `select`                | **Done** | Fewer MaterialApp rebuilds; same theme                                  |
| Max flush re-run cap (5)              | **Done** | Pathological enqueue storms only; leftover deferred to next auto-sync   |
| processQueue → requestFlush           | **Done** | Legacy callers coalesce; no payload change                              |
| API-down flush guard                  | **Done** | No new flush when `!isOnlineProvider`; mid-loop abort                   |
| Reconnect/login skip debounce         | **Done** | Offline backlog drains when API returns                                 |
| Abort bootstrap if API drops mid-sync | **Done** | No pull when online flipped false after flush                           |
| A1 AutoSyncCoordinator extract        | **Done** | Same trigger/debounce semantics; needs manual device QA (see A1)        |
| A3 scoped list invalidation           | **Done** | Full reload still available; scoping only skips _unnecessary_ ones      |
| A4 `courierSessionProvider` facade    | **Done** | Read-only; writes still go through `authProvider.notifier`              |
| A5 feature services (top 3)           | **Done** | Same requests/parsing, moved out of widgets; delivery/bagsakan/dispatch |
| A7 post-submit navigation helper      | **Done** | Every site still goes to `/dashboard`; only the string moved            |

**Still open:**

- A5 remaining features (wallet, profile, auth, dashboard, initial_sync,
  non-dispatch scan) — backlog, migrate opportunistically.
- SYNC_PERFORMANCE: P8 deferred (highest risk to accuracy Rules 1–4, no
  measured need after P1–P6); P7 verification steps documented, not yet run
  — see `sync-performance-todo.md`.

**Companion to** [`sync-performance-todo.md`](./sync-performance-todo.md):

| Document                   | Focus                                                                |
| -------------------------- | -------------------------------------------------------------------- |
| `sync-performance-todo.md` | Bootstrap / API / SQLite **speed** (measured RTTs, paging, N+1)      |
| **coupling-todo.md**       | **Coupling** of auth ↔ connectivity ↔ sync ↔ submit ↔ global refresh |

Accuracy constraints from the performance plan still apply: never weaken
Rules 1–4 ([accuracy-and-scale.md](./accuracy-and-scale.md),
`lib/core/sync/delivery_bootstrap_service.dart`). These items are about
structure, thrash, and maintainability — not about changing truth rules.

Hub: [README.md](./README.md) · [system-map.md](./system-map.md)

---

## Graph evidence (why this exists)

### God nodes (most connected symbols)

| Symbol                     | Edges | Home community (label) | Role                               |
| -------------------------- | ----- | ---------------------- | ---------------------------------- |
| `authProvider`             | 44    | Sync Manager Core      | Session gate for almost everything |
| `apiClientProvider`        | 39    | Auth Login AutoSync    | Raw HTTP used from many screens    |
| `syncManagerProvider`      | 29    | Bagsakan Screen 2      | Offline queue + push               |
| `isOnlineProvider`         | 28    | Auth Login AutoSync    | Online gate for submit + auto-sync |
| `connectionStatusProvider` | 27    | Bagsakan Screen 2      | Banner / richer connectivity UI    |
| `deliveryRefreshProvider`  | 21    | Bagsakan Screen 2      | Global “reload all lists” counter  |
| `Route /dashboard`         | 12    | Dispatch Screen 3      | Shared post-action navigation hub  |

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

### A1 — Extract `AutoSyncCoordinator` out of `app.dart` (high impact, medium risk) ✅ done (2026-08-05)

**Status:** `lib/core/sync/auto_sync_coordinator.dart` — new `AutoSyncCoordinator`
class (provider-scoped via `autoSyncCoordinatorProvider`, torn down via
`ref.onDispose`) now owns: the 5 sync triggers (`onStartup`, `onLogin`,
`onReconnect`, `onResume`, plus `onLogout`/`onOffline`/`onPause`/`onDetached`),
`_kSyncDebounce`/`_kSkipDebounceReasons`/`_isSyncing`/`_lastSyncAt`,
`_runFullSync`, the periodic timer, location-ping start/stop delegation, push
notification init, unread-count loads, and the 3s version-check delay.

`lib/app.dart`'s `_AutoSyncListenerState` shrank from ~297 lines to ~115:
just `WidgetsBindingObserver` registration/dispose, the 3 root-overlay
insert/remove helpers (unchanged — they already only watch provider state),
and `ref.listen(isOnlineProvider)` / `ref.listen(authProvider)` wiring that
now calls into the coordinator instead of duplicating trigger logic inline.

Same trigger semantics, same `_runFullSync` order
(`requestFlush` → `syncFromApi` → refresh), same debounce/skip-debounce
reasons — verified via `flutter analyze` (clean, confirms every import that
moved to the new file is no longer needed in `app.dart`) and the full
`flutter test` suite (green, no regressions).

**Deviation:** no automated unit test for the trigger/debounce policy — every
entry point calls `PushNotificationService.instance.init()` (Firebase, unmocked
in `test()`), so exercising them directly would fail on unrelated plugin
errors, not real regressions. **Needs manual device QA**: airplane-mode
toggle, force-close/resume, login/logout — watch for duplicate syncs via the
`[SYNC]` log lines in `docs/architecture/system-map.md`.

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
- Keep overlays as thin widgets that only _watch_ sync/update state.
- Location pings → stay in `LocationPingService` start/stop API only (no HTTP in UI).

Accuracy: unchanged if `_runFullSync` order stays processQueue → waitUntilIdle →
`syncFromApi` → refresh.

### A2 — One “write completion” helper for feature submits (high impact, low–medium risk) ✅ done

**Status (2026-07-20):** Implemented `lib/core/sync/sync_write_coordinator.dart`
(`completeWrite`) and migrated delivery submit, bagsakan save/submit/remove/delete,
dispatch accept, scan dispatch accept, and bagsakan pull-refresh.

**Closed (2026-08-05):** Audited the remaining non-`completeWrite` call sites
and confirmed each is architecturally correct as-is, not a missed migration:

- `SyncManagerNotifier`'s own internal `deliveryRefreshProvider.increment()`
  calls (`sync_manager.dart:1061,1157,1182`) — `sync_write_coordinator.dart`
  sits _above_ `sync_manager.dart`; routing the queue's own state changess
  back through `completeWrite` would invert that dependency.
- Sync-screen row actions (`sync_now_button.dart`, `sync_entry_list.dart`
  retry/clear/dismiss) — direct queue mutations on the Sync screen itself,
  not a feature "write completion."
- `bagsakan_screen.dart`'s `loadEntries()` call right before its
  `completeWrite(...)` in the delete-group flow — looked redundant but is
  not: `deleteBagsakanGroup` mutates `sync_operations` directly (DAO-level
  cancel/queue), bypassing `SyncManager`, and `completeWrite`'s flush there
  uses `awaitIdle: false` (fire-and-forget) and is skipped entirely when
  offline — so `loadEntries()` is the only thing that refreshes the
  Sync/History screen's queue view for that DAO-level change. Kept, with a
  comment added explaining why.

No further A2 migration work remains.

### A2 (original notes)

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

### A3 — Replace global `deliveryRefreshProvider` counter with scoped invalidation (high impact, medium risk) ✅ done (2026-08-05)

**Status:** `delivery_status_list_screen.dart` and `bagsakan_group_items_screen.dart`
now consult `lastDeliveryRefreshBarcodesProvider` (the scope `invalidate()`
already recorded but nothing read) before reloading: full reload only if a
scoped barcode is on-screen or about to become relevant, else skip.
Dashboard/wallet/sync screen still reload unconditionally — their query is
cheap, scoping isn't worth it. Verified via `flutter test` (full suite green).

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

### A4 — `CourierSession` / thin facade over auth + online (medium impact, low risk) ✅ done (2026-08-05)

**Status:** `lib/core/auth/courier_session_provider.dart` — `courierSessionProvider`
exposes `{ isAuthenticated, courierId, courier, isOnline }`, derived from
`authProvider` + `isOnlineProvider`. Migrated the repeated
`ref.read(authProvider).courier?['id']` (+ nearby `isOnlineProvider`) pattern
in `delivery_update_screen.dart`, `delivery_status_list_screen.dart`,
`bagsakan_screen.dart`, `bagsakan_form_screen.dart`,
`bagsakan_group_items_screen.dart`, `reset_password_screen.dart`, and
`profile_edit_screen.dart` (which also keeps a direct `authProvider.notifier`
write for `setAuthenticated` — the facade is read-only by design, writes
still go through the real notifier). `apiClientProvider` reads are
unchanged — that's A5's concern, not the facade's.

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

### A5 — Feature services over raw `apiClientProvider` in UI (medium impact, medium risk) 🟡 top-3 done (2026-08-05)

**Status:** mirrored the existing `report_service.dart` pattern for the
three highest write-volume features:

- `lib/core/services/delivery_service.dart` — `getDeliveryDetail(barcode)`;
  migrated `delivery_update_screen.dart` and the POD-lookup fallback in
  `scan_screen.dart` (same `GET /deliveries/{barcode}` endpoint, opportunistic
  reuse).
- `lib/core/services/bagsakan_service.dart` — `getGroupDetail(groupId)` +
  `searchEligibleDeliveries(query)`; migrated `bagsakan_form_screen.dart`
  (2 call sites) and `bagsakan_group_items_screen.dart`.
- `lib/core/services/dispatch_service.dart` — `getPendingDispatches`,
  `checkEligibility`, `acceptDispatch`, `rejectDispatch`; migrated
  `dispatch_list_screen.dart`, `dispatch_eligibility_screen.dart`, and the
  scan-to-dispatch flow in `scan_screen.dart` (both eligibility-check and
  accept calls — the plan sketch only named one, but they're the same two
  endpoints used together in one function, so splitting them across two
  passes would've been arbitrary).

**Deliberately left as direct `apiClientProvider` reads** — calls that hand
the client to an already-proper service, not raw HTTP in a widget:
`DeliveryBootstrapService.instance.syncFromApi(...)` /
`.seedForDelivery(...)` pull-to-refresh and post-accept calls in
`bagsakan_screen.dart`, `bagsakan_group_items_screen.dart`,
`dispatch_eligibility_screen.dart`, and `scan_screen.dart`.

Verified via `flutter analyze` (whole project, clean) and full `flutter test`
suite (green).

**Backlog, not done** — migrate opportunistically per the original plan:
wallet, profile (`lib/core/services/profile_service.dart` already exists but
is unused — wire it up when next touching profile), auth, dashboard,
initial_sync, and the non-dispatch parts of scan.

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

### A6 — Unify connectivity reads (`isOnline` vs `connectionStatus`) (low–medium impact) ✅ done (2026-08-05)

**Status:** `bagsakan_form_screen.dart` (2 sites) and `bagsakan_group_items_screen.dart`
were the one inconsistency — gating an online-refresh decision on
`connectionStatusProvider == online` instead of `isOnlineProvider` like every
other policy check in the app. Switched to `isOnlineProvider`;
`connectionStatusProvider` reads elsewhere are all UI banners, left as-is.

Graph: `isOnlineProvider` (deg 28) vs `connectionStatusProvider` (deg 27) live
in different communities and are used for different UI, but policy checks mix both.

**Plan:**

- Single source of truth for “may call network”
- Map richer status → banner only
- Document: queue flush / bootstrap require `isOnline == true`; banners use status enum

### A7 — Post-submit navigation policy (low impact, low risk) ✅ done (2026-08-05)

**Status:** `lib/shared/helpers/post_submit_navigation.dart` —
`goToDashboardAfterSubmit(context)` replaces the bare `context.go('/dashboard')`
literal at the 9 actual success-navigation call sites: `login_screen.dart`,
`reset_password_screen.dart` (authenticated-mode branch only),
`delivery_update_screen.dart`, `dispatch_eligibility_screen.dart` (accept
success, already-accepted info, reject success — 3 sites), `dispatch_list_screen.dart`,
and `scan_screen.dart` (2 sites). Behavior is unchanged — every site still
goes to `/dashboard` — but the destination is now named in one place instead
of a repeated string, so a future feature-specific change (stay on screen,
pop, go to a status list) is a one-line diff at that call site.

**Deliberately NOT touched** — `PopScope` back-button fallbacks
(`wallet_screen.dart`, `profile_screen.dart`,
`dispatch_eligibility_screen.dart._handleBack`, `terms_screen.dart`): these
fire when there's nothing to pop to, which is a different concern (navigation
safety net) from "where does a successful write send you," and folding them
into the same helper would blur that distinction. Kept as direct
`context.go('/dashboard')`.

Didn't add the `pop`/`stay`/`goStatusList` intents from the original plan
sketch — no current call site needs them, and an enum with unused branches
would be speculative. Extend `post_submit_navigation.dart` when a feature
actually needs a different destination.

Many writes navigate to `Route /dashboard` (login, delivery update, dispatch
flows, etc.). That hub sits in a mislabeled “Dispatch Screen 3” cluster and
hides feature-local UX (e.g. stay on bagsakan group after submit).

**Plan:**

- Explicit navigation intents: `pop`, `goStatusList`, `goDashboard`, `stay`
- Default per feature; avoid hard-coding `/dashboard` in every `_submit`

### A8 — Clarify dual queue kickers (medium impact, low risk) ✅ done

**Status (2026-07-20):** `SyncManagerNotifier.requestFlush(reason, awaitIdle)`
coalesces concurrent kicks with re-run-on-join so mid-flight enqueues are not
stranded. Auto-sync uses `awaitIdle: true`; UI submits use `awaitIdle: false`
via `SyncWriteCoordinator`. `waitUntilIdle` also awaits the active flush future.

Remaining: background WorkManager path should call `requestFlush` when next
touched (optional follow-up).

### A9 — Split “theme on AuthState” from auth session (low impact, low risk)

`FsiCourierApp` watches `authProvider` for `themeMode`. That couples full app
rebuilds to auth object identity.

**Plan:** `themeModeProvider` (or settings) separate from login state so auth
token refresh does not rebuild `MaterialApp` theme unnecessarily.

### A10 — Graph hygiene for future refactors (optional, tooling) ✅ done (2026-08-05)

**Status:** re-ran `/graphify . --update` after Phases 1–9. Degrees dropped
vs. the 2026-07-20 baseline: `authProvider` 44→~27, `apiClientProvider`
39→~33, `deliveryRefreshProvider` 21→~9, `connectionStatusProvider` 27→21.
`isOnlineProvider` unchanged (~28) — expected, it's the one correct online
gate, not a coupling smell. Graph health check clean (no dangling/missing/
collapsed edges). Numbers aren't strictly apples-to-apples (incremental
update vs. the original full scan split some nodes differently), but the
direction confirms A1/A4/A5/A6 reduced fan-in as intended.

- Prefer fewer direct edges from `lib/features/**` to `apiClientProvider` /
  `authProvider` over time (track in PR checklist) — use `courierSessionProvider`
  (A4) and a feature service (A5) instead.
- Fix misleading community labels only if re-clustering after a future large
  move (labels are analysis artifacts, not product truth).

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

| Concern                 | Primary files                                                              |
| ----------------------- | -------------------------------------------------------------------------- |
| Auto-sync orchestration | `lib/app.dart` (`_AutoSyncListener`)                                       |
| Bootstrap / pull        | `lib/core/sync/delivery_bootstrap_service.dart`                            |
| Offline queue           | `lib/core/sync/sync_manager.dart`, `lib/core/providers/sync_provider.dart` |
| Session                 | `lib/core/auth/auth_provider.dart`, `auth_storage.dart`                    |
| Connectivity            | `lib/core/providers/connectivity_provider.dart`                            |
| Global list refresh     | `lib/core/providers/delivery_refresh_provider.dart`                        |
| Delivery write path     | `lib/features/delivery/delivery_update_screen.dart`                        |
| Login write path        | `lib/features/auth/login_screen.dart`                                      |
| Dispatch write path     | `lib/features/dispatch/dispatch_eligibility_screen.dart`                   |

---

## Open questions — resolved during A2/A3 implementation (2026-08-05)

1. Always optimistic + dashboard — unchanged; offline submit still navigates
   immediately, the queue drains in the background.
2. Unchanged — debounce + `requestFlush` coalescing (A8) already covers this.
3. Neither — implemented barcode-scope checks on both
   `delivery_status_list_screen.dart` and `bagsakan_group_items_screen.dart`
   directly (see A3), no separate per-status providers needed.
