# Timestamp Sync Contract

**Supersedes**: `docs/api_timestamp_bug_report.md`

## The rule

> **The device capture time is always the source of truth.**
> The server must never use `now()` (sync time) for a terminal delivery status when the mobile client provides a timestamp.

Couriers work offline. The gap between capture time (when the courier marks a delivery) and sync time (when the device reconnects) can be hours. Any timestamp derived from sync time is wrong.

---

## What the Flutter app sends

### Timestamp format

```dart
final transactionAt = DateTime.now().toLocal().toIso8601String();
// e.g. "2026-05-30T08:55:00.123456"  ← naive local, no Z suffix
```

**Why no UTC conversion (`toUtc()`):**  
The server's Eloquent `datetime` cast reads raw MySQL strings using the app timezone (`Asia/Manila`). Sending UTC (`"...T00:55:00Z"`) causes the string `"00:55:00"` to be read back as `00:55 Manila` = `12:55 AM` instead of the correct `08:55 AM`. Sending naive local time avoids this because Carbon/MySQL interpret it directly as Manila time.

### Fields per status

| Status | `transaction_at` | `delivered_date` |
|--------|:---:|:---:|
| `DELIVERED` | ✅ always | ✅ always (same value) |
| `FAILED_DELIVERY` | ✅ always | ❌ never |
| `MISROUTED` | ✅ always | ❌ never |

`delivered_date` is semantically the confirmed delivery timestamp. It does not belong on failed or misrouted attempts.

### Payload shape by status

```dart
// ALL statuses
final payload = {
  'delivery_status': _status.toUpperCase(),
  'transaction_at': transactionAt,   // always — device capture time
};

// DELIVERED only
if (_isDelivered) {
  payload['delivered_date'] = transactionAt;
  // ... recipient, relationship, placement_type, etc.
}
```

---

## What the server does

### Resolution order (`UpdateDeliveryStatusAction`)

```
delivered_date  (present?)  →  use it          // DELIVERED from mobile
transaction_at  (present?)  →  use it          // FAILED_DELIVERY / MISROUTED from mobile
transactionDate + transactionTime  →  use it   // web admin form only
else  →  now()                                 // should NEVER fire from mobile
```

### DTO mapping (`DeliveryStatusUpdateData`)

```php
deliveredDate:  $data['delivered_date']  ?? null,
transactionAt:  $data['transaction_at']  ?? null,
```

### Guard: `transaction_at` is only stored for terminal statuses

The `DeliveryTimeline` model automatically clears `transaction_at` for non-terminal statuses (`FOR_DELIVERY`, `RETURNED_DELIVERY`, `RTS`, payment events). This is enforced in the model `saving` hook and cannot be bypassed.

Terminal statuses that MAY have `transaction_at`: `DELIVERED`, `FAILED_DELIVERY`, `MISROUTED`.

---

## What NOT to do

| ❌ Wrong | ✅ Correct |
|---|---|
| `DateTime.now().toUtc().toIso8601String()` | `DateTime.now().toLocal().toIso8601String()` |
| Send `delivered_date` for `FAILED_DELIVERY` | Only send `delivered_date` for `DELIVERED` |
| Omit `transaction_at` from the payload | Always include `transaction_at` |
| Server uses `now()` when no mobile timestamp | Server reads `transaction_at` before falling back |
| Re-capture timestamp at sync time | Timestamp is frozen at queue time in `SyncOperation.payloadJson` |

---

## Test coverage

| Test file | What it covers |
|---|---|
| `test/features/delivery/delivery_update_timestamp_test.dart` | Timestamp format (no Z), payload shape per status, JSON roundtrip, offline freeze |
| `tests/Feature/Deliveries/TransactionAtTest.php` (bottom section) | Server PATCH API: capture time preserved, priority order, future rejection, offline 4h delay |

### Rules for writing API timestamp tests

These rules were learned from an intermittent failure in the full test suite.

**1. Never use hardcoded datetime strings as input.**

```php
// ❌ Fails intermittently in the full suite — date may collide with
//    other tests' side effects or timezone edge cases.
$captureTime = '2026-05-30 08:55:00';

// ✅ Always relative to the current test run.
$captureTime = now()->subHours(4);
```

**2. Always call `->toDateTimeString()` when passing a Carbon to a request.**

```php
// ❌ Raw string bypasses Carbon's format guarantee.
'transaction_at' => $captureTime,

// ✅ Explicit format — matches what ->format('Y-m-d H:i:s') asserts against.
'transaction_at' => $captureTime->toDateTimeString(),
```

**3. Assert with the same Carbon object, not a re-parsed string.**

```php
// ❌ Brittle — relies on the string matching the stored format exactly.
expect($timeline->transaction_at->format('Y-m-d H:i:s'))->toBe('2026-05-30 08:55:00');

// ✅ Self-consistent — input and assertion use the same variable.
expect($timeline->transaction_at->format('Y-m-d H:i:s'))->toBe($captureTime->toDateTimeString());
```

**4. Make capture time and sync time clearly distinguishable.**

Use at least a 1-hour gap so a test bug (using `now()` instead of `$captureTime`) is immediately visible in the failure diff, not hidden by clock drift.

```php
$captureTime = now()->subHours(4); // clearly in the past
$syncTime    = now();              // clearly "now"
```

**5. `transaction_at` must be in the FormRequest rules or it will be stripped by `$request->validated()`.**

Fields absent from the FormRequest rules are silently dropped by Laravel before they reach the service/DTO/action. If a new mobile timestamp field is added, add it to `DeliveryStatusUpdateRequest::rules()` first, or the action will always fall back to `now()`.

---

## Files involved

| File | Role |
|---|---|
| `lib/features/delivery/delivery_update_screen.dart` | Builds payload, sets `transaction_at` and conditionally `delivered_date` |
| `lib/core/database/sync_operations_dao.dart` | Stores `SyncOperation` with frozen `payloadJson` |
| `lib/core/sync/sync_manager.dart` | Sends frozen payload to server; never modifies timestamps |
| `app/DTOs/DeliveryStatusUpdateData.php` | Maps `transaction_at` and `delivered_date` from request |
| `app/Actions/Deliveries/UpdateDeliveryStatusAction.php` | Resolves `$actionTime` using priority order above |
| `app/Models/DeliveryTimeline.php` | Guard: clears `transaction_at` for non-terminal statuses |
