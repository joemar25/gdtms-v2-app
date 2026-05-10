# Bagsakan Offline-First Sync Tests

## Overview

Comprehensive test suite for the offline-first, strong sync capabilities of the bagsakan module. Tests cover local queueing, operation ordering, dependency resolution, conflict handling, and UI indicators.

---

## Test Files Created

### 1. `test/features/bagsakan/bagsakan_offline_sync_test.dart`

**Purpose**: Core offline sync behavior and operation queueing

**Tests**:
- ✅ `CREATE_BAGSAKAN operation queues locally when offline`
- ✅ `CREATE_BAGSAKAN payload contains group metadata`
- ✅ `ASSIGN_TO_BAGSAKAN queues assignments locally`
- ✅ `Multiple operations queue in order when offline`
- ✅ `ASSIGN operation waits for CREATE to sync first`
- ✅ `Dependent operations are requeued when dependency not met`
- ✅ `Barcode conflict detected in ASSIGN operation`
- ✅ `Synced operations deleted after retention period`
- ✅ `Pending operations NOT deleted even after retention period`
- ✅ `No local persistence for bagsakan groups when offline`
- ✅ `Operations sync in correct order: CREATE → ASSIGN → SUBMIT`
- ✅ `Each operation has unique X-Request-ID for idempotency`
- ✅ `Failed operation retries with exponential backoff`
- ✅ `DELETE_BAGSAKAN allows atomic cancellation for local-only groups`
- ✅ `UPDATE_BAGSAKAN_GROUP operation queues correctly`
- ✅ `UI displays "⏳ Pending Sync" badge for queued operations`
- ✅ `UI displays "✓ Synced" badge when operation completed`

**Coverage**:
- Operation queueing (offline behavior)
- Dependency ordering
- Conflict handling
- Data retention
- UI indicators

---

### 2. `test/features/bagsakan/bagsakan_form_screen_offline_test.dart`

**Purpose**: UI integration tests for offline status display

**Tests**:
- ✅ `Shows ConnectionStatusBanner when offline`
- ✅ `Shows ConnectionStatusBanner when API unreachable`
- ✅ `Does not show banner when online`
- ✅ `Form allows saving while offline (operations queued)`

**Coverage**:
- ConnectionStatusBanner integration
- Offline form behavior
- Form accessibility when offline

---

### 3. `test/core/sync/bagsakan_operation_ordering_test.dart`

**Purpose**: Sync manager operation sequencing and dependencies

**Tests**:
- ✅ `Operations execute in required precedence order`
- ✅ `ASSIGN operation blocked if CREATE not synced`
- ✅ `DELETE operation blocks dependent operations`
- ✅ `Multiple groups can be processed in parallel (independent)`
- ✅ `Payload includes group_id for dependent operations`
- ✅ `Deleted synced operations removed from queue`
- ✅ `Retry count incremented on failure`
- ✅ `Conflict status prevents auto-retry`
- ✅ `Processing state prevents duplicate concurrent syncs`

**Coverage**:
- Operation sequencing rules
- Dependency resolution
- Concurrent group handling
- Retry logic
- Processing state management

---

### 4. `test/core/database/bagsakan_dao_offline_queuing_test.dart`

**Purpose**: DAO layer offline queuing behavior

**Tests**:
- ✅ `createBagsakanGroup queues CREATE_BAGSAKAN operation`
- ✅ `assignToBagsakan queues ASSIGN_TO_BAGSAKAN operation`
- ✅ `assignToBagsakan merges with existing pending ASSIGN`
- ✅ `updateBagsakanGroup queues UPDATE_BAGSAKAN_GROUP operation`
- ✅ `deleteBagsakanGroup queues DELETE_BAGSAKAN_GROUP operation`
- ✅ `deleteBagsakanGroup cancels all operations atomically for local-only groups`
- ✅ `unassignFromBagsakan queues UNASSIGN_FROM_BAGSAKAN operation`
- ✅ `submitBagsakanGroup queues SUBMIT_BAGSAKAN operation`
- ✅ `All queued operations have accurate createdAt timestamp`
- ✅ `Each operation has unique UUID for idempotency`
- ✅ `Bagsakan groups NOT stored locally, only operations queued`

**Coverage**:
- All CRUD operations on bagsakan groups
- Offline queuing at the DAO layer
- Operation merging
- Atomic cancellation
- Idempotency via UUID

---

## Key Test Scenarios

### Offline-First Workflow

```
User Offline:
  1. Create bagsakan group → CREATE_BAGSAKAN queued (pending)
  2. Assign items → ASSIGN_TO_BAGSAKAN queued (pending)
  3. View UI → See "⏳ Pending Sync" badge
  4. Form shows ConnectionStatusBanner

User Goes Online:
  1. SyncManager picks up pending operations
  2. Verifies CREATE completed before running ASSIGN
  3. If dependency not met, ASSIGN requeued
  4. On completion → "✓ Synced" badge shown
```

### Dependency Resolution

```
Queue: [CREATE_1, ASSIGN_1, CREATE_2, ASSIGN_2]
Process:
  - CREATE_1 ✓ → ASSIGN_1 ✓ (CREATE_1 dependency met)
  - CREATE_2 ✓ → ASSIGN_2 ✓ (CREATE_2 dependency met)
```

### Conflict Handling

```
ASSIGN ["PKG001"] to Group 1:
  → PKG001 already in Group 2
  → 409 Conflict with {already_assigned_barcodes: ["PKG001"], group_name: "Group 2"}
  → Operation marked 'conflict' status
  → UI offers resolution options
```

### Data Retention

```
Synced Operations:
  - Deleted after sync_retention_days (configurable)
  
Pending Operations:
  - Retained indefinitely until sync succeeds
  
Conflict Operations:
  - Retained until user resolves (max 7 days)
```

---

## Running the Tests

### All offline-first tests:
```bash
flutter test test/features/bagsakan/bagsakan_offline_sync_test.dart \
              test/features/bagsakan/bagsakan_form_screen_offline_test.dart \
              test/core/sync/bagsakan_operation_ordering_test.dart \
              test/core/database/bagsakan_dao_offline_queuing_test.dart
```

### Individual test file:
```bash
flutter test test/core/database/bagsakan_dao_offline_queuing_test.dart
```

### With verbose output:
```bash
flutter test -v test/features/bagsakan/bagsakan_offline_sync_test.dart
```

---

## Coverage Areas

### ✅ Covered

- [x] Offline operation queueing (all 6 operation types)
- [x] Operation dependency resolution
- [x] Conflict detection and handling
- [x] Retry logic with exponential backoff
- [x] Data retention and cleanup
- [x] No local group persistence
- [x] Idempotency via X-Request-ID
- [x] UI indicators (badges)
- [x] ConnectionStatusBanner integration
- [x] Form behavior when offline/online
- [x] Concurrent independent group processing
- [x] Atomic cancellation for local-only groups
- [x] Multiple operation queuing in order

### 📋 Future Coverage

- [ ] End-to-end sync with mock API server
- [ ] Connectivity state transitions (online ↔ offline)
- [ ] Large batch operation handling (1000+ barcodes)
- [ ] Stress test: concurrent queue processing
- [ ] Network failure scenarios (timeout, 5xx errors)
- [ ] Database corruption recovery
- [ ] Clock rollback detection

---

## Test Organization

```
test/
├── features/bagsakan/
│   ├── bagsakan_offline_sync_test.dart ........................ Core sync
│   └── bagsakan_form_screen_offline_test.dart ................. UI integration
├── core/
│   ├── sync/
│   │   └── bagsakan_operation_ordering_test.dart .............. Sync manager
│   └── database/
│       └── bagsakan_dao_offline_queuing_test.dart ............. DAO layer
```

---

## Key Assertions

### Operation Queueing
```dart
expect(op.operationType, 'CREATE_BAGSAKAN');
expect(op.status, 'pending');
expect(op.barcode, 'BAGSAKAN_42');
```

### Operation Ordering
```dart
expect(pending[0].operationType, 'CREATE_BAGSAKAN');
expect(pending[1].operationType, 'ASSIGN_TO_BAGSAKAN');
expect(pending[0].createdAt <= pending[1].createdAt, true);
```

### Dependency Blocking
```dart
final waiting = await mockDao.hasUnfinishedCreateBagsakan(
  'courier-1', 1, excludeOperationId: 'op-assign'
);
expect(waiting, true); // ASSIGN blocked until CREATE syncs
```

### No Local Persistence
```dart
verify(mockSyncOpsDao.insert(any)).called(1);
// No cache or separate group record — only sync_operations table
```

---

## Dependencies

Tests use:
- `flutter_test`
- `mockito` for mocking DAOs and providers
- `flutter_riverpod` for provider overrides
- Standard Dart assertions

No external API calls or database connections required (all mocked).

---

## Maintenance Notes

- Tests are mock-based (no real database)
- Safe to run in CI/CD without network
- No test data cleanup required (all in-memory)
- Add new tests when adding bagsakan operation types
- Update operation ordering tests if precedence changes

