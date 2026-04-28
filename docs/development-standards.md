# Development Standards for GDTMS v2 Mobile App

> **Reference Guide for Developers & AI Assistants**  
> Last Updated: April 28, 2026  
> Focus: Flutter / Dart Mobile Development

**Quick Start:** For day-to-day development, refer to this document. It outlines the core architecture, rules, and best practices for the FSI Courier Mobile App.

---

## Table of Contents

1. [Project Context & Core Memory](#project-context--core-memory)
2. [Developer Workflow](#developer-workflow)
3. [Code Quality Standards](#code-quality-standards)
4. [Tooling & Code Health Checks](#tooling--code-health-checks)
5. [Commenting Standards — Be a Rockstar Commenter](#commenting-standards--be-a-rockstar-commenter)
6. [Mobile Development Rules (Flutter & Riverpod)](#mobile-development-rules-flutter--riverpod)
7. [Logging & Observability Standards](#logging--observability-standards)
8. [Testing Requirements](#testing-requirements)
9. [Documentation Standards](#documentation-standards)
10. [Security & Data Protection](#security--data-protection)
11. [Performance & Optimization](#performance--optimization)
12. [File Management & Navigation](#file-management--navigation)
13. [Error Handling & Recovery](#error-handling--recovery)
14. [Dynamic Design & Overflow Prevention](#dynamic-design--overflow-prevention)
15. [Separation of Concerns & Logic Mapping](#separation-of-concerns--logic-mapping)

---

## Project Context & Core Memory

### System Overview

The GDTMS v2 Courier Mobile App is an **enterprise courier management platform** built with Flutter, focusing on:

- Offline-first execution and local SQLite persistence
- Background synchronization with the Sample backend
- Real-time delivery status updates (POD scanning)
- Delivery timeline tracking
- Secure authentication and token management

**Business Critical Rules** (Never violate):

1. **Offline-First Resilience**: The app must operate without internet access. All actions write to the local SQLite database first, then sync to the server when connectivity is restored.
2. **Immutable Final States**: Once a delivery is marked as Delivered or Failed Verification, it is sealed locally.
3. **Data Integrity**: Local database operations must be transactional where applicable.
4. **Single Device Session**: One active session per courier enforced by device fingerprinting.

---

## Developer Workflow

### 🎯 Core Principle: Think Before You Code

**NEVER** jump straight to implementation. Follow this workflow:

1. **UNDERSTAND** → Read context from related feature docs and APIs.
2. **PLAN** → Break down the task, identify affected screens, providers, and database DAOs.
3. **VERIFY** → Search existing codebase for similar patterns (e.g., custom widgets, existing Riverpod providers).
4. **IMPLEMENT** → Write code following standards, reuse existing patterns.
5. **TEST** → Test UI changes on multiple device dimensions and orientations, verify offline behavior.
6. **DOCUMENT** → Update relevant markdown docs.
7. **REVIEW** → Self-review against this checklist before committing.

### When Stuck

If you encounter uncertainty:

1. **State what you know**: "I understand X, but I'm unsure about Y"
2. **Propose options**: "I see two approaches: A (pros/cons) vs B (pros/cons)"
3. **Ask specific questions**: "Should I use approach A or B, given constraint X?"

---

## Code Quality Standards

> Cheat codes don't exist in production. Write it right the first time.

### The Golden Rule

Write production-grade code on the first pass. No `// TODO: optimize later`, no placeholder types, no commented-out dead code shipped.

### Rules

#### 01 — Max 600 executable lines per file

Controllers, Screens, and Providers should stay lean.

- **When to split:**
  - Screen file getting fat? → Extract widgets into `<feature>_components.dart`.
  - Provider doing too much? → Split the state logic or extract repositories.

#### 02 — Strict Type Safety and No `dynamic` by default

- Do not use `dynamic` unless absolutely necessary (e.g., parsing raw JSON).
- Always use strongly typed variables and return types.
- Ensure `flutter analyze` passes with zero warnings.

#### 03 — Use `const` everywhere possible

- Always add `const` constructors to Widgets.
- Always use `const` for structural widget compositions to prevent unnecessary widget rebuilds.
- Enable `prefer_const_constructors` in `analysis_options.yaml`.

#### 04 — Design System Strict Compliance

Duplicate UI code and hardcoded values are technical debt.

- **Centralized Tokens**: **NEVER hardcode colors, spacing, or animation durations**. Use `DSColors`, `DSSpacing`, and `DSStyles`.
- **The 5-Tier Rule**: All layout and style configurations (Typography, Spacing, Elevation, Animations) must strictly follow a **3-to-5 tier scale** (XS, SM, MD, LG, XL). MD is the standard. Avoid creating new "tiers" for specific layout needs; always align to the nearest standard token to ensure app-wide consistency.
- **Typography for All**: **NEVER** use direct `TextStyle()` constructors. Always use `DSTypography` methods. This ensures the correct Montserrat weight mapping and theme-aware colors are used app-wide.
- **Search Before Creating**: Check `lib/shared/widgets/` for existing molecules/atoms before building a new UI component.
- **Icons**: Use `DSColors.labelSecondary` or `Theme.of(context).iconTheme.color` for icons. Do not hardcode `Colors.black54` etc.

#### 05 — Single Responsibility

- **Screen (`.dart`)**: UI layout, user interaction, connecting to Riverpod.
- **Provider (`.dart`)**: State management, business logic orchestration.
- **Repository/DAO (`.dart`)**: Data access, API calls, SQLite queries.
- **Model (`.dart`)**: Immutable data classes (use `freezed` or `equatable` where appropriate).

---

## Tooling & Code Health Checks

> 🔧 **Mandatory before every commit.** Running `flutter analyze` and `dart format` is not optional — it is a gate check. Zero warnings, zero errors, zero unformatted files. Ship clean or don't ship.

### 06 — Always Run `flutter analyze` Before Every Commit

`flutter analyze` runs the Dart static analyzer across the entire codebase. It catches type errors, deprecated API usage, lint violations, and dead code — **before they reach production.**

#### Non-Negotiables

- Run `flutter analyze` before **every commit** without exception.
- **Zero warnings policy**: the pipeline does not accept a codebase with outstanding analyzer warnings. Warnings today become crashes tomorrow.
- Do **not** suppress warnings with `// ignore:` unless you can write a full justification comment explaining why suppression is safe. Suppression is a last resort, not a shortcut.
- Enable strict analysis in `analysis_options.yaml`:

```yaml
analyzer:
  strong-mode:
    implicit-casts: false
    implicit-dynamic: false

linter:
  rules:
    - prefer_const_constructors
    - prefer_const_declarations
    - avoid_dynamic_calls
    - always_declare_return_types
    - unawaited_futures
    - avoid_print
    - unnecessary_null_checks
    - prefer_typing_uninitialized_variables
```

#### Pre-Commit Workflow

```bash
# Step 1: Analyze — must return zero issues
flutter analyze

# Step 2: Format — must return zero changes
dart format --set-exit-if-changed .

# Step 3: Tests — must pass
flutter test
```

> 🚫 **CI/CD Gate**: Both `flutter analyze` and `dart format --set-exit-if-changed .` are enforced in the CI pipeline. A failing check blocks the merge. There is no bypass.

---

### 07 — Always Run `dart format` — Zero Unformatted Files

Inconsistent formatting is noise in code reviews. `dart format` enforces the canonical Dart style guide automatically, keeping diffs clean and readable.

#### Rules

- Run `dart format .` before every commit to auto-format all Dart files.
- In CI, `dart format --set-exit-if-changed .` is run as a gate — unformatted code **fails the pipeline**.
- Configure your IDE to **format on save**. This is mandatory for all team members.
- Line length: the project uses the **default 80-character limit**. Do not override this per-file.
- **Never hand-format code or fight the formatter.** If a code pattern looks awkward when formatted, the pattern is probably wrong — not the formatter.

#### IDE Setup — VS Code

```json
// settings.json
{
  "editor.formatOnSave": true,
  "[dart]": {
    "editor.defaultFormatter": "Dart-Code.dart-code",
    "editor.formatOnSave": true
  }
}
```

#### IDE Setup — Android Studio / IntelliJ

- **Settings → Languages & Frameworks → Flutter** → Enable "Format code on save"
- **Settings → Editor → Code Style → Dart** → Set "Right margin (columns)" to `80`

> ✅ **The Golden Combo**: `flutter analyze && dart format --set-exit-if-changed .` must both exit with code `0` before any commit is pushed. Treat a non-zero exit as a build-breaking bug.

---

## Commenting Standards — Be a Rockstar Commenter

> 💬 **The Philosophy**: Comments are love letters to your future self and your teammates. Great comments don't explain **WHAT** the code does — the code does that. Great comments explain **WHY** it exists, **WHAT** decisions were made, and **WHAT** traps to avoid.

---

### 08 — DartDoc for Every Public API (`///` Triple-Slash)

Every public class, method, and property **MUST** have a triple-slash DartDoc comment. This is non-negotiable.

#### Class-Level DartDoc

```dart
/// Manages the full lifecycle of a single delivery item.
///
/// This provider acts as the single source of truth for delivery state.
/// All mutations go through here — never update the delivery model directly
/// from a screen widget.
///
/// ### Offline Behavior
/// When the device is offline, state changes are written to the local
/// SQLite store via [DeliveryDao]. The [SyncService] will replay them
/// in FIFO order once connectivity is restored.
///
/// ### Immutable Finals
/// A delivery in [DeliveryStatus.delivered] or
/// [DeliveryStatus.failedVerification] cannot be mutated. Any attempt
/// throws an [ImmutableDeliveryException].
///
/// See also:
///  - [DeliveryDao] for the underlying SQLite operations.
///  - [SyncService] for background sync logic.
class DeliveryProvider extends StateNotifier<DeliveryState> {
  DeliveryProvider(this._dao, this._syncService)
      : super(DeliveryState.initial());
}
```

#### Method-Level DartDoc

```dart
/// Marks the delivery as [DeliveryStatus.delivered] and seals it locally.
///
/// ### What this does
/// 1. Validates that the barcode matches the expected delivery manifest.
/// 2. Captures a timestamped proof-of-delivery (POD) entry.
/// 3. Writes the sealed state to SQLite (transactional).
/// 4. Enqueues a sync payload for the Sample backend.
///
/// ### Why sealed?
/// Delivery records are legally binding. Once confirmed, any mutation
/// would break the audit trail. This is enforced at the domain level,
/// not just at the UI level.
///
/// Throws [BarcodeValidationException] if [barcode] does not match
/// the delivery manifest.
/// Throws [ImmutableDeliveryException] if the delivery is already in
/// a final state.
///
/// [barcode] The scanned barcode string from the POD scanner widget.
Future<void> confirmDelivery(String barcode) async {
  // implementation
}
```

---

### 09 — Inline Comments: The WHY, Not the WHAT

> ⚠️ **Rule**: If your inline comment describes **WHAT** the code does, delete it. The code does that. Comments explain **WHY**.

```dart
// ❌ BAD — restates the code, adds zero value
// Increment the retry count
retryCount++;

// ✅ GOOD — explains the business constraint behind the decision
// The Sample API enforces a max of 3 retries per sync window.
// Beyond this, we surface a hard error to avoid flooding the queue
// with unresolvable requests during extended outages.
retryCount++;
if (retryCount >= kMaxSyncRetries) {
  throw SyncRetryLimitException(deliveryId: delivery.id);
}
```

---

### 10 — Section Dividers for Large Files

For files over 200 lines, divide logical sections with clearly labeled block comments. This lets any developer jump to the right section in seconds.

```dart
// ─────────────────────────────────────────────────
// MARK: Initialization & Lifecycle
// ─────────────────────────────────────────────────

// ... init code ...

// ─────────────────────────────────────────────────
// MARK: Sync Queue Management
// ─────────────────────────────────────────────────

// ... sync code ...

// ─────────────────────────────────────────────────
// MARK: Error Handling
// ─────────────────────────────────────────────────
```

---

### 11 — TODO & FIXME: Track It or Kill It

> 🗂️ **Rule**: A TODO without a ticket number and owner is dead weight. Every TODO must be actionable and traceable.

```dart
// ❌ BAD — vague, unowned, will never be resolved
// TODO: fix this later

// ✅ GOOD — owner, ticket, and clear description
// TODO(mar1): [GDTMS-421] Replace polling with WebSocket push
// when the Sample v3 API is available (ETA: Q3 2026).

// FIXME(mar2): [GDTMS-438] Race condition on concurrent scans.
// Repro: scan two barcodes simultaneously in < 200ms.
// Mitigation: debounce at 300ms in the scan input handler.
```

---

### 12 — Business Logic Comments: Explain the Domain

When code implements a non-obvious business rule, write a comment that a new developer could hand to a product manager and have them confirm it is correct.

```dart
// Business Rule: A courier can only re-attempt a failed delivery
// up to 3 times per working day. On the 4th failure, the delivery
// is automatically escalated to the Dispatch team and locked for
// that courier. — Ref: Ops Policy v2.3, Section 4.1
if (delivery.failureCount >= kMaxDailyRetries) {
  await _escalateToDispatch(delivery);
  return;
}
```

---

### Commenting Cheat Sheet

| Type            | Syntax                      | Use For                                      |
| --------------- | --------------------------- | -------------------------------------------- |
| DartDoc         | `/// text`                  | Public API: classes, methods, properties     |
| Inline          | `// text`                   | WHY a decision was made (never WHAT)         |
| Section Divider | `// ─── MARK: Title ───`    | Navigate large files (200+ lines)            |
| TODO (tracked)  | `// TODO(owner): [TICKET]`  | Known future work — must have ticket         |
| FIXME (tracked) | `// FIXME(owner): [TICKET]` | Known bugs — must have ticket + repro steps  |
| Business Rule   | `// Business Rule: ...`     | Non-obvious domain logic with policy ref     |
| Suppression     | `// ignore: lint_rule`      | **LAST RESORT** — must include justification |

---

## Mobile Development Rules (Flutter & Riverpod)

### Directory Structure

```text
lib/
├── core/
│   ├── api/            # API client and interceptors
│   ├── database/       # SQLite DAOs and migrations
│   ├── models/         # Core domain models
│   ├── providers/      # Global state providers
│   └── sync/           # Background synchronization logic
├── design_system/      # Tokens (DSColors, DSStyles, DSSpacing)
├── features/           # Feature modules (e.g., delivery, scan, auth)
│   └── {feature_name}/
│       ├── {feature}_screen.dart
│       ├── {feature}_components.dart
│       └── {feature}_provider.dart
├── shared/
│   ├── helpers/        # Utility functions and formatters
│   ├── router/         # GoRouter configuration
│   └── widgets/        # Reusable global UI components
└── main.dart
```

### Quick Reference

| Concern          | Rule                                                                                        |
| ---------------- | ------------------------------------------------------------------------------------------- |
| State Management | Use `Riverpod` (`ConsumerWidget`, `ConsumerStatefulWidget`). No `setState` for global data. |
| Navigation       | Use `go_router` (`context.push`, `context.go`).                                             |
| Database         | Use `sqflite` with robust DAO classes.                                                      |
| Styling          | **Never hardcode values**. Strictly use `DSColors`, `DSStyles`, and `DSTypography`.         |
| API Calls        | Route through `ApiClient` for consistent error handling and token injection.                |
| Offline          | Always read from Local DB. Background sync queues update the server.                        |

---

## Logging & Observability Standards

### 1. Appropriate Log Levels

Use a logging package (like `logger`) or custom debug wrappers.

- `debugPrint()` for simple development checks.
- Structured logging for critical operations (e.g., Sync Service, API Errors).

### 2. Capture Sufficient Context

When logging an error, capture:

- Delivery/Barcode ID
- Sync attempt count
- Error stack trace

```dart
// ✅ GOOD
logError('Sync failed for delivery', error: e, stackTrace: s, context: {'barcode': delivery.barcode});

// ❌ BAD
print('Error syncing');
```

---

## Testing Requirements

### Test-First Mindset

- Write unit tests for your data parsing and domain models.
- Write unit tests for local SQLite DAO logic (using `sqflite_common_ffi` for desktop).

### Widget Testing

- Test critical UI flows using `WidgetTester`.
- Ensure custom components render correctly with mock Riverpod providers.

---

## Documentation Standards

### Updating Docs

**ALWAYS update docs when**:

- Modifying offline sync behavior.
- Adding a new feature module.
- Changing API payload structures.

### Formatting

- Use Markdown for repository docs.
- Use `///` DartDoc comments for public classes and methods.

---

## Security & Data Protection

- **DO NOT** log passwords, raw auth tokens, or PII.
- Securely store API tokens using `flutter_secure_storage`.
- The SQLite database must clear user-specific data on logout to prevent cross-session leakage.

---

## Performance & Optimization

### Widget Rebuilds

- Use `Consumer` localized to the exact widget tree that needs rebuilding instead of wrapping the entire screen.
- Use `select` in Riverpod to listen only to specific property changes: `ref.watch(provider.select((s) => s.property))`.

### Lists and Scrolling

- Always use `ListView.builder` or `SliverList` for dynamic lists. Never map a huge list into a `Column`.
- Ensure images and assets are properly sized.

---

## File Management & Navigation

- Keep feature modules small and well-scoped under `lib/features/{feature}`.
- Reuse shared widgets in `lib/shared/widgets/` and design-system tokens from `lib/design_system/`.
- Prefer `go_router` for navigation with `context.push` / `context.go`; avoid raw `Navigator` chains unless explicitly required.
- Separate large screens into smaller components and providers when a file grows past a few hundred lines.

---

## Error Handling & Recovery

### API and Network

- Distinguish between `ApiNetworkError` (offline) and `ApiServerError` (500).
- The app must gracefully degrade when offline, caching requests into the sync queue.

### User Feedback

- Use `showErrorNotification()` and `showInfoNotification()` for uniform snackbars.
- Never show a raw Exception string directly to the user.

---

## Dynamic Design & Overflow Prevention

To ensure a premium feel across all device sizes (including small screens), UI components must be **defensive** against data length and layout constraints.

### Goal: Zero `RenderFlex` Overflows

1. **Flexible Text**: **NEVER** place a `Text` widget inside a `Row` or `Column` without considering its potential length.
   - **Fix**: Wrap `Text` in `Flexible` or `Expanded` and use `overflow: TextOverflow.ellipsis`.
2. **Scrollable Containers**: Ensure lists and dense forms are wrapped in `SingleChildScrollView` or `ListView`.
3. **Adaptive Layouts**: Use `MediaQuery` or `LayoutBuilder` to adjust spacing on smaller devices if the standard 5-tier spacing causes crowding.

**Bad Pattern (Causes Overflow):**

```dart
Row(
  children: [
    Icon(Icons.star),
    Text("Very Long Label that will eventually overflow the screen on small devices") // ❌ WRONG
  ],
)
```

**Good Pattern (Safe):**

```dart
Row(
  children: [
    Icon(Icons.star),
    Flexible(
      child: Text(
        "Very Long Label...",
        overflow: TextOverflow.ellipsis, // ✅ CORRECT
      ),
    ),
  ],
)
```

---

## Separation of Concerns & Logic Mapping

To maintain a scalable codebase, we enforce a strict separation between **Definitions** (What), **Configurations** (How), and **Implementations** (Execution).

### 🏛️ The Three-Layer Rule

1. **Tokens & Definitions (The "What")**:
   - Found in: `lib/design_system/tokens/`, `lib/core/constants.dart`.
   - Rules: Pure data constants. **NO** logic, **NO** context-aware building.
   - _Example_: `DSColors.primary` is just a `Color` object.

2. **Configurations & Themes (The "How")**:
   - Found in: `lib/design_system/ds_theme.dart`.
   - Rules: Maps tokens to the Flutter framework. This is where you configure `ThemeData`, `InputDecorationTheme`, etc.
   - _Example_: `DSTheme.build()` takes `DSColors` and builds a `ThemeData`.

3. **Implementations & UI (The "Execution")**:
   - Found in: `lib/features/`, `lib/shared/widgets/`.
   - Rules: Uses the configurations and tokens to build user-facing features.
   - _Example_: `DeliveryCard` uses `DSSpacing` and inherits colors from `Theme.of(context)`.

### Why we do this

- **Maintainability**: Changing a color token in one file updates the entire app.
- **Predictability**: Developers know exactly where to go to change a specific UI behavior vs. a specific raw value.
- **Safety**: Logic-heavy files stay lean by offloading static configurations to dedicated files.

---

**This is your source of truth for the Courier Mobile App. Consult it before every coding session.**

Last Updated: April 28, 2026
