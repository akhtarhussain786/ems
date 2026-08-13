import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../firebase_options.dart';
import 'api_service.dart';

// WhatsApp-Style High Importance Notification Channel
const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'This channel is used for important notifications.',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kDebugMode) {
    print("Handling background message: ${message.messageId}");
  }
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 1. Initialize Firebase Core
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // 2. Set background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 3. Setup Android Local Notification Channel & Plugin
      const AndroidInitializationSettings androidInitSettings =
          AndroidInitializationSettings('@drawable/ic_stat_notification');

      const InitializationSettings initSettings = InitializationSettings(
        android: androidInitSettings,
        iOS: DarwinInitializationSettings(),
      );

      await _localNotificationsPlugin.initialize(initSettings);

      await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // 4. Request Permissions & Enable Foreground Banners
      NotificationSettings settings =
          await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      if (kDebugMode) {
        print('User granted notification permission: ${settings.authorizationStatus}');
      }

      // 5. Get FCM Token & Sync with Backend
      await syncTokenWithBackend();

      // 6. Listen for Token Refreshes
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        if (kDebugMode) {
          print("FCM Token Refreshed: $newToken");
        }
        ApiService().updateFcmToken(newToken);
      });

      // 7. Handle Foreground Messages (Display WhatsApp-style Heads-Up Banner)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        if (notification != null) {
          _localNotificationsPlugin.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                _channel.id,
                _channel.name,
                channelDescription: _channel.description,
                icon: android?.smallIcon ?? '@drawable/ic_stat_notification',
                importance: Importance.max,
                priority: Priority.high,
                ticker: 'ticker',
                playSound: true,
                enableVibration: true,
                styleInformation: BigTextStyleInformation(
                  notification.body ?? '',
                  htmlFormatBigText: true,
                  contentTitle: notification.title,
                  htmlFormatContentTitle: true,
                ),
              ),
              iOS: const DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
          );
        }
      });

      // 8. Handle Message Tap (App Opened)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('Notification tapped: ${message.messageId}');
        }
      });

      _initialized = true;
    } catch (e) {
      if (kDebugMode) {
        print("FCM Initialization Error: $e");
      }
    }
  }

  Future<void> syncTokenWithBackend() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        if (kDebugMode) {
          print("FCM Token: $token");
        }
        await ApiService().updateFcmToken(token);
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error syncing FCM token: $e");
      }
    }
  }
}
