import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:localstorage/localstorage.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin
  _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // ignoring macOS and linux setup for now
  static Future<void> setup() async {
    tz.initializeTimeZones();
    const androidInitializationSetting = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosInitializationSetting = DarwinInitializationSettings();
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: androidInitializationSetting,
          iOS: iosInitializationSetting,
        );
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  static Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  static Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  void showLocalNotification(String title, String body) {
    const androidNotificationDetail = AndroidNotificationDetails(
      '0', // channel Id
      'general', // channel Name
    );
    const iosNotificatonDetail = DarwinNotificationDetails();
    const notificationDetails = NotificationDetails(
      iOS: iosNotificatonDetail,
      android: androidNotificationDetail,
    );
    _flutterLocalNotificationsPlugin.show(0, title, body, notificationDetails);
  }

  static Future<int?> scheduleNotification(
    DateTime selectedTime,
    String title,
    String body,
  ) async {
    // define notification details
    NotificationDetails notificationDetails = const NotificationDetails(
      android: AndroidNotificationDetails(
        'your_channel_id',
        'your_channel_name',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: false,
      ),
      iOS: DarwinNotificationDetails(),
    );

    // when to send notif
    if (selectedTime.isBefore(DateTime.now())) {
      return null;
    }
    int id = int.parse(localStorage.getItem('notification_id_counter') ?? '0');
    final tz.TZDateTime scheduledTime = tz.TZDateTime.from(
      selectedTime,
      tz.local,
    );
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      notificationDetails,
      matchDateTimeComponents: DateTimeComponents.time,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    localStorage.setItem('notification_id_counter', (id + 1).toString());
    return id;
  }
}
