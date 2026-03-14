import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/alarm_model.dart';
import 'debug_log_service.dart';

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
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTap,
    );

    // Explicitly create channels with max importance so Android can't downgrade them
    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // Pre-create a channel for each tune to lock in sound + max importance.
    // Channel IDs are versioned (v2) so old cached channels without alarm
    // audio attributes are replaced instead of reused.
    const tuneIds = [
      'gentle_chime', 'morning_bird', 'digital_pulse', 'zen_bell', 'classic_alarm'
    ];
    for (final tuneId in tuneIds) {
      // Use USAGE_ALARM audio stream — same as system Clock app, bypasses DND.
      await androidImpl?.createNotificationChannel(
        AndroidNotificationChannel(
          'alarm_ring_${tuneId}_v2',
          'Alarm Rings',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(tuneId),
          enableVibration: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          bypassDnd: true,
        ),
      );
      await androidImpl?.createNotificationChannel(
        AndroidNotificationChannel(
          'alarm_reminder_${tuneId}_v2',
          'Alarm Reminders',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(tuneId),
          enableVibration: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          bypassDnd: true,
        ),
      );
    }

    // Silent wake channel — used by background alarm callback for ring/reminder
    // notifications. AudioPlayer in the callback handles all sound; this channel
    // just wakes the screen, vibrates, and shows the Dismiss button.
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        'alarm_wake_v1',
        'Alarm Wakeup',
        importance: Importance.max,
        playSound: false,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        bypassDnd: true,
      ),
    );

    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();

    _initialized = true;
    await DebugLog.log('SETUP', 'NotificationService initialized. Timezone: ${tz.local.name}');
  }

  void _onNotificationTap(NotificationResponse response) {
    DebugLog.log('NOTIF', 'TAP: actionId=${response.actionId} id=${response.id}').ignore();
    if (response.actionId == 'stop') {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool('alarm_stop_signal', true);
        DebugLog.log('NOTIF', 'Stop signal written to prefs').ignore();
      });
    }
  }

  // Hard cap — combined with AlarmSchedulerService's 40, stays well under Android's 500 limit
  static const _maxNotifPerAlarm = 80;

  /// Schedule notifications for an alarm — capped at 20 to avoid Android's 500-alarm limit
  Future<void> scheduleAlarm(IntervalAlarm alarm) async {
    if (!alarm.isEnabled) return;

    await cancelAlarm(alarm.id);

    final now = tz.TZDateTime.now(tz.local);
    int notifIndex = 0;
    await DebugLog.log('NOTIF', 'Scheduling notifications for "${alarm.label}" | now=$now');

    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      if (notifIndex >= _maxNotifPerAlarm) break;
      final date = now.add(Duration(days: dayOffset));
      if (!alarm.activeDays.contains(date.weekday)) continue;

      final startOnDate = tz.TZDateTime(
        tz.local, date.year, date.month, date.day,
        alarm.startTime.hour, alarm.startTime.minute,
      );
      final endOnDate = tz.TZDateTime(
        tz.local, date.year, date.month, date.day,
        alarm.endTime.hour, alarm.endTime.minute,
      );

      final ringTimes = _buildRingTimes(startOnDate, endOnDate, alarm.intervalMinutes);
      await DebugLog.log('NOTIF', 'Day+$dayOffset: ${ringTimes.length} ring times built ($startOnDate → $endOnDate)');

      for (final ringTime in ringTimes) {
        if (notifIndex >= _maxNotifPerAlarm) break;
        if (ringTime.isBefore(now)) continue;

        await _scheduleNotification(
          id: _generateNotificationId(alarm.id, notifIndex, false),
          title: '⏰ ${alarm.label}',
          body: 'Time for your interval alarm',
          scheduledTime: ringTime,
          channelId: 'alarm_ring_${alarm.alarmTune.id}_v2',
          channelName: 'Alarm Rings',
          isAlarm: true,
        );
        await DebugLog.log('NOTIF', 'Ring notif #$notifIndex → $ringTime');
        // Reminder notifications are scheduled by AlarmSchedulerService (AlarmManager-based)
        // to avoid being wiped by rescheduleAll() on app cold-starts triggered by fullScreenIntent.
        notifIndex++;
      }
    }
    await DebugLog.log('NOTIF', '"${alarm.label}" done: $notifIndex notifications scheduled');
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
    // Extract tune name from channelId (e.g. 'alarm_ring_gentle_chime_v2' → 'gentle_chime')
    final tuneName = channelId
        .replaceFirst('alarm_ring_', '')
        .replaceFirst('alarm_reminder_', '')
        .replaceFirst('_v2', '');
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: isAlarm ? 'Interval alarm rings' : 'Alarm reminders',
      importance: isAlarm ? Importance.max : Importance.high,
      priority: isAlarm ? Priority.max : Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(tuneName),
      audioAttributesUsage: AudioAttributesUsage.alarm,
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
      await DebugLog.log('NOTIF', 'zonedSchedule EXACT OK: id=$id at $scheduledTime channel=$channelId');
    } catch (e) {
      await DebugLog.log('NOTIF', 'zonedSchedule EXACT failed ($e) — falling back to inexact');
      try {
        await _notifications.zonedSchedule(
          id, title, body, scheduledTime, details,
          androidScheduleMode: AndroidScheduleMode.inexact,
        );
        await DebugLog.log('NOTIF', 'zonedSchedule INEXACT OK: id=$id');
      } catch (e2) {
        await DebugLog.log('NOTIF', 'zonedSchedule INEXACT also failed: $e2');
      }
    }
  }

  /// Show an immediate notification + schedule one 30s from now (for testing)
  Future<void> showTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'alarm_ring_gentle_chime_v2',
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
    await DebugLog.log('NOTIF', 'Test: immediate notification sent');

    // Scheduled 10s from now — proves scheduled notifications fire with sound
    final in10s = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10));
    try {
      await _notifications.zonedSchedule(
        9998, '⏰ Alarm Test', 'Scheduled sound works! ✅', in10s, details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      await DebugLog.log('NOTIF', 'Test: 10s EXACT scheduled at $in10s');
    } catch (e) {
      await DebugLog.log('NOTIF', 'Test: 10s EXACT failed ($e) — using inexact');
      await _notifications.zonedSchedule(
        9998, '⏰ Alarm Test', 'Scheduled sound works! ✅', in10s, details,
        androidScheduleMode: AndroidScheduleMode.inexact,
      );
    }
  }

  /// Cancel all notifications for a given alarm
  Future<void> cancelAlarm(String alarmId) async {
    final baseId = alarmId.hashCode.abs() % 100000;
    for (int i = 0; i < _maxNotifPerAlarm + 5; i++) {
      await _notifications.cancel(baseId + i);
      await _notifications.cancel(baseId + 100 + i); // reminder IDs
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

/// Top-level callback required by flutter_local_notifications for background/killed app.
/// Must be annotated so the Dart compiler doesn't tree-shake it.
@pragma('vm:entry-point')
void _onBackgroundNotificationTap(NotificationResponse response) {
  DebugLog.log('NOTIF', 'BG-TAP: actionId=${response.actionId} id=${response.id}').ignore();
  if (response.actionId == 'stop') {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('alarm_stop_signal', true);
      DebugLog.log('NOTIF', 'BG Stop signal written to prefs').ignore();
    });
  }
}
