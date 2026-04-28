import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FullScreenAlertService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    await _notifications.initialize(
      const InitializationSettings(android: androidSettings),
    );
  }

  static Future<void> showFullScreenAlert() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'sos_channel',
      'SOS Alerts',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true, // <--- THE MAGIC LINE
      category: AndroidNotificationCategory.alarm,
      playSound: false, // We handle audio ourselves
    );

    await _notifications.show(
      999,
      'Emergency Alert',
      'Tap to open safety screen',
      const NotificationDetails(android: androidDetails),
    );
  }
}