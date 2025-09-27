// notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> setup() async {
    // ANDROID
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS + macOS use DarwinInitializationSettings
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // IMPORTANT: include macOS here, not just iOS
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(initSettings);
  }

  // simple test notification
  static Future<void> showTest() async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails('test', 'Test'),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );
    await _plugin.show(0, 'Hello', 'It worked on macOS!', details);
  }
}
