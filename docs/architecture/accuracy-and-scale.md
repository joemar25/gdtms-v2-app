<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  Accuracy contract for mobile sync. Source of truth for Rules 1–4 is also
  documented in delivery_bootstrap_service.dart — keep both in sync.
  ══════════════════════════════════════════════════════════════════════════════
-->

# Accuracy & scale contract

## What we guarantee (and what we do not)

### Accurate for the courier’s working set

This app is a **courier-scoped offline client**, not a global warehouse of the
entire GDTMS/ITMS fleet.

| Layer | Holds | Accuracy goal |
| ----- | ----- | ------------- |
| **Server API** | Fleet-scale deliveries (millions+ over time) | System of record |
| **Mobile SQLite** | **This courier’s** assigned / relevant subset (pending, failed, misrouted, delivered-today, bagsakan, …) | Converge to server truth under Rules 1–4 |
| **Offline queue** | Courier actions not yet accepted by API | Durable until flushed or conflict-resolved |

**“100% accurate” on mobile means:** after a successful online reconcile, every
local row the app shows for that courier matches the server’s rules for that
scope—not that the phone stores every delivery in the company forever.

### What we deliberately do **not** claim

- Storing **trillions** of rows on the phone (device + SQLite cannot and must not).
- Instant global consistency while offline (impossible offline; queue is the truth for local actions).
- Zero-latency recovery when the API is down for hours (work stays queued; resumes when `isOnlineProvider` is true).

Fleet-scale volume belongs on the **API and DB**. The mobile path stays correct
by **scoping**, **reconciliation rules**, and **paged sync**—see
[sync-performance-todo.md](./sync-performance-todo.md) and
[../production-readiness-large-datasets.md](../production-readiness-large-datasets.md).

---

## Rules 1–4 (reconciliation — never weaken)

Source: `lib/core/sync/delivery_bootstrap_service.dart`.

### Rule 1 — Priority reconcile local pending first

When online, barcodes that are still pending locally are checked against the
server **before** the full status sweep (e.g. batched verify-status / detail
fetch). Web-app status changes surface without waiting for a complete sweep.

### Rule 2 — Never downgrade the courier’s local terminal status

If the courier recorded **delivered / failed_delivery / misrouted** locally,
a server response that still says pending **does not** overwrite it. Courier
action is trusted until a server **terminal** record wins (Rule 3).

### Rule 3 — Accept server authority for terminal changes

If the server returns a **different terminal** status than local (e.g. admin
changed failed → misrouted), update local to match.

### Rule 4 — Remove genuinely gone items

After a full sweep, local pending barcodes absent from **all** server status
lists are deleted (cancelled, reassigned, removed).

**Invariant for all performance and coupling work:** P1–P8 and A2/A8/A3 must
preserve Rules 1–4. Speed without these rules is incorrect data.

---

## How accuracy holds when the API is flaky

| Situation | Accuracy mechanism |
| --------- | ------------------ |
| Offline write | Insert queue + update local status first; UI shows local truth |
| API unreachable | No flush / no auto-sync (`isOnlineProvider == false`); queue retained |
| API returns | `reconnected` / `login` skip debounce → flush then bootstrap |
| Mid-flush API death | Op-level fail/retry; no bootstrap pull if offline after flush |
| Concurrent submit + auto-sync | Coalesced `requestFlush` + re-run so enqueued ops are not stranded |
| Conflict (409) | Mark conflict; do not pretend success; user/dismiss + server refresh paths |

See [system-map.md](./system-map.md).

### Courier heart: updates must not be lost

Field work is durable on-device **before** any success toast. Support must treat
History rows as work product—see [ops-runbook.md](./ops-runbook.md) (never
reinstall/clear data to “fix sync” while queue has pending work).

---

## Scale strategy (device + API)

| Concern | Approach |
| ------- | -------- |
| **What syncs** | Scoped statuses (not all historical delivered) — retention docs |
| **How it syncs** | Paged list APIs; delta `updated_since` after first full pull |
| **Local lists** | Pagination / limits in DAOs; list UI guidance for 50K–100K patterns |
| **Writes** | Batched SQLite; single-writer queue processing |
| **Throughput** | P1 parallel sweeps + P2 `per_page=150` + P5 checksum skip done; see [sync-performance-todo.md](./sync-performance-todo.md) |
| **UI thrash** | Debounced delivery list invalidation (A3 partial) |

If company data grows to “millions of fleet deliveries,” **mobile still only
syncs this courier’s slice**. Accuracy does not require loading the entire
fleet onto the device.

---

## Verification checklist (accuracy)

Use before releasing sync-related changes:

1. Offline delivery submit → appears in local list → survives app kill → flushes when online.  
2. API down (`apiUnreachable`) → submit still queues; no successful PATCH until online.  
3. Web changes pending → delivered → next online sync reflects server (Rule 1/3).  
4. Local delivered while server still pending → local stays delivered until server terminal (Rule 2).  
5. Cancelled/reassigned barcode → removed after full sweep (Rule 4).  
6. Concurrent multi-submit + auto-sync → no permanently stuck `pending` ops without a later flush.  
7. Large courier load (hundreds–thousands of assigned items) → paged bootstrap completes; lists remain usable ([production-readiness-large-datasets.md](../production-readiness-large-datasets.md)).

Automated anchors: `test/features/sync/`, `test/features/bagsakan/bagsakan_sync_edge_test.dart`, `test/core/sync/`.

---

## Related

- [system-map.md](./system-map.md)  
- [ops-runbook.md](./ops-runbook.md) — field support; **updates must not be lost**  
- [../core/sync.md](../core/sync.md)  
- [../mobile-delivery-retention.md](../mobile-delivery-retention.md)  
- [../features/timestamp-sync-contract.md](../features/timestamp-sync-contract.md)  
