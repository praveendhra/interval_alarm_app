import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/alarm_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    // Set device's local timezone so notifications fire at correct local time
    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      // Fall back to UTC if timezone detection fails
      tz.setLocalLocation(tz.UTC);
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _notifications.initialize(
      InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Explicitly create channels with max importance so Android can't downgrade them
    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // Pre-create a channel for each tune to lock in sound + max importance
    const tuneIds = [
      'gentle_chime', 'morning_bird', 'digital_pulse', 'zen_bell', 'classic_alarm'
    ];
    for (final tuneId in tuneIds) {
      await androidImpl?.createNotificationChannel(
        AndroidNotificationChannel(
          'alarm_ring_$tuneId',
          'Alarm Rings',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(tuneId),
          enableVibration: true,
        ),
      );
      await androidImpl?.createNotificationChannel(
        AndroidNotificationChannel(
          'alarm_reminder_$tuneId',
          'Alarm Reminders',
          importance: Importance.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(tuneId),
          enableVibration: true,
        ),
      );
    }

    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();

    _initialized = true;
  }

  void _onNotificationTap(NotificationResponse response) {}

  /// Schedule all notifications for an alarm across the next 7 days
  Future<void> scheduleAlarm(IntervalAlarm alarm) async {
    if (!alarm.isEnabled) return;

    await cancelAlarm(alarm.id);

    final now = tz.TZDateTime.now(tz.local);

    // Schedule for each active day in the next 7 days
    int notifIndex = 0;
    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      final date = now.add(Duration(days: dayOffset));
      // weekday: Mon=1, Sun=7 (same as activeDays convention)
      final weekday = date.weekday;

      if (!alarm.activeDays.contains(weekday)) continue;

      // Build ring times for this date using the alarm's start/end time-of-day
      final startOnDate = tz.TZDateTime(
        tz.local,
        date.year, date.month, date.day,
        alarm.startTime.hour, alarm.startTime.minute,
      );
      final endOnDate = tz.TZDateTime(
        tz.local,
        date.year, date.month, date.day,
        alarm.endTime.hour, alarm.endTime.minute,
      );

      final ringTimes = _buildRingTimes(startOnDate, endOnDate, alarm.intervalMinutes);

      for (final ringTime in ringTimes) {
        if (ringTime.isBefore(now)) continue;

        // Schedule main ring
        await _scheduleNotification(
          id: _generateNotificationId(alarm.id, notifIndex, false),
          title: '⏰ ${alarm.label}',
          body: 'Time for your interval alarm',
          scheduledTime: ringTime,
          channelId: 'alarm_ring_${alarm.alarmTune.id}',
          channelName: 'Alarm Rings',
          isAlarm: true,
        );

        // Schedule reminder if set
        if (alarm.reminderMinutesBefore > 0) {
          final reminderTime = ringTime.subtract(
            Duration(minutes: alarm.reminderMinutesBefore),
          );
          if (reminderTime.isAfter(now)) {
            await _scheduleNotification(
              id: _generateNotificationId(alarm.id, notifIndex, true),
              title: '🔔 Reminder: ${alarm.label}',
              body: 'Alarm in ${alarm.reminderMinutesBefore} min',
              scheduledTime: reminderTime,
              channelId: 'alarm_reminder_${alarm.reminderTune.id}',
              channelName: 'Alarm Reminders',
              isAlarm: false,
            );
          }
        }

        notifIndex++;
      }
    }
  }

  List<tz.TZDateTime> _buildRingTimes(
    tz.TZDateTime start, tz.TZDateTime end, int intervalMinutes,
  ) {
    final times = <tz.TZDateTime>[];
    var current = start;
    while (!current.isAfter(end)) {
      times.add(current);
      current = current.add(Duration(minutes: intervalMinutes));
    }
    return times;
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledTime,
    required String channelId,
    required String channelName,
    required bool isAlarm,
  }) async {
    // Visual-only notification — sound is handled by AudioPlayer in the callback
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: isAlarm ? 'Interval alarm rings' : 'Alarm reminders',
      importance: isAlarm ? Importance.max : Importance.high,
      priority: isAlarm ? Priority.max : Priority.high,
      playSound: false,
      enableVibration: true,
      fullScreenIntent: isAlarm,
      category: isAlarm
          ? AndroidNotificationCategory.alarm
          : AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    try {
      await _notifications.zonedSchedule(
        id, title, body, scheduledTime, details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      await _notifications.zonedSchedule(
        id, title, body, scheduledTime, details,
        androidScheduleMode: AndroidScheduleMode.inexact,
      );
    }
  }

  /// Show an immediate notification + schedule one 30s from now (for testing)
  Future<void> showTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'alarm_ring_gentle_chime',
      'Alarm Rings',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('gentle_chime'),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
    );
    const details = NotificationDetails(android: androidDetails);

    // Immediate notification
    await _notifications.show(9999, '🔔 Sound Test', 'Immediate — sound working!', details);

    // Scheduled 10s from now — proves scheduled notifications fire with sound
    final in10s = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10));
    try {
      await _notifications.zonedSchedule(
        9998, '⏰ Alarm Test', 'Scheduled sound works! ✅', in10s, details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      await _notifications.zonedSchedule(
        9998, '⏰ Alarm Test', 'Scheduled sound works! ✅', in10s, details,
        androidScheduleMode: AndroidScheduleMode.inexact,
      );
    }
  }

  /// Cancel all notifications for a given alarm
  Future<void> cancelAlarm(String alarmId) async {
    final baseId = alarmId.hashCode.abs() % 100000;
    for (int i = 0; i < 50; i++) {
      await _notifications.cancel(baseId + i);
    }
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  int _generateNotificationId(String alarmId, int index, bool isReminder) {
    final baseId = alarmId.hashCode.abs() % 100000;
    final offset = isReminder ? 100 : 0;
    return baseId + offset + index;
  }

  Future<bool> requestPermissions() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestNotificationsPermission();
      await android.requestExactAlarmsPermission();
    }
    return true;
  }
}
