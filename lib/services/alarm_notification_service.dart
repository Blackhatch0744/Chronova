import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class AlarmNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(settings: settings);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'timepilot_alarm_channel_v2',
  'TimePilot Smart Alarms',
  description: 'Alarm alerts and task reminders for TimePilot AI',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<bool> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      return await androidPlugin.requestNotificationsPermission() ?? false;
    }

    return false;
  }

  static Future<void> scheduleAlarm({
    required int id,
    required DateTime scheduledTime,
    required String title,
    required String body,
  }) async {
    final tz.TZDateTime tzScheduledTime =
        tz.TZDateTime.from(scheduledTime, tz.local);

    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
  'timepilot_alarm_channel_v2',
  'TimePilot Smart Alarms',
      channelDescription: 'Alarm alerts and task reminders for TimePilot AI',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tzScheduledTime,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static Future<void> cancelAlarm(int id) async {
    await _notificationsPlugin.cancel(id: id);
  }

  static Future<void> rescheduleAlarm({
    required int id,
    required DateTime oldTime,
    required DateTime newTime,
  }) async {
    await cancelAlarm(id);

    await scheduleAlarm(
      id: id,
      scheduledTime: newTime,
      title: 'TimePilot Alarm',
      body: 'Your alarm has been rescheduled due to traffic changes.',
    );
  }

  static Future<void> scheduleTaskReminder({
  required int id,
  required DateTime scheduledTime,
  required String title,
  required String body,
}) async {
  final tz.TZDateTime tzScheduledTime =
      tz.TZDateTime.from(scheduledTime, tz.local);

  const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
  'timepilot_alarm_channel_v2',
  'TimePilot Smart Alarms',
  channelDescription: 'Alarm alerts and task reminders for TimePilot AI',
  importance: Importance.max,
  priority: Priority.max,
  playSound: true,
  enableVibration: true,
  fullScreenIntent: true,
  category: AndroidNotificationCategory.alarm,
  visibility: NotificationVisibility.public,
);

  const NotificationDetails details =
      NotificationDetails(android: androidDetails);

  await _notificationsPlugin.zonedSchedule(
    id: id,
    title: title,
    body: body,
    scheduledDate: tzScheduledTime,
    notificationDetails: details,
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  );
}

  static Future<void> cancelTaskReminder(int id) async {
    await _notificationsPlugin.cancel(id: id);
  }
static Future<void> showInstantTaskReminder({
  required int id,
  required String title,
  required String body,
}) async {
  const AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
    'timepilot_alarm_channel_v2',
    'TimePilot Smart Alarms',
    channelDescription: 'Alarm alerts and task reminders for TimePilot AI',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
  );

  const NotificationDetails details =
      NotificationDetails(android: androidDetails);

  await _notificationsPlugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: details,
  );
}
  static Future<void> showTestTaskReminder() async {
  await showInstantTaskReminder(
    id: 8887,
    title: 'TimePilot Test Reminder',
    body: 'Instant test reminder is working.',
  );

  final DateTime testTime = DateTime.now().add(const Duration(seconds: 10));

  await scheduleTaskReminder(
    id: 8888,
    scheduledTime: testTime,
    title: 'TimePilot Reminder',
    body: 'This is your scheduled planner reminder.',
  );
}

  static Future<void> showTestAlarm() async {
    final DateTime testTime = DateTime.now().add(const Duration(seconds: 5));

    await scheduleAlarm(
      id: 9999,
      scheduledTime: testTime,
      title: 'TimePilot Test Alarm',
      body: 'This is a test alarm to verify notification functionality.',
    );
  }
}