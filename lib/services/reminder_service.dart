// lib/services/reminder_service.dart

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:io';
import 'dart:typed_data';

class ReminderService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // ✅ Sound file name WITHOUT extension
  // Must match the file you placed in android/app/src/main/res/raw/
  // e.g. if file is yoga_alarm.mp3 → write 'yoga_alarm'
  static const String _alarmSoundName = 'yoga_alarm';

  static Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _notifications.initialize(settings);

    await _createAlarmChannel();
  }

  static Future<void> _createAlarmChannel() async {
    if (!Platform.isAndroid) return;

    final AndroidNotificationChannel channel = AndroidNotificationChannel(
      'yoga_alarm_channel_sound', // ✅ New channel ID — forces fresh channel
      'Yoga Alarm', //    with the correct sound baked in
      description: 'Rings at your scheduled yoga time',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      // ✅ Reference your sound file here (no extension)
      sound: RawResourceAndroidNotificationSound(_alarmSoundName),
    );

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(channel);

    debugPrint('=== Alarm channel created with sound: $_alarmSoundName');
  }

  static Future<bool> isExactAlarmPermissionGranted() async {
    if (!Platform.isAndroid) return true;
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return false;
    return await androidPlugin.canScheduleExactNotifications() ?? false;
  }

  static Future<void> openExactAlarmSettings() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestExactAlarmsPermission();
  }

  static Future<bool> checkAndRequestPermissions() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return true;

    final notifGranted =
        await androidPlugin.requestNotificationsPermission() ?? false;
    final exactGranted = await isExactAlarmPermissionGranted();

    debugPrint('=== Notification permission granted: $notifGranted');
    debugPrint('=== Exact alarm permission granted: $exactGranted');

    return notifGranted && exactGranted;
  }

  static Future<void> scheduleReminder({
    required int id,
    required int weekday,
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);

    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
      0,
    );

    int attempts = 0;
    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
      attempts++;
      if (attempts > 14) break;
    }

    debugPrint(
      '=== Scheduling alarm id=$id for: $scheduled '
      '(weekday: ${scheduled.weekday})',
    );

    await _notifications.zonedSchedule(
      id,
      'Yoga Reminder 🧘',
      'Time for your yoga session! Tap to begin.',
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'yoga_alarm_channel_sound', // ✅ must match channel ID above
          'Yoga Alarm',
          channelDescription: 'Rings at your scheduled yoga time',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          // ✅ Same sound reference on the notification itself
          sound: RawResourceAndroidNotificationSound(_alarmSoundName),
          enableVibration: true,
          // ✅ Strong vibration pattern: wait 0ms, vibrate 800ms,
          //    pause 300ms, vibrate 800ms, pause 300ms, vibrate 800ms
          vibrationPattern: Int64List.fromList([0, 800, 300, 800, 300, 800]),
          fullScreenIntent: true,
          autoCancel: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    debugPrint('=== Alarm id=$id scheduled successfully');
  }

  static Future<void> cancelForIds(List<int> ids) async {
    for (final id in ids) {
      await _notifications.cancel(id);
    }
  }

  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
