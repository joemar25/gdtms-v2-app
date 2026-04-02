# Bug Report: Missing timezone in delivery timestamps → client shows shifted times

Summary
-------
Some API responses return ISO-8601 datetimes without an explicit timezone (e.g. `2026-04-03T01:16:00.000`). Mobile clients must assume a timezone for such values; inconsistent assumptions produce an 8‑hour shift in the courier app's UI after sync.

Fields affected
---------------
- `transaction_at`
- `delivered_date`

Observed
--------
- Courier captures delivery on-device at `Apr 3 01:16 AM` (PST, UTC+8).
- The sync UI later shows `Apr 2 05:16 PM` for the same delivery (8 hours earlier).
- This happens even when the device has not yet uploaded the update (local queue view).

Likely cause
------------
Server sometimes emits naive ISO strings (no timezone suffix). Different clients interpret these differently (device-local vs UTC). If the server intended the timestamp to be in the Philippines timezone but omitted the `Z` or explicit `+08:00`, many clients will treat it as UTC and display an 8-hour-shifted instant.

Reproduction steps (suggested)
----------------------------
1. From the mobile app, capture a delivery at local time (e.g. `2026-04-03T01:16:00.000` PST).
2. Observe queued entry in `/sync` (should show the local timestamp in the UI).
3. Compare server-side record returned by `GET /api/mbl/deliveries/{barcode}` (or PATCH response) for `transaction_at` / `delivered_date`.
4. If the server value lacks timezone (no `Z` or `+08:00`), confirm the mismatch.

Example — problematic response
------------------------------
```json
{
  "data": {
    "barcode": "ABC123",
    "transaction_at": "2026-04-03T01:16:00.000",
    "delivered_date": "2026-04-03T01:16:00.000"
  }
}
```

Expected (recommended)
----------------------
Always return timezone-aware ISO-8601 timestamps. Two recommended options:

- Use UTC (preferred):

```json
"transaction_at": "2026-04-02T17:16:00.000Z"
```

- Or include explicit offset (if server stores local datetimes):

```json
"transaction_at": "2026-04-03T01:16:00.000+08:00"
```

Server-side recommendations
---------------------------
1. Ensure the API responses always include timezone information for datetime fields (`Z` for UTC, or explicit offset).
2. Persist datetimes in UTC (e.g. `TIMESTAMP WITH TIME ZONE`) and serialize responses as UTC (`Z`). This avoids ambiguity when clients are in different timezones.
3. When accepting client-submitted timestamps, treat them as instants (store/convert in UTC) and echo back the same instant in the response.

Client-side mitigation (already applied)
---------------------------------------
- The mobile client now treats naive strings as local-first (to better match servers that emit local timestamps), and also temporarily sends `delivered_date` with explicit `+08:00` offset when queuing updates. These are stop-gap measures — the correct fix is server-side.

Action requested from API team
-----------------------------
Please confirm which timezone is intended for `transaction_at` and `delivered_date`, and update the API to always return timezone-aware ISO-8601 datetimes. If you prefer UTC, please return `Z` suffixed values. If the values are local (PH), include `+08:00` explicitly.

Attach: raw server response for a failing barcode (the full `data` object) so we can verify.
