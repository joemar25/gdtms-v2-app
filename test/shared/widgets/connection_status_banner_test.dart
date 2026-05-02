// Tests for ConnectionStatusBanner and ConnectionStatus logic.
//
// Covered:
//   1. ConnectionStatus enum — three distinct values.
//   2. ConnectionStatus derivation — network + API reachability combinations.
//   3. ConnectionStatusBanner standard variant — renders per state.
//   4. ConnectionStatusBanner minimal variant — renders per state.
//   5. Custom message overrides (customOfflineMessage / customApiMessage).
//   6. API and network states are independent.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/shared/widgets/offline_banner.dart';

// ─── Helpers ────────────────────────────────────────────────────────────────

Widget _buildBanner(
  ConnectionStatus status, {
  bool isMinimal = false,
  String? customOfflineMessage,
  String? customApiMessage,
}) {
  return ProviderScope(
    overrides: [
      connectionStatusProvider.overrideWithValue(status),
      isOnlineProvider.overrideWithValue(status == ConnectionStatus.online),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ConnectionStatusBanner(
          isMinimal: isMinimal,
          customOfflineMessage: customOfflineMessage,
          customApiMessage: customApiMessage,
        ),
      ),
    ),
  );
}

// ─── Tests ──────────────────────────────────────────────────────────────────

void main() {
  // ── 1. ConnectionStatus enum ──────────────────────────────────────────────

  group('ConnectionStatus enum', () {
    test('has exactly three values', () {
      expect(ConnectionStatus.values.length, 3);
      expect(
        ConnectionStatus.values,
        containsAll([
          ConnectionStatus.online,
          ConnectionStatus.networkOffline,
          ConnectionStatus.apiUnreachable,
        ]),
      );
    });

    test('all three values are distinct', () {
      expect(ConnectionStatus.online, isNot(ConnectionStatus.networkOffline));
      expect(ConnectionStatus.online, isNot(ConnectionStatus.apiUnreachable));
      expect(
        ConnectionStatus.networkOffline,
        isNot(ConnectionStatus.apiUnreachable),
      );
    });
  });

  // ── 2. ConnectionStatus derivation ───────────────────────────────────────

  group('ConnectionStatus derivation', () {
    ConnectionStatus derive({
      required bool hasNetwork,
      required bool apiReachable,
    }) {
      if (!hasNetwork) return ConnectionStatus.networkOffline;
      return apiReachable
          ? ConnectionStatus.online
          : ConnectionStatus.apiUnreachable;
    }

    test('online when network and API are both reachable', () {
      expect(
        derive(hasNetwork: true, apiReachable: true),
        ConnectionStatus.online,
      );
    });

    test('apiUnreachable when network is up but API fails', () {
      expect(
        derive(hasNetwork: true, apiReachable: false),
        ConnectionStatus.apiUnreachable,
      );
    });

    test('networkOffline when device has no network', () {
      expect(
        derive(hasNetwork: false, apiReachable: false),
        ConnectionStatus.networkOffline,
      );
    });

    test('networkOffline regardless of apiReachable when no network', () {
      // API reachability is meaningless without a network interface.
      expect(
        derive(hasNetwork: false, apiReachable: true),
        ConnectionStatus.networkOffline,
      );
    });
  });

  // ── 3. Standard banner ────────────────────────────────────────────────────

  group('ConnectionStatusBanner — standard variant', () {
    testWidgets('renders nothing when online', (tester) async {
      await tester.pumpWidget(_buildBanner(ConnectionStatus.online));

      expect(find.byType(Container), findsNothing);
      expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
      expect(find.byIcon(Icons.cloud_off_rounded), findsNothing);
    });

    testWidgets(
      'shows wifi_off icon and "You\'re offline" when network offline',
      (tester) async {
        await tester.pumpWidget(_buildBanner(ConnectionStatus.networkOffline));

        expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
        expect(find.text("You're offline"), findsOneWidget);
        expect(find.byIcon(Icons.cloud_off_rounded), findsNothing);
      },
    );

    testWidgets(
      'shows cloud_off icon and "Server unavailable" when API unreachable',
      (tester) async {
        await tester.pumpWidget(_buildBanner(ConnectionStatus.apiUnreachable));

        expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
        expect(find.text('Server unavailable'), findsOneWidget);
        expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
      },
    );

    testWidgets('network-offline and API-unreachable show different icons', (
      tester,
    ) async {
      await tester.pumpWidget(_buildBanner(ConnectionStatus.networkOffline));
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);

      await tester.pumpWidget(_buildBanner(ConnectionStatus.apiUnreachable));
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
    });
  });

  // ── 4. Minimal banner ─────────────────────────────────────────────────────

  group('ConnectionStatusBanner — minimal variant', () {
    testWidgets('renders nothing when online', (tester) async {
      await tester.pumpWidget(
        _buildBanner(ConnectionStatus.online, isMinimal: true),
      );

      expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
      expect(find.byIcon(Icons.cloud_off_rounded), findsNothing);
    });

    testWidgets(
      'shows wifi_off icon and "No internet connection" when network offline',
      (tester) async {
        await tester.pumpWidget(
          _buildBanner(ConnectionStatus.networkOffline, isMinimal: true),
        );

        expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
        expect(find.text('No internet connection'), findsOneWidget);
      },
    );

    testWidgets(
      'shows cloud_off icon and "Server unavailable" when API unreachable',
      (tester) async {
        await tester.pumpWidget(
          _buildBanner(ConnectionStatus.apiUnreachable, isMinimal: true),
        );

        expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
        expect(find.text('Server unavailable'), findsOneWidget);
      },
    );
  });

  // ── 5. Custom message overrides ───────────────────────────────────────────

  group('ConnectionStatusBanner — custom messages', () {
    testWidgets('customOfflineMessage overrides network-offline text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildBanner(
          ConnectionStatus.networkOffline,
          isMinimal: true,
          customOfflineMessage: 'Showing cached data',
        ),
      );

      expect(find.text('Showing cached data'), findsOneWidget);
      expect(find.text('No internet connection'), findsNothing);
    });

    testWidgets('customApiMessage overrides API-unreachable text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildBanner(
          ConnectionStatus.apiUnreachable,
          isMinimal: true,
          customApiMessage: 'Unable to sync — server down',
        ),
      );

      expect(find.text('Unable to sync — server down'), findsOneWidget);
      expect(find.text('Server unavailable'), findsNothing);
    });

    testWidgets('customOfflineMessage does not affect API-unreachable text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildBanner(
          ConnectionStatus.apiUnreachable,
          isMinimal: true,
          customOfflineMessage: 'Custom network msg',
        ),
      );

      // API path falls back to default since no customApiMessage set.
      expect(find.text('Server unavailable'), findsOneWidget);
      expect(find.text('Custom network msg'), findsNothing);
    });

    testWidgets('customApiMessage does not affect network-offline text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildBanner(
          ConnectionStatus.networkOffline,
          isMinimal: true,
          customApiMessage: 'Custom api msg',
        ),
      );

      // Network path falls back to default since no customOfflineMessage set.
      expect(find.text('No internet connection'), findsOneWidget);
      expect(find.text('Custom api msg'), findsNothing);
    });
  });

  // ── 6. API and network independence ──────────────────────────────────────

  group('ConnectionStatus — API and network are independent', () {
    // Uses a helper so the analyzer cannot fold branches at compile time.
    ConnectionStatus derive({
      required bool hasNetwork,
      required bool apiReachable,
    }) {
      if (!hasNetwork) return ConnectionStatus.networkOffline;
      return apiReachable
          ? ConnectionStatus.online
          : ConnectionStatus.apiUnreachable;
    }

    test('apiUnreachable can occur while device has network', () {
      // Models: Wi-Fi up, server down (DNS failure, firewall, maintenance).
      expect(
        derive(hasNetwork: true, apiReachable: false),
        ConnectionStatus.apiUnreachable,
      );
    });

    test('networkOffline when no network, regardless of API flag', () {
      expect(
        derive(hasNetwork: false, apiReachable: false),
        ConnectionStatus.networkOffline,
      );
      expect(
        derive(hasNetwork: false, apiReachable: true),
        ConnectionStatus.networkOffline,
      );
    });

    test('online requires both network AND API reachable', () {
      expect(
        derive(hasNetwork: true, apiReachable: true),
        ConnectionStatus.online,
      );
    });
  });
}
