# Sync Performance TODO (plan only — no code changed)

> Hub: [README.md](./README.md) · Accuracy: [accuracy-and-scale.md](./accuracy-and-scale.md) · Coupling: [coupling-todo.md](./coupling-todo.md)

Prepared 2026-07-16 from a measured profiling session against the gdtms-v2-web API.
Every number below was measured, not estimated. Accuracy is the hard constraint:
couriers must always see 100% correct data, so every item here preserves the existing
reconciliation rules (Rules 1–4 in `lib/core/sync/delivery_bootstrap_service.dart`;
see [accuracy-and-scale.md](./accuracy-and-scale.md)).

## Context — what the API team already fixed (2026-07-16)

The server was the dominant cost and is now fixed:

| Metric (courier w/ 257 FOR_DELIVERY items) | Before   | After  |
| ------------------------------------------ | -------- | ------ |
| `GET /deliveries` one page (per_page=50)   | 2,093 ms | 177 ms |
| Full 4-status sweep, server-side           | ~15 s    | ~0.5 s |

Root cause was a missing DB index (`delivery_timeline.event`), fixed by migration
`2026_07_16_231714_add_event_index_to_delivery_timeline` — must also be run on prod.
Results verified row-identical before/after (barcode + status + `data_checksum`, 258 rows).

**Consequence for mobile:** server time per page is now ~tens of ms, so remaining sync
latency is dominated by network round-trips, sequential awaits, and device-side work.
That is what this plan addresses.

## What is already good (verified in code — do not redo)

- SQLite writes are batched (`db.batch()` in `local_delivery_dao.dart`). ✔
- Delta sync via `updated_since` exists and is used after the first full sweep. ✔
- Phase-0 reconciliation uses the batched `POST /deliveries/verify-status`. ✔
- Initial sync scope is already minimal: FOR_DELIVERY / FAILED_DELIVERY / MISROUTED
  fully, DELIVERED **today-only** (server default — past delivered items are never
  synced), RTS-validated items excluded server-side, bagsakan-assigned items gated. ✔

## Prioritized TODOs

### P1 — Parallelize the status sweep (high impact, low risk) ✅ done (2026-07-20)

`delivery_bootstrap_service.dart`:

- Full sweep runs the 4 status fetches with `Future.wait`.
- Within a status: page 1 first, then pages 2..N with concurrency **3**.
- Phase-2 stale cleanup still waits until **all** statuses finish.
- Accuracy unchanged (same requests/upserts; Rules 1–4 intact).

### P2 — Raise sync `per_page` from 50 to 100–200 (trivial) ✅ done (2026-07-20)

`DeliveryBootstrapService.kSyncPerPage = 150` for status + delta list GETs.
Fewer RTTs for large courier working sets.

### P3 — Kill the bagsakan enrichment N+1 (needs one small API addition) 🟡 mobile-side stopgap done (2026-08-05)

**Status:** `_fetchAndInsertGroupDeliveries` (`delivery_bootstrap_service.dart`)
now fetches `GET /deliveries/{barcode}` in concurrency-capped batches
(`DeliverySyncPaging.chunk`, same `_kPageConcurrency = 3` used by the P1
status sweep) instead of one at a time — a 30-item group is still 30 requests,
but they run 3-wide instead of sequentially, cutting wall-clock time roughly
3x. Verified via `flutter test test/core/sync/`.

**Still open — real fix needs backend work:** the server already has
`DeliveryQueryBuilder::applyBagsakanFilter($id)`; ask the API team (gdtms-v2-web)
to expose `GET /deliveries?bagsakan_id={id}` (or embed full delivery objects
in the group detail response), then replace the chunked loop with one paged
call. Cross-repo, out of scope for the mobile app alone.

### P4 — Stop wiping on every re-login (medium impact, needs care) ✅ done (2026-08-05)

**Status:** `login_screen.dart` now computes `needsFullResync` (first install OR
courier/server fingerprint change) alongside the existing wipe check, persists
it via `AuthStorage.setNeedsFullResync`, and — when identity changed — also
resets `last_sync_time` to 0 (previously only `clearAndSyncFromApiWithProgress`
did this; `AppDatabase.clearAllDeliveryData()` wipes `local_deliveries` but
never touched the separate secure-storage `last_sync_time`, so leaving it
stale would have made the very next sync take the delta path against an
empty table and miss the new courier's backlog).

`initial_sync_screen.dart._runSync` reads the flag: `true` → unchanged
`clearAndSyncFromApiWithProgress` (wipe + full sweep); `false` → calls
`syncFromApiWithProgress` directly, which naturally takes the delta path
(Phase-0 `verify-status` reconciliation → `updated_since` delta → Phase-2
cleanup) since `last_sync_time` from the prior session is still intact —
same convergence guarantee, no wipe.

"Reload from Server" on the Sync screen (`clearAndSyncFromApi`) is untouched —
still the manual full-wipe escape hatch.

Verified via `flutter analyze` + full `flutter test` suite (no existing
widget-test harness for login/initial-sync/secure-storage in this repo to
extend). **Needs manual device QA before shipping**: logout → login with the
_same_ courier (expect delta sync, no spinner-visible wipe) and with a
_different_ courier (expect full wipe + sweep, unchanged from today).

### P5 — Skip unchanged upserts using `data_checksum` (small win, safe) ✅ done (2026-07-20)

`LocalDeliveryDao.insertAllFromApiItems`: when local and server `data_checksum`
match (and row is not dirty), skip the SQLite write. Dirty/courier-local rows and
verified purge paths are unchanged.

### P6 — Progressive UI during initial sync (perceived speed) ✅ done (2026-08-05)

**Status:** `delivery_bootstrap_service.dart` — `syncFromApiWithProgress` /
`clearAndSyncFromApiWithProgress` gained an optional `onForDeliveryReady`
callback, fired the moment the FOR_DELIVERY-specific fetch resolves (full
sweep: as soon as that one status's mapped future completes inside the
existing `Future.wait`, independent of the other 3; delta mode: right after
the single delta call, since there's no per-status split there). Purely
additive — same fetch order, same concurrency, same Phase 2/3 gating.

`initial_sync_screen.dart._runSync` races
`Future.any([forDeliveryReady, syncFuture])` — the courier sees "All set!"
and can continue as soon as FOR_DELIVERY is ready, while
FAILED_DELIVERY/MISROUTED/DELIVERED/bagsakan/cleanup keep running
unawaited in the background if they haven't finished yet.

Two correctness details this needed, beyond the callback itself:

- The background continuation can outlive this screen (once the courier
  continues to `/dashboard`), so it can't touch this screen's `ref` —
  `ProviderScope.containerOf(context, listen: false)` is captured up front
  (same API `ref.read()` uses internally) and used for the follow-up
  `deliveryRefreshProvider.increment()` instead.
- That increment itself is new: the original code never needed one, because
  the full sync always finished *before* navigation, so dashboard/list
  screens' first `_load()` already saw complete data. With early
  navigation, those screens can now mount *before* the background remainder
  finishes — without the increment, FAILED_DELIVERY/MISROUTED/DELIVERED
  tabs would sit stale until some unrelated later trigger (next periodic
  auto-sync, manual pull-to-refresh).

Verified via `flutter analyze` (whole project, clean) and full `flutter
test` suite (green — no existing test exercises these methods directly, and
both new parameters are optional so no signature break). **Needs manual
device QA before shipping** — this is the most UX-visible timing change in
the whole pass: verify on a slow/throttled connection that (a) the courier
can genuinely continue before FAILED_DELIVERY/MISROUTED/DELIVERED are
synced, (b) those tabs populate correctly once the background sync lands
without a manual refresh, and (c) the normal (small-dataset, sync-finishes-
before-checkmark-ends) case looks unchanged.

### P7 — Verify gzip end-to-end (verification task) — still open, needs manual check outside the app

Dio's default `IOHttpClientAdapter` (wrapping `dart:io` `HttpClient`) sends
`Accept-Encoding: gzip` and auto-decompresses by default — confirmed in
`lib/core/api/api_client.dart`, no custom adapter or header override. That
also means **the app itself can never observe `Content-Encoding` on a
response** (`dart:io` strips it after auto-decompression), so this cannot be
verified with a unit/widget test or by adding logging inside `ApiClient`.

Verify outside the app instead, against both environments:

- Herd/nginx local: `curl -v --compressed http://<herd-domain>/api/mbl/deliveries -H "Accept: application/json" -H "Authorization: Bearer <token>"` and check for `Content-Encoding: gzip` in the response headers (curl's `-v` shows raw headers even with `--compressed` auto-decoding the body).
- Prod: same command against the prod base URL.
- Or use a proxy (mitmproxy/Charles) while running the app and inspect the raw response headers for a `GET /deliveries` call.

Record pass/fail + date here once checked — not yet run as of this pass
(no local Herd domain / prod URL available in-repo to probe from this
session).

### P8 — Later: single unified stream instead of 4 sweeps

`GET /sync` (v3.4) already exists and the app uses it for bagsakan groups only. Moving
delivery syncing onto that one paginated stream would collapse the sweep into a single
request series. Bigger refactor of the bootstrap service — evaluate after P1–P5 land.

## Explicitly out of scope

- No change to which items sync (the current scope is correct: no past-date DELIVERED,
  no validated-RTS, no other couriers' items).
- No weakening of Rules 1–4 (never downgrade courier-local terminal statuses; server
  authority for terminal changes; full-sweep-only stale deletion).

## Local dev note (not app work)

The dev machine's MariaDB still runs `innodb_buffer_pool_size=16MB`; raise to 512M in
my.ini + restart to make local API testing representative.
