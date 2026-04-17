import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/services/error_log_service.dart';
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

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('[PUSH] User granted permission');

      // Always re-sync the FCM token on every init call (startup + login).
      // Firebase may silently rotate the token between sessions; the backend
      // must always hold the latest token to be able to reach this device —
      // even when the app is backgrounded or terminated.
      try {
        final token = await _messaging.getToken();
        if (token != null) {
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
      // the user has declined notifications. Inform the server on login so it
      // won't attempt to send pushes to a token that isn't present on-device.
      try {
        if (_apiClient != null) {
          final deviceType = kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android');
          await _apiClient!.post(
            '/profile/fcm-token',
            data: {'fcm_token': null, 'device_type': deviceType},
            parser: (data) => data,
          );
          debugPrint('[PUSH] Backend notified: notifications disabled for device');
        }
      } catch (e) {
        debugPrint('[PUSH] Failed to notify backend about disabled notifications: $e');
        await ErrorLogService.warning(
          context: 'PushNotificationService',
          message: 'Failed to notify backend when notifications disabled',
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
    if (_apiClient != null) {
      final deviceType = kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android');
      await _apiClient!.post(
        '/profile/fcm-token',
        data: {'fcm_token': null, 'device_type': deviceType},
        parser: (data) => data,
      );
      debugPrint('[PUSH] FCM token cleared on backend');
    }

    // 3. Reset so init() fully re-registers listeners on next login.
    _initialized = false;
    _apiClient = null;
  }

  Future<void> _syncTokenToApi(String token) async {
    if (_apiClient == null) return;

    debugPrint('[PUSH] Syncing FCM Token: $token');

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
    } else {
      debugPrint('[PUSH] FCM Token synced successfully');
    }
  }
}
