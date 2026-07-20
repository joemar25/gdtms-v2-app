# Sync Performance TODO (plan only — no code changed)

Prepared 2026-07-16 from a measured profiling session against the gdtms-v2-web API.
Every number below was measured, not estimated. Accuracy is the hard constraint:
couriers must always see 100% correct data, so every item here preserves the existing
reconciliation rules (Rules 1–4 in `lib/core/sync/delivery_bootstrap_service.dart`).

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

### P1 — Parallelize the status sweep (high impact, low risk)

`delivery_bootstrap_service.dart` `syncFromApi*` runs the 4 status sweeps strictly
sequentially, and `_syncStatus` awaits each page one at a time. With server pages at
~177 ms, total time ≈ sum of all round-trips.

- Run the 4 status sweeps with `Future.wait`.
- Within a status: fetch page 1 to learn `last_page`, then fetch remaining pages with
  a small concurrency cap (2–3) to stay polite to the API.
- Accuracy: unchanged — same requests, same upserts; Phase-2 stale cleanup already
  waits for all sweeps to complete before deleting anything. Keep that ordering.

### P2 — Raise sync `per_page` from 50 to 100–200 (trivial)

Server paging is cheap now; fewer round-trips wins. 257 items = 6 requests today,
2 at per_page=150. Measure payload size on a slow connection before choosing the value.

### P3 — Kill the bagsakan enrichment N+1 (needs one small API addition)

`_fetchAndInsertGroupDeliveries` (`delivery_bootstrap_service.dart:671`) fetches
`GET /deliveries/{barcode}` **once per barcode** in a sequential loop — a 30-item group
= 30 round-trips. The server already has `DeliveryQueryBuilder::applyBagsakanFilter($id)`;
ask the API team to expose `GET /deliveries?bagsakan_id={id}` (or embed full delivery
objects in the group detail response), then replace the loop with one paged call.

### P4 — Stop wiping on every re-login (medium impact, needs care)

`initial_sync_screen.dart:42` always calls `clearAndSyncFromApiWithProgress` — full
local wipe + full sweep. Keep the wipe for first install and courier-identity change,
but for the same courier re-logging in, run the normal delta path
(`updated_since` + Phase-0 `verify-status` + Phase-2 cleanup). Those rules already
guarantee convergence to server truth, so accuracy is preserved while re-login sync
drops from "everything" to "what changed".

- Guard: compare stored courier id/phone against the login response before skipping the wipe.
- Keep "Reload from Server" on the Sync screen as the manual full-wipe escape hatch.

### P5 — Skip unchanged upserts using `data_checksum` (small win, safe)

Every list item carries a server-computed sha256 `data_checksum` (id, status, barcode,
updated_at). `insertAllFromApiItems` currently rewrites every row. Compare stored vs
incoming checksum and skip identical rows to cut SQLite writes and list-refresh churn.
Accuracy-safe: any real change alters the checksum.

### P6 — Progressive UI during initial sync (perceived speed)

The delivery list renders only after all 4 sweeps finish. FOR_DELIVERY is synced first —
navigate to the list (or show partial data with a "syncing…" banner) as soon as the
FOR_DELIVERY sweep completes; let the remaining statuses finish in the background.

### P7 — Verify gzip end-to-end (verification task)

Dart's HttpClient sends `Accept-Encoding: gzip` and auto-decompresses by default, but
confirm the servers (Herd/nginx local, prod) actually return `Content-Encoding: gzip`
for `application/json`. Delivery payloads carry full recipient metadata; compression
matters on mobile data.

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
