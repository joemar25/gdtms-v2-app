import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/api/api_result.dart';
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

  /// Called when the app starts up to request permissions and listen to messages.
  Future<void> init(ApiClient apiClient) async {
    _apiClient = apiClient;

    if (_initialized) return;

    // 1. Request Permission (mainly for iOS, but good practice)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('[PUSH] User granted permission');

      // 2. Setup Foreground notification channels (Android)
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

      // Initialize local notifications for foreground alerts
      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: DarwinInitializationSettings(),
          );
      await _localNotificationsPlugin.initialize(
        settings: initializationSettings,
      );

      // Listen to foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 3. Get token and sync initially
      try {
        final token = await _messaging.getToken();
        if (token != null) {
          await _syncTokenToApi(token);
        }
      } catch (e) {
        debugPrint('[PUSH] Failed to get FCM token: $e');
      }

      // 4. Listen to token refreshes
      _messaging.onTokenRefresh.listen((token) {
        _syncTokenToApi(token);
      });

      // 5. Handle notification tap when app was terminated (cold start).
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        // Delay navigation until after the first frame so the router is ready.
        Future.delayed(const Duration(milliseconds: 500), () {
          _navigateFromMessage(initialMessage.data);
        });
      }

      // 6. Handle notification tap when app is in the background (warm start).
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _navigateFromMessage(message.data);
      });

      _initialized = true;
    } else {
      debugPrint('[PUSH] User declined or has not accepted permission');
    }
  }

  void _navigateFromMessage(Map<String, dynamic> data) {
    final action = data['action'] as String?;
    if (action != 'view_delivery') return;

    final barcode = data['barcode'] as String?;
    if (barcode == null || barcode.isEmpty) return;

    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      debugPrint('[PUSH] Cannot navigate — no root context');
      return;
    }

    debugPrint('[PUSH] Navigating to delivery: $barcode');
    GoRouter.of(context).push('/deliveries/$barcode');
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
