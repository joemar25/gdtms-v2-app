// DOCS: docs/development-standards.md
// DOCS: docs/core/services.md — update that file when you edit this one.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';

/// A5: feature service over raw `apiClientProvider` for the dispatch feature.
///
/// Used by the dispatch list/eligibility screens and the scan-to-dispatch
/// flow in `scan_screen.dart` (same two endpoints, same UX). Post-accept
/// bootstrap (`DeliveryBootstrapService.seedForDelivery`) and queue/refresh
/// side effects (`SyncWriteCoordinator.completeWrite`) stay in the calling
/// screens — this only wraps the raw HTTP + parsing.
class DispatchService {
  const DispatchService(this._api);

  final ApiClient _api;

  /// GET /pending-dispatches — dispatch list screen's paged feed.
  Future<ApiResult<Map<String, dynamic>>> getPendingDispatches({
    required int page,
    required int perPage,
  }) {
    return _api.get<Map<String, dynamic>>(
      '/pending-dispatches',
      queryParameters: {'page': page, 'per_page': perPage},
      parser: parseApiMap,
    );
  }

  /// POST /check-dispatch-eligibility — partial-code lookup before accept.
  Future<ApiResult<Map<String, dynamic>>> checkEligibility({
    required String partialCode,
    required String clientRequestId,
    required Map<String, dynamic> deviceInfo,
  }) {
    return _api.post<Map<String, dynamic>>(
      '/check-dispatch-eligibility',
      data: {
        'partial_code': partialCode,
        'client_request_id': clientRequestId,
        'device_info': deviceInfo,
      },
      parser: parseApiMap,
    );
  }

  /// POST /accept-dispatch.
  Future<ApiResult<Map<String, dynamic>>> acceptDispatch({
    required String dispatchCode,
    required String clientRequestId,
    required Map<String, dynamic> deviceInfo,
  }) {
    return _api.post<Map<String, dynamic>>(
      '/accept-dispatch',
      data: {
        'dispatch_code': dispatchCode,
        'client_request_id': clientRequestId,
        'device_info': deviceInfo,
      },
      parser: parseApiMap,
    );
  }

  /// POST /reject-dispatch.
  Future<ApiResult<Map<String, dynamic>>> rejectDispatch({
    required String dispatchCode,
    required String clientRequestId,
    required String reason,
    String? remarks,
    required Map<String, dynamic> deviceInfo,
  }) {
    return _api.post<Map<String, dynamic>>(
      '/reject-dispatch',
      data: {
        'dispatch_code': dispatchCode,
        'client_request_id': clientRequestId,
        'reason': reason,
        'remarks': remarks,
        'device_info': deviceInfo,
      },
      parser: parseApiMap,
    );
  }
}

final dispatchServiceProvider = Provider<DispatchService>((ref) {
  return DispatchService(ref.read(apiClientProvider));
});
