# Development Standards for GDTMS v2 Mobile App

> **Reference Guide for Developers & AI Assistants**  
> Last Updated: April 30, 2026  
> Focus: Flutter / Dart Mobile Development

**Quick Start:** For day-to-day development, refer to this document. It outlines the core architecture, rules, and best practices for the FSI Courier Mobile App.

---

## Table of Contents

1. [Project Context & Core Memory](#project-context--core-memory)
2. [Developer Workflow](#developer-workflow)
3. [Code Quality Standards](#code-quality-standards)
4. [Tooling & Code Health Checks](#tooling--code-health-checks)
5. [Commenting Standards — Be a Rockstar Commenter](#commenting-standards--be-a-rockstar-commenter)
6. [Localization & Translation Standards](#-localization--translation-standards)
7. [Mobile Development Rules (Flutter & Riverpod)](#mobile-development-rules-flutter--riverpod)
8. [Logging & Observability Standards](#logging--observability-standards)
9. [Testing Requirements](#testing-requirements)
10. [Documentation Standards](#documentation-standards)
11. [Security & Data Protection](#security--data-protection)
12. [Performance & Optimization](#performance--optimization)
13. [File Management & Navigation](#file-management--navigation)
14. [Error Handling & Recovery](#error-handling--recovery)
15. [Dynamic Design & Overflow Prevention](#dynamic-design--overflow-prevention)
16. [Separation of Concerns & Logic Mapping](#separation-of-concerns--logic-mapping)

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

#### 05 — Mandatory Package Imports

Relative imports (e.g., `import '../../tokens/ds_colors.dart';`) are **prohibited** in this project for cross-directory imports. They lead to refactoring fragility and inconsistent import patterns.

- **Rule**: Always use package-absolute imports for any file within the `lib/` directory when importing from another directory.
- **Exception**: Relative imports are allowed only when importing files within the **same directory** or a **direct subdirectory** (e.g., `import 'widgets/my_widget.dart';` inside a feature screen), though package imports are still preferred.

```dart
// ❌ PROHIBITED
import '../../design_system/design_system.dart';
import '../../../core/config.dart';

// ✅ MANDATORY
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/core/config.dart';
```

#### 06 — Single Responsibility

- **Screen (`.dart`)**: UI layout, user interaction, connecting to Riverpod.
- **Provider (`.dart`)**: State management, business logic orchestration.
- **Repository/DAO (`.dart`)**: Data access, API calls, SQLite queries.
- **Model (`.dart`)**: Immutable data classes (use `freezed` or `equatable` where appropriate).

---

## Tooling & Code Health Checks

> 🔧 **Mandatory before every commit.** Running `flutter analyze` and `dart format` is not optional — it is a gate check. Zero warnings, zero errors, zero unformatted files. Ship clean or don't ship.

### 07 — Always Run `flutter analyze` Before Every Commit

`flutter analyze` runs the Dart static analyzer across the entire codebase. It catches type errors, deprecated API usage, lint violations, and dead code — **before they reach production.**

#### Non-Negotiables

- Run `flutter analyze` before **every commit** without exception.
- **Zero warnings policy**: the pipeline does not accept a codebase with outstanding analyzer warnings. Warnings today become crashes tomorrow.
- Do **not** suppress warnings with `// ignore:` unless you can write a full justification comment explaining why suppression is safe. Suppression is a last resort, not a shortcut.

### 08 — Always Run `dart format` — Zero Unformatted Files

Inconsistent formatting is noise in code reviews. `dart format` enforces the canonical Dart style guide automatically, keeping diffs clean and readable.

---

## Commenting Standards — Be a Rockstar Commenter

> 💬 **The Philosophy**: Comments are love letters to your future self and your teammates. Great comments don't explain **WHAT** the code does — the code does that. Great comments explain **WHY** it exists, **WHAT** decisions were made, and **WHAT** traps to avoid.

---

### 09 — DartDoc for Every Public API (`///` Triple-Slash)

Every public class, method, and property **MUST** have a triple-slash DartDoc comment. This is non-negotiable.

### 10 — Inline Comments: The WHY, Not the WHAT

> ⚠️ **Rule**: If your inline comment describes **WHAT** the code does, delete it. The code does that. Comments explain **WHY**.

### 11 — Section Dividers for Large Files

For files over 200 lines, divide logical sections with clearly labeled block comments. This lets any developer jump to the right section in seconds.

### 12 — TODO & FIXME: Track It or Kill It

> 🗂️ **Rule**: A TODO without a ticket number and owner is dead weight. Every TODO must be actionable and traceable.

### 13 — Business Logic Comments: Explain the Domain

When code implements a non-obvious business rule, write a comment that a new developer could hand to a product manager and have them confirm it is correct.

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

## 🌐 Localization & Translation Standards

> **Rule**: Every user-visible string in this app must go through `easy_localization`. No exceptions. Hardcoded text is treated the same as a hardcoded color — it is a design system violation.

---

### 14 — No Hardcoded Strings, Ever

This app supports **English (EN)** and **Filipino (FIL)** via the `easy_localization` package. All user-visible text must be stored in the translation JSON files and accessed through `.tr()`.

### 15 — Translation File Structure

Translation files live in:

```
assets/translations/
  ├── en.json    ← English (source of truth)
  └── fil.json   ← Filipino
```

### 16 — Workflow: Adding a New String

Follow this order **every time** a new string is introduced:

1. Add English string to assets/translations/en.json
2. Add Filipino translation to assets/translations/fil.json
3. Use the key in the widget via .tr()

### 17 — Currency & Date Formatting

**Currency: Philippine Peso (₱) only. This never changes regardless of language.**

All monetary values and dates must go through `AppFormatters` in `lib/shared/helpers/formatters.dart`. Never format currency or dates inline.

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

---

## Logging & Observability Standards

### 1. Appropriate Log Levels

Use a logging package (like `logger`) or custom debug wrappers.

---

## Testing Requirements

### Test-First Mindset

- Write unit tests for your data parsing and domain models.
- Write unit tests for local SQLite DAO logic.

---

## Documentation Standards

### Updating Docs

**ALWAYS update docs when**:

- Modifying offline sync behavior.
- Adding a new feature module.
- Changing API payload structures.

---

## Security & Data Protection

- **DO NOT** log passwords, raw auth tokens, or PII.
- Securely store API tokens using `flutter_secure_storage`.

---

## Performance & Optimization

### Widget Rebuilds

- Use `Consumer` localized to the exact widget tree that needs rebuilding.
- Use `select` in Riverpod to listen only to specific property changes.

---

## File Management & Navigation

- Keep feature modules small and well-scoped under `lib/features/{feature}`.
- Reuse shared widgets in `lib/shared/widgets/` and design-system tokens from `lib/design_system/`.

---

## Error Handling & Recovery

### API and Network

- Distinguish between `ApiNetworkError` (offline) and `ApiServerError` (500).

---

## Dynamic Design & Overflow Prevention

To ensure a premium feel across all device sizes, UI components must be **defensive** against data length and layout constraints.

### Goal: Zero `RenderFlex` Overflows

1. **Flexible Text**: **NEVER** place a `Text` widget inside a `Row` or `Column` without considering its potential length. Wrap in `Flexible` or `Expanded`.

---

## Separation of Concerns & Logic Mapping

To maintain a scalable codebase, we enforce a strict separation between **Definitions** (What), **Configurations** (How), and **Implementations** (Execution).

### 🏛️ The Three-Layer Rule

1. **Tokens & Definitions (The "What")**: `lib/design_system/tokens/`, `lib/core/constants.dart`.
2. **Configurations & Themes (The "How")**: `lib/design_system/ds_theme.dart`.
3. **Implementations & UI (The "Execution")**: `lib/features/`, `lib/shared/widgets/`.

---

**This is your source of truth for the Courier Mobile App. Consult it before every coding session.**

Last Updated: April 30, 2026
