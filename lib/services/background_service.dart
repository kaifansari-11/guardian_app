import 'dart:async';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';

// CRITICAL: Import this to wake the screen
import 'fullscreen_alert_service.dart';

// --- 1. INITIALIZE THE SERVICE ---
Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'guardian_channel',
    'Guardian Safety Service',
    description: 'This channel shows the safety service status',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: false,
      notificationChannelId: 'guardian_channel',
      initialNotificationTitle: 'Guardian Protection',
      initialNotificationContent: 'System is Active',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(autoStart: false, onForeground: onStart),
  );
}

// --- 2. THE BACKGROUND TASK ---
@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  // Ensure the engine is ready for background work
  DartPluginRegistrant.ensureInitialized();

  StreamSubscription? shakeSubscription;

  // IMPORTANT: Do NOT use FlutterBackgroundService() here.
  // Only use the 'service' instance passed into this function.
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  // --- STOP LOGIC ---
  service.on('stopService').listen((event) {
    shakeSubscription?.cancel();
    service.stopSelf();
  });

  // --- HEARTBEAT SYNC ---
  // Tells the UI the service is alive to prevent flicker
  Timer.periodic(const Duration(seconds: 2), (timer) {
    service.invoke('service_status', {"isRunning": true});
  });

  DateTime? shakeStartTime;
  DateTime? lastShakeTime;

  // Listen to accelerometer events
  shakeSubscription = accelerometerEventStream().listen((
    AccelerometerEvent event,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    // reload() is critical to see changes made in the UI Screen
    await prefs.reload();

    bool isShakeFeatureEnabled = prefs.getBool('shake_feature_enabled') ?? true;
    if (!isShakeFeatureEnabled) return;

    double acceleration = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    if (acceleration > 15.0) {
      DateTime now = DateTime.now();
      double requiredDuration = prefs.getDouble('shake_duration') ?? 3.0;

      if (shakeStartTime == null ||
          (lastShakeTime != null &&
              now.difference(lastShakeTime!).inMilliseconds > 500)) {
        shakeStartTime = now;
      }

      lastShakeTime = now;

      if (now.difference(shakeStartTime!).inMilliseconds >
          (requiredDuration * 1000)) {
        shakeStartTime = null;

        // 1. Update State for UI recovery
        await prefs.setBool('is_sos_active', true);
        await prefs.setBool('sms_sent_by_background', true);

        // 2. Wake Up UI (Using the service that bypasses isolate issues)
        await FullScreenAlertService.showFullScreenAlert();

        // 3. Inform the UI Isolate
        service.invoke('shake_detected');

        // 4. Send the SMS from background
        _sendSOS();
      }
    }
  });
}

// --- 3. THE SENDING LOGIC ---
Future<void> _sendSOS() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    List<String>? phones = prefs.getStringList('contact_phones');
    String? uid = prefs.getString('user_uid');

    if (phones == null || phones.isEmpty) return;

    String baseUrl = "https://guardian-live.netlify.app";
    String dashboardLink = (uid != null) ? "$baseUrl/?uid=$uid" : baseUrl;
    String message = "HELP! I am in danger! Track me LIVE here: $dashboardLink";

    final Telephony telephony = Telephony.instance;

    for (String phone in phones) {
      String cleanPhone = phone.trim().replaceAll(" ", "");
      try {
        await telephony.sendSms(
          to: cleanPhone,
          message: message,
          isMultipart: false,
        );
      } catch (e) {
        debugPrint("Background SMS Error: $e");
      }
    }
  } catch (e) {
    debugPrint("Background SOS logic error: $e");
  }
}
