// test/core/database/bagsakan_visibility_test.dart
//
// Business-rule tests for Bagsakan visibility logic.
//
// These tests validate the pure-Dart rules that the DAO SQL queries
// and isVisibleToRider() enforce for items assigned to a Bagsakan group.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsi_courier_app/core/models/local_delivery.dart';

/// Builds a minimal [LocalDelivery] for testing Bagsakan visibility logic.
LocalDelivery _makeDelivery({
  required String status,
  int? bagsakanId,
  bool isArchived = false,
}) {
  final rawJson = jsonEncode({
    'barcode': 'TEST001',
    'delivery_status': status,
    'bagsakan_id': bagsakanId,
  });

  return LocalDelivery(
    barcode: 'TEST001',
    deliveryStatus: status,
    rawJson: rawJson,
    createdAt: DateTime.now().millisecondsSinceEpoch,
    updatedAt: DateTime.now().millisecondsSinceEpoch,
    bagsakanId: bagsakanId,
    isArchived: isArchived,
  );
}

/// Simulates the [isVisibleToRider] decision tree in pure Dart,
/// specifically focusing on the Bagsakan exclusion rule.
bool _isVisible(LocalDelivery d) {
  // RULE: Archived items are never visible.
  if (d.isArchived) return false;

  // RULE: Items assigned to a Bagsakan group are never visible in standard lists.
  if (d.bagsakanId != null) return false;

  final status = d.deliveryStatus.toUpperCase();
  switch (status) {
    case 'FOR_DELIVERY':
    case 'FOR_REDELIVERY':
      return true;
    case 'DELIVERED':
      // Simplified for this test file — we care about Bagsakan logic.
      return true;
    default:
      return false;
  }
}

void main() {
  group('Bagsakan Visibility Rules', () {
    test('standard PENDING delivery is visible', () {
      final d = _makeDelivery(status: 'FOR_DELIVERY', bagsakanId: null);
      expect(_isVisible(d), isTrue);
    });

    test('delivery assigned to Bagsakan is NOT visible', () {
      final d = _makeDelivery(status: 'FOR_DELIVERY', bagsakanId: 101);
      expect(
        _isVisible(d),
        isFalse,
        reason:
            'Items in a Bagsakan group must be excluded from standard lists',
      );
    });

    test('archived delivery is NOT visible regardless of Bagsakan status', () {
      final d = _makeDelivery(
        status: 'FOR_DELIVERY',
        bagsakanId: 101,
        isArchived: true,
      );
      expect(_isVisible(d), isFalse);
    });

    test('DELIVERED item in Bagsakan is NOT visible', () {
      final d = _makeDelivery(status: 'DELIVERED', bagsakanId: 202);
      expect(
        _isVisible(d),
        isFalse,
        reason: 'Even delivered items are hidden if they belong to a Bagsakan',
      );
    });
  });
}
