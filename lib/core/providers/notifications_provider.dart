// DOCS: docs/core/providers.md — update that file when you edit this one.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.message,
    this.transactionReference,
    this.deliveryReferences = const [],
    this.amount,
    this.stage,
    this.rejectionReason,
    this.dispatchCode,
    this.partialCode,
    this.deliveryCount,
    this.action,
    required this.date,
    required this.read,
    this.readAt,
  });

  final String id;
  final String type;
  final String message;
  final String? transactionReference;
  final List<String> deliveryReferences;
  final double? amount;

  /// Approval stage — e.g. "ops", "finance". Present on payout_approved/rejected.
  final String? stage;

  /// Rejection reason text. Present on payout_rejected.
  final String? rejectionReason;

  /// Full dispatch code. Present on new_dispatch.
  final String? dispatchCode;

  /// Partial (scan) code used to open the eligibility screen. Present on new_dispatch.
  final String? partialCode;

  /// Number of deliveries in a dispatch. Present on new_dispatch.
  final int? deliveryCount;

  /// Machine-readable action hint, e.g. "new_dispatch". May duplicate type.
  final String? action;
  final String date;
  final bool read;
  final String? readAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final refs = json['delivery_references'];
    return AppNotification(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      transactionReference: json['transaction_reference']?.toString(),
      deliveryReferences: refs is List
          ? refs.map((e) => e.toString()).toList()
          : const [],
      amount: json['amount'] != null
          ? double.tryParse('${json['amount']}')
          : null,
      stage: json['stage']?.toString(),
      rejectionReason: json['rejection_reason']?.toString(),
      dispatchCode: json['dispatch_code']?.toString(),
      partialCode: json['partial_code']?.toString(),
      deliveryCount: json['delivery_count'] != null
          ? int.tryParse('${json['delivery_count']}')
          : null,
      action: json['action']?.toString(),
      date: json['date']?.toString() ?? '',
      read: json['read'] as bool? ?? false,
      readAt: json['read_at']?.toString(),
    );
  }

  AppNotification copyWith({bool? read, String? readAt}) {
    return AppNotification(
      id: id,
      type: type,
      message: message,
      transactionReference: transactionReference,
      deliveryReferences: deliveryReferences,
      amount: amount,
      stage: stage,
      rejectionReason: rejectionReason,
      dispatchCode: dispatchCode,
      partialCode: partialCode,
      deliveryCount: deliveryCount,
      action: action,
      date: date,
      read: read ?? this.read,
      readAt: readAt ?? this.readAt,
    );
  }
}

// ─── State ────────────────────────────────────────────────────────────────────

class NotificationsState {
  const NotificationsState({
    this.entries = const [],
    this.unreadCount = 0,
    this.loading = false,
    this.loadingMore = false,
    this.currentPage = 0,
    this.lastPage = 1,
  });

  final List<AppNotification> entries;
  final int unreadCount;
  final bool loading;
  final bool loadingMore;
  final int currentPage;
  final int lastPage;

  bool get hasMore => currentPage < lastPage;

  NotificationsState copyWith({
    List<AppNotification>? entries,
    int? unreadCount,
    bool? loading,
    bool? loadingMore,
    int? currentPage,
    int? lastPage,
  }) {
    return NotificationsState(
      entries: entries ?? this.entries,
      unreadCount: unreadCount ?? this.unreadCount,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class NotificationsNotifier extends Notifier<NotificationsState> {
  bool _disposed = false;

  static const _unreadCountKey = 'offline_unread_count';

  ApiClient get _api => ref.read(apiClientProvider);

  @override
  NotificationsState build() {
    ref.onDispose(() => _disposed = true);
    _initOfflineCount();
    return const NotificationsState();
  }

  Future<void> _initOfflineCount() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedCount = prefs.getInt(_unreadCountKey);
    if (cachedCount != null && state.unreadCount == 0 && !_disposed) {
      state = state.copyWith(unreadCount: cachedCount);
    }
  }

  Future<void> _saveOfflineCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_unreadCountKey, count);
  }

  /// Loads page 1 and replaces the current list.
  Future<void> load() async {
    state = state.copyWith(loading: true);

    final result = await _api.get<Map<String, dynamic>>(
      '/notifications',
      queryParameters: {'page': 1, 'per_page': 10},
      parser: parseApiMap,
    );

    if (_disposed) return;

    if (result case ApiSuccess<Map<String, dynamic>>(:final data)) {
      final rawList = data['data'];
      final entries = rawList is List
          ? rawList
                .whereType<Map<String, dynamic>>()
                .map(AppNotification.fromJson)
                .toList()
          : <AppNotification>[];
      final meta = asStringDynamicMap(data['meta']);
      final lastPage = (meta['last_page'] as num?)?.toInt() ?? 1;
      final unreadCount =
          (data['unread_count'] as num?)?.toInt() ?? state.unreadCount;

      state = state.copyWith(
        entries: entries,
        unreadCount: unreadCount,
        loading: false,
        currentPage: 1,
        lastPage: lastPage,
      );
      _saveOfflineCount(unreadCount);
    } else {
      state = state.copyWith(loading: false);
    }
  }

  /// Appends the next page to the existing list.
  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore) return;
    state = state.copyWith(loadingMore: true);

    final nextPage = state.currentPage + 1;
    final result = await _api.get<Map<String, dynamic>>(
      '/notifications',
      queryParameters: {'page': nextPage, 'per_page': 10},
      parser: parseApiMap,
    );

    if (_disposed) return;

    if (result case ApiSuccess<Map<String, dynamic>>(:final data)) {
      final rawList = data['data'];
      final more = rawList is List
          ? rawList
                .whereType<Map<String, dynamic>>()
                .map(AppNotification.fromJson)
                .toList()
          : <AppNotification>[];
      final meta = asStringDynamicMap(data['meta']);
      final lastPage = (meta['last_page'] as num?)?.toInt() ?? state.lastPage;

      state = state.copyWith(
        entries: [...state.entries, ...more],
        loadingMore: false,
        currentPage: nextPage,
        lastPage: lastPage,
      );
    } else {
      state = state.copyWith(loadingMore: false);
    }
  }

  /// Fetches only the unread count — lightweight call for badge display.
  Future<void> loadUnreadCount() async {
    final result = await _api.get<Map<String, dynamic>>(
      '/notifications/unread-count',
      parser: parseApiMap,
    );
    if (_disposed) return;
    if (result case ApiSuccess<Map<String, dynamic>>(:final data)) {
      final count = (data['count'] as num?)?.toInt() ?? state.unreadCount;
      state = state.copyWith(unreadCount: count);
      _saveOfflineCount(count);
    }
  }

  /// Marks a single notification as read locally and persists to the server.
  Future<void> markAsRead(String id) async {
    // Optimistic local update.
    final updated = state.entries.map((n) {
      return n.id == id
          ? n.copyWith(read: true, readAt: DateTime.now().toIso8601String())
          : n;
    }).toList();
    final wasUnread = state.entries.any((n) => n.id == id && !n.read);
    final newCount = wasUnread
        ? (state.unreadCount - 1).clamp(0, double.maxFinite.toInt())
        : state.unreadCount;

    state = state.copyWith(entries: updated, unreadCount: newCount);

    _saveOfflineCount(newCount);

    await _api.post<Map<String, dynamic>>(
      '/notifications/$id/mark-as-read',
      parser: parseApiMap,
    );
  }

  /// Marks all notifications as read locally and persists to the server.
  Future<void> markAllAsRead() async {
    final updated = state.entries
        .map(
          (n) =>
              n.copyWith(read: true, readAt: DateTime.now().toIso8601String()),
        )
        .toList();
    state = state.copyWith(entries: updated, unreadCount: 0);
    _saveOfflineCount(0);

    await _api.post<Map<String, dynamic>>(
      '/notifications/mark-all-as-read',
      parser: parseApiMap,
    );
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, NotificationsState>(
      NotificationsNotifier.new,
    );

/// Derived provider — exposes only the unread count for badge display.
/// Components that only need the badge watch this instead of the full state.
final notificationsUnreadCountProvider = Provider<int>(
  (ref) => ref.watch(notificationsProvider).unreadCount,
);
