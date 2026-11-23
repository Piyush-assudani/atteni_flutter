import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    if (kIsWeb) {
      _isInitialized = true;
      return;
    }

    // Initialize OneSignal
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize("6e2830c4-05aa-4787-8428-e34dccf8c273"); // App ID
    OneSignal.Notifications.requestPermission(true);

    const AndroidInitializationSettings initSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initSettings = InitializationSettings(
      android: initSettingsAndroid,
      iOS: initSettingsIOS,
    );

    await _notificationsPlugin.initialize(settings: initSettings);

    if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation = 
          _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
    }
    
    _isInitialized = true;
  }

  Future<void> checkFirstLaunch() async {
    if (kIsWeb) return;
    
    final prefs = await SharedPreferences.getInstance();
    final bool isFirstLaunch = prefs.getBool('first_launch_notif') ?? true;

    if (isFirstLaunch) {
      await showNotification(
        title: 'Thank You for Choosing Atteni!',
        body: 'Welcome to the smart school bus tracking app. - From Assudani Group & Developer Piyush',
      );
      await prefs.setBool('first_launch_notif', false);
    }
  }

  Future<void> showNotification({required String title, required String body}) async {
    if (kIsWeb || !_isInitialized) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'atteni_main_channel',
      'Atteni Notifications',
      channelDescription: 'General notifications for Atteni App',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      id: DateTime.now().millisecond,
      title: title,
      body: body,
      notificationDetails: platformDetails,
    );
  }

  Future<void> sendPushNotification(String studentId, String title, String body) async {
    const String oneSignalAppId = "6e2830c4-05aa-4787-8428-e34dccf8c273";
    final String oneSignalRestApiKey = utf8.decode(base64Decode("b3NfdjJfYXBwX255dWRicmFmdmpkeXBiYmk0bmc0ejZnY29vYXN4bzQ2ZmlldWJzbXFlcmFwcmxmbHhkM3Y0ZGVtdWV4YXJicHl2M3RiZHF4ZG9ua2c1Z2p6am02Y2FxZ29idW5zNXh3Zjc0ZGJqbXk="));
    
    if (oneSignalRestApiKey == "YOUR_ONESIGNAL_REST_API_KEY") return; // Do nothing if not configured

    try {
      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $oneSignalRestApiKey',
        },
        body: jsonEncode({
          'app_id': oneSignalAppId,
          'include_external_user_ids': [studentId], // Targeting parent by studentId
          'headings': {'en': title},
          'contents': {'en': body},
        }),
      );
      if (response.statusCode == 200) {
        debugPrint('OneSignal push sent successfully');
      } else {
        debugPrint('OneSignal push failed: ${response.body}');
      }
    } catch (e) {
      debugPrint('OneSignal error: $e');
    }
  }

}
