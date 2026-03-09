import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/api/api_result.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';

/// Fetches the courier's current delivery list from the server and seeds the
/// local SQLite database so the app has data to display while offline.
///
/// This is a **best-effort, fire-and-forget** operation. All errors are
/// silently swallowed; any partial data that was written before an error
/// remains in the database.
///
/// Call [syncFromApi] once on app startup (when online) and again each time
/// the device transitions from offline → online.
class DeliveryBootstrapService {
  const DeliveryBootstrapService._();

  static const DeliveryBootstrapService instance = DeliveryBootstrapService._();

  static const List<String> _statuses = [
    'pending',
    'rts',
    'osa',
    'delivered',
  ];

  /// Fetches all deliveries for each status from `GET /deliveries` (paginated)
  /// and upserts them into [LocalDeliveryDao].
  Future<void> syncFromApi(ApiClient client) async {
    for (final status in _statuses) {
      await _syncStatus(client, status);
    }
  }

  Future<void> _syncStatus(ApiClient client, String status) async {
    int page = 1;
    int lastPage = 1;

    do {
      try {
        final result = await client.get<Map<String, dynamic>>(
          '/deliveries',
          queryParameters: {
            'status': status,
            'per_page': 50,
            'page': page,
          },
          parser: parseApiMap,
        );

        if (result is! ApiSuccess<Map<String, dynamic>>) break;

        final data = result.data;

        // Extract the items list — the API wraps it under 'data'.
        final rawList = data['data'];
        final List<Map<String, dynamic>> items;
        if (rawList is List) {
          items = rawList
              .whereType<Map<String, dynamic>>()
              .toList();
        } else {
          break;
        }

        if (items.isNotEmpty) {
          await LocalDeliveryDao.instance.insertAllFromApiItems(items);
        }

        // Parse pagination meta to know if there are more pages.
        final meta = data['meta'];
        if (meta is Map<String, dynamic>) {
          lastPage = (meta['last_page'] as num?)?.toInt() ?? 1;
        } else {
          // No meta present — treat as single-page response.
          break;
        }

        page++;
      } catch (_) {
        // Silently ignore errors — bootstrap is best-effort.
        break;
      }
    } while (page <= lastPage);
  }
}
