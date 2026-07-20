<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  Support / field ops runbook for courier sync issues. Update when queue
  statuses, UI paths, or recovery tools change. Link from architecture hub,
  docs/index.md, README.md, features/sync-history.md, features/error-logs.md.
  ══════════════════════════════════════════════════════════════════════════════
-->

# Ops runbook — courier updates must not be lost

This mobile app is the **heart of courier field work**. Offline POD updates,
failed delivery, misroute, and bagsakan actions are written to **local SQLite
first**. Losing that queue means losing operational truth.

**Prime directive:** treat every `pending` / `processing` / `failed` / `conflict`
row as **courier work product** until it is `synced` or deliberately resolved
with a server-backed outcome—not “noise to clear.”

---

## 1. Durability guarantees (what the app already does)

| Guarantee | Mechanism | Source |
| --------- | --------- | ------ |
| Write survives kill/power | SQLite insert before success UI | `SyncOperationsDao.insert`, delivery/bagsakan screens |
| Offline still works | No live API required to submit form | Offline-first path |
| API down ≠ drop queue | Flush skipped when `!isOnlineProvider` | `requestFlush`, `completeWrite` |
| Concurrent kicks don’t drop new ops | Coalesced flush + re-run (max 5) | `SyncManager.requestFlush` |
| Recovery when API returns | `reconnected` / `login` skip 30s debounce | `app.dart` `_maybeTriggerSync` |
| Server/admin truth after pull | Rules 1–4 on bootstrap | `delivery_bootstrap_service.dart` |
| Media not “success” if all uploads fail | Stay `failed`, retry later | `sync_manager.dart` |

Full contract: [accuracy-and-scale.md](./accuracy-and-scale.md).  
Flow diagram: [system-map.md](./system-map.md).

### What “not lost” does **not** mean

- Instant appearance on the web if the phone has no path to the API.  
- Auto-resolve of **conflict** without human/server review (409/validation).  
- Recovery after **user or support deliberately wipes app data / clears queue** without backup.

---

## 2. Queue status legend (Sync / History screen)

| Status | Meaning | Courier impact | Support action |
| ------ | ------- | -------------- | -------------- |
| `pending` | Saved locally, not yet sent | Safe; waiting for online flush | Ensure online + Sync Now / wait reconnect |
| `processing` | Flush currently uploading/PATCHing | Safe if app stays open long enough | Wait; if stuck >10 min see §4 |
| `synced` | Server accepted | Done | None |
| `failed` | Attempt failed; will retry | Safe; still on device | Retry; check network/API; see error text |
| `conflict` | Server rejected as non-retryable / business conflict | Needs attention | Read error; fix data or dismiss + reconcile |

Never tell couriers “delete the app and reinstall” as a first step—that can
**destroy the queue**.

---

## 3. Connectivity check (always first)

`isOnlineProvider` requires **both**:

1. Device network (Wi‑Fi / mobile data)  
2. API reachable (app pings API base URL ~every 10s)

| UI / state | Meaning |
| ---------- | ------- |
| Fully online | Flushes and auto-sync can run |
| No bars / airplane | Writes queue only; flush waits |
| Network OK, “server unreachable” | Same as offline for sync—**queue kept** |

If the courier can browse the internet but ITMS/GDTMS API is down, **updates stay
on the phone**. That is correct. Do not clear data.

---

## 4. Playbooks

### A. “My update is stuck pending”

1. Confirm the barcode shows **PENDING SYNC** / History row `pending`.  
2. Confirm connectivity: network **and** API (banner / connection status).  
3. Open **History (Sync)** → pull to refresh or **Sync Now** overlay.  
4. Wait for auto-sync (reconnect, resume, or up to ~3 min periodic when online).  
5. If still `pending` after online + manual Sync:  
   - Note error on any sibling rows  
   - Collect logs (§5)  
   - Escalate eng—do **not** clear app storage  

### B. “Failed — will it try again?”

1. Open History → read `lastError` on the row.  
2. Fix environment (signal, API, storage full, time enforcement if shown).  
3. Retry from History / Error logs retry if available.  
4. Media “all uploads failed” → photos still referenced by paths; fix storage/network and retry—**do not delete media folders**.  

### C. “Conflict”

1. Read conflict message (may include server validation summary).  
2. Common causes: confirmation code, business rule, barcode state already terminal on server.  
3. Prefer **server-backed** resolution (web status check + dismiss/reconcile paths in app).  
4. Do not force re-submit the same invalid payload in a loop.  

### D. “I worked offline all day — did HQ get it?”

1. History must list today’s actions (`pending`/`failed`/`synced`).  
2. When back online: Sync Now; wait until no actionable pending/processing.  
3. Spot-check 2–3 barcodes on web after `synced`.  
4. If rows vanish without `synced`, treat as **P0 data loss** (§6).  

### E. “App reinstalled / data cleared / new phone”

| Situation | Risk | Action |
| --------- | ---- | ------ |
| Fresh install, same phone, data cleared | **Queue gone** | Only server has what already `synced`; offline-only work may be lost—document barcodes from paper/memory if any |
| New phone | Old phone queue not migrated | Complete Sync Now on **old** device before retirement; never wipe old device first |
| Logout | Depends on clearAuth paths | Prefer Sync Now while still logged in |

**Support phrase:** “Finish Sync Now until History is clear, **then** change phones or clear data.”

### F. Stuck `processing` (rare)

1. Force-close app → reopen (should not delete queue).  
2. Online + Sync Now.  
3. If row stays `processing` after restart, escalate eng (possible interrupted write of status field)—still **do not** delete DB.

---

## 5. Logs & evidence (for eng)

Ask courier/support to capture:

1. Screenshots: History rows (barcode, status, error), connection banner.  
2. Approximate time of submit and of Sync Now.  
3. Device logs filtered by:

```
[SYNC] requestFlush
[SYNC] requestFlush skipped — offline/API unreachable
[SYNC] _runFullSync
[SYNC] abort pull
[SYNC] priority reconciliation
[SYNC] ALL media uploads failed
[SYNC] PATCH payload
```

4. App version, courier id/phone, environment (prod/staging).  
5. Whether Error Logs screen shows related entries (`docs/features/error-logs.md`).

---

## 6. Severity guide

| Severity | Example | Response |
| -------- | ------- | -------- |
| **P0** | Queue wiped with only-offline updates; mass disappear without `synced` | Stop further wipes; preserve device; eng + DB forensics if possible |
| **P1** | All couriers cannot reach API; queues growing | Platform/API status; couriers keep working offline; communicate “sync when API back” |
| **P2** | Single barcode conflict / repeated fail | Per-barcode support §4 |
| **P3** | Slow sync, large lists | Performance plans—not data loss |

---

## 7. What support must **never** do first

1. **Clear app data / reinstall** to “fix sync.”  
2. **Clear failed** bulk delete without reading errors (History “clear failed” removes failed ops and media—use only when ops confirmed obsolete).  
3. Tell courier to **toggle airplane mode** as a wipe ritual without Sync Now after recovery.  
4. Assume “not on web yet” = “lost”—check History status first.  

---

## 8. Eng quick reference (no ops change without accuracy review)

| Component | File |
| --------- | ---- |
| Queue DAO | `lib/core/database/sync_operations_dao.dart` |
| Flush / retry / conflict | `lib/core/sync/sync_manager.dart` |
| Post-write kick | `lib/core/sync/sync_write_coordinator.dart` |
| Pull Rules 1–4 | `lib/core/sync/delivery_bootstrap_service.dart` |
| Auto-sync triggers | `lib/app.dart` |
| Online gate | `lib/core/providers/connectivity_provider.dart` |

Any change that deletes queue rows, short-circuits insert, or weakens Rules 1–4
must update this runbook and [accuracy-and-scale.md](./accuracy-and-scale.md).

---

## 9. Courier-facing script (short)

> Your delivery update is saved on the phone first.  
> If the signal or server is down, it stays in History as pending.  
> When you’re online again, open History and tap Sync, or wait a few minutes.  
> Please don’t reinstall or clear app data until History shows synced—or we may lose work that never reached the office.

---

## Related docs

| Doc | Use |
| --- | --- |
| [system-map.md](./system-map.md) | How flush/bootstrap interact |
| [accuracy-and-scale.md](./accuracy-and-scale.md) | Rules 1–4, scope of “accurate” |
| [../core/sync.md](../core/sync.md) | Implementation reference |
| [../features/sync-history.md](../features/sync-history.md) | History UI |
| [../features/delivery.md](../features/delivery.md) | Offline POD submit |
| [../features/error-logs.md](../features/error-logs.md) | Error log screen |
| [../entry-points.md](../entry-points.md) | Auto-sync triggers |

## Automated tests (eng — run before release)

```bash
flutter test test/core/sync/ test/core/providers/delivery_refresh_provider_test.dart test/core/database/insert_all_from_api_checksum_test.dart test/features/sync/sync_manager_test.dart test/features/bagsakan/bagsakan_sync_edge_test.dart
```

| Area | Test location |
| ---- | ------------- |
| P5 checksum + dirty protection | `test/core/sync/sync_upsert_policy_test.dart`, `test/core/database/insert_all_from_api_checksum_test.dart` |
| P1 paging chunks | `test/core/sync/sync_upsert_policy_test.dart` |
| P2 per_page band | `test/core/sync/delivery_bootstrap_perf_constants_test.dart` |
| A3 debounce / scope | `test/core/providers/delivery_refresh_provider_test.dart` |
| Offline flush gate | `test/features/sync/sync_manager_test.dart`, `sync_performance_regression_test.dart` |
| Queue conflict/fail paths | `test/features/bagsakan/bagsakan_sync_edge_test.dart` |
