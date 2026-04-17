import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/services/error_log_service.dart';
import 'package:fsi_courier_app/core/auth/auth_storage.dart';
import 'package:fsi_courier_app/shared/router/router_keys.dart';
import 'package:go_router/go_router.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  debugPrint("Handling a background message: ${message.messageId}");
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  ApiClient? _apiClient;
  final AuthStorage _authStorage = AuthStorage();

  /// Called in main.dart before runApp to register the background handler.
  static Future<void> initBackgroundHandler() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  /// Called on every app startup and every fresh login.
  /// Permission must already be granted via the permissions screen before
  /// this is called — we check current status only, never prompt here.
  ///
  /// The FCM token is **always** re-synced to the backend on every call so the
  /// server always has a valid token (Firebase can rotate it silently between
  /// sessions). Listener + channel setup is guarded by [_initialized] so those
  /// are registered only once per app lifetime.
  Future<void> init(ApiClient apiClient) async {
    _apiClient = apiClient;

    // Check current permission status without prompting the user.
    // The permissions screen (LocationRequiredScreen) is responsible for
    // requesting notification permission before the user reaches the dashboard.
    final settings = await _messaging.getNotificationSettings();

    // Attempt to flush any previously-persisted FCM token changes. This makes
    // the token sync robust across restarts or offline periods.
    await _attemptPendingTokenSync(settings);

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('[PUSH] User granted permission');

      // Always re-sync the FCM token on every init call (startup + login).
      // Attempt to get token even if the app hasn't been granted notification
      // permission yet — on many platforms (Android) a token is still available.
      try {
        final token = await _messaging.getToken();
        debugPrint('[PUSH] getToken() -> $token');
        final lastSynced = await _authStorage.getLastSyncedFcmToken();
        if (token != null && token.isNotEmpty && token != lastSynced) {
          await _syncTokenToApi(token);
        }
      } catch (e) {
        debugPrint('[PUSH] Failed to get FCM token: $e');
      }

      // Listeners + channel setup — register only once per app lifetime.
      if (_initialized) return;

      // Enable foreground notifications on iOS (alert + badge + sound).
      // Without this iOS silently ignores notifications while the app is open.
      if (!kIsWeb && Platform.isIOS) {
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      // Setup high-importance notification channel for Android foreground alerts.
      if (!kIsWeb && Platform.isAndroid) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'high_importance_channel',
          'High Importance Notifications',
          description: 'This channel is used for important notifications.',
          importance: Importance.max,
        );

        await _localNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(channel);
      }

      // Initialize local notifications for foreground alerts.
      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: DarwinInitializationSettings(),
          );
      await _localNotificationsPlugin.initialize(
        settings: initializationSettings,
      );

      // Listen to foreground messages.
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Re-sync whenever Firebase silently rotates the token.
      _messaging.onTokenRefresh.listen((token) {
        _syncTokenToApi(token);
      });

      // Handle notification tap when app was terminated (cold start).
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        // Delay navigation until after the first frame so the router is ready.
        Future.delayed(const Duration(milliseconds: 500), () {
          _navigateFromMessage(initialMessage.data);
        });
      }

      // Handle notification tap when app is in the background (warm start).
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _navigateFromMessage(message.data);
      });

      _initialized = true;
    } else {
      debugPrint('[PUSH] User declined or has not accepted permission');

      // Ensure backend does not retain a stale FCM token for this device when
      // the user has declined notifications. Schedule a clear of the backend
      // token (offline-safe) so the server doesn't retain an invalid token.
      try {
        await _syncTokenToApi(null);
      } catch (e) {
        debugPrint('[PUSH] Failed to schedule clearing FCM token: $e');
        await ErrorLogService.warning(
          context: 'PushNotificationService',
          message: 'Failed to schedule clearing FCM token',
          detail: e.toString(),
        );
      }
    }
  }

  void _navigateFromMessage(Map<String, dynamic> data) {
    final action = data['action'] as String?;
    if (action == null) return;

    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      debugPrint('[PUSH] Cannot navigate — no root context');
      return;
    }

    if (action == 'view_delivery') {
      final barcode = data['barcode'] as String?;
      if (barcode == null || barcode.isEmpty) return;
      debugPrint('[PUSH] Navigating to delivery: $barcode');
      GoRouter.of(context).push('/deliveries/$barcode');
    } else if (action == 'new_dispatch') {
      debugPrint('[PUSH] Navigating to dispatch list');
      GoRouter.of(context).push('/dispatches');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null && !kIsWeb) {
      _localNotificationsPlugin.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription:
                'This channel is used for important notifications.',
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    }
  }

  /// Called on logout. Deletes the Firebase token on-device so the stored
  /// backend token immediately becomes invalid, then clears it on the server.
  /// Resets [_initialized] so [init] fully re-registers on the next login.
  Future<void> clearToken() async {
    // 1. Delete the Firebase token — any attempt by the backend to send a push
    //    to the old token will be rejected by FCM even if the server clear fails.
    try {
      await _messaging.deleteToken();
      debugPrint('[PUSH] FCM token deleted from device');
    } catch (e) {
      debugPrint('[PUSH] Failed to delete FCM token: $e');
    }

    // 2. Clear the token on the backend so the server knows this device is gone.
    try {
      await _syncTokenToApi(null);
    } catch (e) {
      debugPrint('[PUSH] Failed to schedule backend clear for FCM token: $e');
    }

    // 3. Reset so init() fully re-registers listeners on next login.
    _initialized = false;
    _apiClient = null;
  }

  Future<void> _syncTokenToApi(String? token) async {
    // Persist desired state first so it survives restarts/offline.
    try {
      await _authStorage.setPendingFcmToken(token);
    } catch (e) {
      debugPrint('[PUSH] Failed to persist pending FCM token: $e');
    }

    if (_apiClient == null) {
      debugPrint('[PUSH] API client not ready; pending token saved');
      return;
    }

    debugPrint('[PUSH] Syncing FCM Token: ${token ?? 'null'}');

    // We assume the backend expects this payload.
    // POST /profile/fcm-token
    final deviceType = kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android');

    final result = await _apiClient!.post(
      '/profile/fcm-token',
      data: {'fcm_token': token, 'device_type': deviceType},
      parser: (data) => data, // ignore return value
    );

    final errorMessage = switch (result) {
      ApiSuccess() => null,
      ApiValidationError(:final message) => message ?? 'Validation error',
      ApiBadRequest(:final message) => message,
      ApiNetworkError(:final message) => message,
      ApiUnauthorized(:final message) => message ?? 'Unauthorized',
      ApiRateLimited(:final message) => message,
      ApiConflict(:final message) => message,
      ApiServerError(:final message) => message,
    };

    if (errorMessage != null) {
      // Log silently. If API is not up yet, it will fail but not crash the app.
      debugPrint('[PUSH] Failed to sync FCM Token: $errorMessage');
      await ErrorLogService.warning(
        context: 'PushNotificationService',
        message: 'Failed to sync FCM token',
        detail: errorMessage,
      );
      // Leave the pending token in storage so it can be retried later.
    } else {
      debugPrint('[PUSH] FCM Token synced successfully');
      try {
        await _authStorage.setLastSyncedFcmToken(token);
        await _authStorage.clearPendingFcmToken();
      } catch (e) {
        debugPrint('[PUSH] Failed to update local FCM sync state: $e');
      }
    }
  }

  Future<void> _attemptPendingTokenSync(NotificationSettings settings) async {
    try {
      final hasPending = await _authStorage.hasPendingFcmToken();
      if (!hasPending) return;
      final pending = await _authStorage.getPendingFcmToken();
      if (pending == null) {
        // Explicit clear requested.
        await _syncTokenToApi(null);
      } else {
        // If permissions are granted, try to send the token; otherwise clear server-side token.
        if (settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional) {
          await _syncTokenToApi(pending);
        } else {
          await _syncTokenToApi(null);
        }
      }
    } catch (e) {
      debugPrint('[PUSH] Failed to attempt pending FCM sync: $e');
    }
  }
}
