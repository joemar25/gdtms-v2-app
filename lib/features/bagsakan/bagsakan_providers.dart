// DOCS: docs/development-standards.md
// DOCS: docs/features/bagsakan.md — update that file when you edit this one.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fsi_courier_app/core/database/database_providers.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';

/// Provider that fetches all bagsakan groups.
/// Watches [deliveryRefreshProvider] to re-fetch when a new group is created
/// or when delivery data changes.
final bagsakanGroupsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  ref.watch(deliveryRefreshProvider);
  return await ref.read(bagsakanDaoProvider).getBagsakanGroups();
});
