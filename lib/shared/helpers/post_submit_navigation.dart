// DOCS: docs/development-standards.md
// DOCS: docs/architecture/coupling-todo.md

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// A7: named wrapper for the "return to dashboard after a successful write"
/// navigation used by login, delivery submit, dispatch accept/reject, and
/// scan-to-dispatch — instead of a bare `context.go('/dashboard')` literal
/// repeated at each call site. One place to change if a feature ever needs
/// a different post-submit destination (stay on screen, pop, go to a status
/// list); until a call site actually needs that, this only does what today's
/// behavior already does.
void goToDashboardAfterSubmit(BuildContext context) => context.go('/dashboard');
