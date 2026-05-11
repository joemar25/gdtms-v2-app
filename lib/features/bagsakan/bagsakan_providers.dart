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

/// Keeps track of local-to-server ID remappings during a sync session.
/// This prevents UI flicker or 'not found' errors when a group is remapped
/// while its details screen is open.
class BagsakanIdRemapNotifier extends Notifier<Map<int, int>> {
  @override
  Map<int, int> build() => {};

  void updateRemap(int localId, int serverId) {
    state = {...state, localId: serverId};
  }
}

final bagsakanIdRemapProvider =
    NotifierProvider<BagsakanIdRemapNotifier, Map<int, int>>(
      BagsakanIdRemapNotifier.new,
    );
