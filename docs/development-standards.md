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
4. [Mobile Development Rules (Flutter & Riverpod)](#mobile-development-rules-flutter--riverpod)
5. [Logging & Observability Standards](#logging--observability-standards)
6. [Testing Requirements](#testing-requirements)
7. [Documentation Standards](#documentation-standards)
8. [Security & Data Protection](#security--data-protection)
9. [Performance & Optimization](#performance--optimization)
10. [File Management & Navigation](#file-management--navigation)
11. [Error Handling & Recovery](#error-handling--recovery)
12. [Dynamic Design & Overflow Prevention](#dynamic-design--overflow-prevention)
13. [Separation of Concerns & Logic Mapping](#separation-of-concerns--logic-mapping)

---

## Project Context & Core Memory

### System Overview

The GDTMS v2 Courier Mobile App is an **enterprise courier management platform** built with Flutter, focusing on:

- Offline-first execution and local SQLite persistence
- Background synchronization with the Bumble backend
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
- Write unit tests for local SQLite DAO logic (using sqflite_common_ffi for desktop).

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

## 12. Dynamic Design & Overflow Prevention

To ensure a premium feel across all device sizes (including small screens), UI components must be **defensive** against data length and layout constraints.

### Goal: Zero `RenderFlex` Overflows

1. **Flexible Text**: **NEVER** place a `Text` widget inside a `Row` or `Column` without considering its potential length.
   - **Fix**: Wrap `Text` in `Flexible` or `Expanded` and use `overflow: TextOverflow.ellipsis`.
2. **Scrollable Containers**: Ensure lists and dense forms are wrapped in `SingleChildScrollView` or `ListView`.
3. **Adaptive Layouts**: Use `MediaQuery` or `LayoutBuilder` to adjust spacing on smaller devices if the standard 5-tier spacing causes crowding.

**Bad Pattern Example (Causes Overflow):**

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

## 13. Separation of Concerns & Logic Mapping

To maintain a scalable codebase, we enforce a strict separation between **Definitions** (What), **Configurations** (How), and **Implementations** (Execution).

### 🏛️ The Three-Layer Rule

1.  **Tokens & Definitions (The "What")**:
    *   Found in: `lib/design_system/tokens/`, `lib/core/constants.dart`.
    *   Rules: Pure data constants. **NO** logic, **NO** context-aware building.
    *   *Example*: `DSColors.primary` is just a `Color` object.

2.  **Configurations & Themes (The "How")**:
    *   Found in: `lib/design_system/ds_theme.dart`.
    *   Rules: Maps tokens to the Flutter framework. This is where you configure `ThemeData`, `InputDecorationTheme`, etc.
    *   *Example*: `DSTheme.build()` takes `DSColors` and builds a `ThemeData`.

3.  **Implementations & UI (The "Execution")**:
    *   Found in: `lib/features/`, `lib/shared/widgets/`.
    *   Rules: Uses the configurations and tokens to build user-facing features.
    *   *Example*: `DeliveryCard` uses `DSSpacing` and inherits colors from `Theme.of(context)`.

### Why we do this:
- **Maintainability**: Changing a color token in one file updates the entire app.
- **Predictability**: Developers know exactly where to go to change a specific UI behavior vs. a specific raw value.
- **Safety**: Logic-heavy files stay lean by offloading static configurations to dedicated files.

---

**This is your source of truth for the Courier Mobile App. Consult it before every coding session.**

Last Updated: April 28, 2026
