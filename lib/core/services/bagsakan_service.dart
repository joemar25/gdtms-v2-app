// DOCS: docs/development-standards.md
// DOCS: docs/core/services.md — update that file when you edit this one.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';

/// A5: feature service over raw `apiClientProvider` for the bagsakan feature.
///
/// Bagsakan writes (save/submit/remove/delete) already go through the
/// offline-first sync queue via `SyncWriteCoordinator` — this only wraps the
/// direct read calls the bagsakan UI makes (group detail refresh, eligible
/// delivery search). Pull-to-refresh calls into `DeliveryBootstrapService`
/// directly and stays that way — it's already a proper service, not raw
/// HTTP in a widget.
class BagsakanService {
  const BagsakanService(this._api);

  final ApiClient _api;

  /// GET /bagsakan/groups/{groupId} — full group detail with member
  /// deliveries, used to refresh a group screen when online.
  Future<ApiResult<Map<String, dynamic>>> getGroupDetail(int groupId) {
    return _api.get<Map<String, dynamic>>(
      '/bagsakan/groups/$groupId',
      parser: parseApiMap,
    );
  }

  /// GET /deliveries/search?eligible_for_bagsakan=1 — server-qualified
  /// search used when adding items to a group, so eligibility stays aligned
  /// with backend rules (v3.8: eligible_for_bagsakan flag) instead of the
  /// local-only heuristic.
  Future<ApiResult<Map<String, dynamic>>> searchEligibleDeliveries(
    String query, {
    int perPage = 50,
  }) {
    return _api.get<Map<String, dynamic>>(
      '/deliveries/search',
      queryParameters: {
        'q': query,
        'eligible_for_bagsakan': 1,
        'per_page': perPage,
      },
      parser: parseApiMap,
    );
  }
}

final bagsakanServiceProvider = Provider<BagsakanService>((ref) {
  return BagsakanService(ref.read(apiClientProvider));
});
