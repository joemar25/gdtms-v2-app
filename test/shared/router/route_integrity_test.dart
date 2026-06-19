// Regression guard for "GoException: no routes for location: /xxx".
//
// This test statically scans every `context.push('/...')` / `context.go('/...')`
// (and pushReplacement / replace, plus GoRouter.of(context).push) literal used
// anywhere under lib/, and asserts each target resolves to a route registered in
// `lib/shared/router/app_router.dart`. Path parameters (`:param`) match any
// non-empty segment; query strings are ignored.
//
// It exists because the dashboard "Misrouted" card once pushed `/osa`, a route
// that no longer existed after the OSA → MISROUTED refactor, producing a
// "Page Not Found" screen at runtime. A source-level check catches this class of
// bug for ALL pages without needing to build the provider graph or platform
// channels.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Resolve the project root regardless of the cwd the test runner uses.
  Directory projectRoot() {
    var dir = Directory.current;
    while (!File('${dir.path}/pubspec.yaml').existsSync()) {
      final parent = dir.parent;
      if (parent.path == dir.path) {
        fail(
          'Could not locate project root (pubspec.yaml) from ${Directory.current.path}',
        );
      }
      dir = parent;
    }
    return dir;
  }

  final root = projectRoot();
  final libDir = Directory('${root.path}/lib');
  final routerFile = File('${root.path}/lib/shared/router/app_router.dart');

  // ── Build the set of registered route patterns ───────────────────────────────
  //
  // Extracts every `path: '...'` from the router file. Relative child paths
  // (those not starting with '/') are joined to the nearest preceding absolute
  // parent path, reconstructing full patterns like `/bagsakan/edit/:groupId`.
  List<String> registeredRoutePatterns() {
    final src = routerFile.readAsStringSync();
    final pathRe = RegExp(r"""path:\s*'([^']+)'""");
    final patterns = <String>[];
    String? lastAbsolute;
    for (final m in pathRe.allMatches(src)) {
      final p = m.group(1)!;
      if (p.startsWith('/')) {
        lastAbsolute = p;
        patterns.add(p);
      } else {
        // Relative child — join to the nearest absolute parent.
        final parent = lastAbsolute ?? '';
        final joined = '$parent/$p';
        patterns.add(joined);
      }
    }
    return patterns;
  }

  // A target path matches a registered pattern when they have the same number of
  // segments and each pattern segment is either a literal match or a `:param`.
  bool matchesPattern(String target, String pattern) {
    final t = target.split('/').where((s) => s.isNotEmpty).toList();
    final p = pattern.split('/').where((s) => s.isNotEmpty).toList();
    if (t.length != p.length) return false;
    for (var i = 0; i < p.length; i++) {
      final seg = p[i];
      // A `:param` segment matches any non-empty segment.
      if (seg.startsWith(':')) continue;
      if (seg != t[i]) return false;
    }
    return true;
  }

  // ── Collect every literal navigation target used under lib/ ──────────────────
  //
  // Matches: .push('/x'), .go('/x'), .pushReplacement('/x'), .replace('/x'),
  // including string interpolation like '/wallet/$ref' and query strings.
  List<({String path, String location})> navigationTargets() {
    final navRe = RegExp(
      r"""\.(?:push|go|pushReplacement|replace)\(\s*(['"])(/[^'"]*)\1""",
    );
    final targets = <({String path, String location})>[];
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final m in navRe.allMatches(lines[i])) {
          var raw = m.group(2)!;
          // Strip query string and fragment.
          raw = raw.split('?').first.split('#').first;
          // Replace interpolation segments ($x or ${x}) with a placeholder so
          // they behave like a concrete path parameter value during matching.
          final normalized = raw.replaceAll(
            RegExp(r'\$\{[^}]*\}|\$[A-Za-z0-9_.]+'),
            'X',
          );
          targets.add((
            path: normalized,
            location:
                '${entity.path.replaceFirst(root.path, '').replaceAll(r'\\', '/')}:${i + 1}',
          ));
        }
      }
    }
    return targets;
  }

  test('every navigation target resolves to a registered route', () {
    final patterns = registeredRoutePatterns();
    expect(
      patterns,
      isNotEmpty,
      reason: 'No routes parsed from app_router.dart',
    );

    final targets = navigationTargets();
    expect(targets, isNotEmpty, reason: 'No navigation calls found under lib/');

    final unresolved = <String>[];
    for (final t in targets) {
      final ok = patterns.any((p) => matchesPattern(t.path, p));
      if (!ok) unresolved.add('${t.path}  (at ${t.location})');
    }

    expect(
      unresolved,
      isEmpty,
      reason:
          'These navigation targets have no matching GoRoute — they will throw '
          '"GoException: no routes for location" at runtime:\n  ${unresolved.join('\n  ')}',
    );
  });

  // ── Availability of ALL pages ────────────────────────────────────────────────
  //
  // The complete inventory of pages the app ships. If a route/page is removed or
  // renamed, this list must be updated deliberately — the test fails otherwise,
  // forcing a conscious decision instead of a silent broken page.
  const expectedRoutes = <String>[
    '/splash',
    '/initial-sync',
    '/permissions-required',
    '/login',
    '/reset-password',
    '/update',
    '/change-password',
    '/dashboard',
    '/bagsakan',
    '/bagsakan/create',
    '/bagsakan/edit/:groupId',
    '/bagsakan/group/:groupId',
    '/wallet',
    '/profile',
    '/scan',
    '/dispatches',
    '/dispatches/eligibility',
    '/deliveries',
    '/deliveries/:barcode/update',
    '/delivered',
    '/failed-deliveries',
    '/misrouted',
    '/sync',
    '/notifications',
    '/wallet/request',
    '/wallet/:reference',
    '/profile/edit',
    '/error-logs',
    '/terms',
    '/privacy',
    '/user-guide',
    '/report',
  ];

  test('all expected page routes are registered in the router', () {
    final patterns = registeredRoutePatterns().toSet();
    final missing = expectedRoutes.where((r) => !patterns.contains(r)).toList();
    expect(
      missing,
      isEmpty,
      reason:
          'These pages are expected to exist but are not registered in '
          'app_router.dart (a page is missing/renamed):\n  ${missing.join('\n  ')}',
    );
  });

  test(
    'every registered route is reachable — no page shadowed by an earlier route',
    () {
      final patterns = registeredRoutePatterns();
      // GoRouter matches routes in registration order. A *literal* route that comes
      // after a parameterized route covering the same shape can never be reached
      // (e.g. `/wallet/request` placed after `/wallet/:reference`). Verify that each
      // literal route is the first pattern to match its own concrete path.
      final shadowed = <String>[];
      for (var i = 0; i < patterns.length; i++) {
        final p = patterns[i];
        // Only literal routes can be silently swallowed by an earlier param route.
        if (p.contains(':')) continue;
        final firstMatch = patterns.indexWhere((q) => matchesPattern(p, q));
        if (firstMatch != i) {
          shadowed.add(
            '"$p" is shadowed by earlier route "${patterns[firstMatch]}"',
          );
        }
      }
      expect(
        shadowed,
        isEmpty,
        reason:
            'Unreachable pages — these routes can never be matched:\n  ${shadowed.join('\n  ')}',
      );
    },
  );

  test('the removed /osa route is not referenced anywhere', () {
    final offenders = <String>[];
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (RegExp(r"""['"]/osa(?:['"/?])""").hasMatch(lines[i])) {
          offenders.add('${entity.path}:${i + 1}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'OSA was removed (now MISROUTED). Found stale /osa references:\n  ${offenders.join('\n  ')}',
    );
  });
}
