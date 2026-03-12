import 'dart:convert';
import 'dart:io';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alarm_model.dart';

const _kCallbackPrefix = 'alarmcb_';
const _kTuneFilePrefix = 'tunefile_';

class AlarmSchedulerService {
  static final AlarmSchedulerService _instance =
      AlarmSchedulerService._internal();
  factory AlarmSchedulerService() => _instance;
  AlarmSchedulerService._internal();

  /// Copy Flutter asset tunes to device storage so background isolates can play them.
  /// Call this once on app startup. Stores device paths in SharedPreferences.
  static Future<void> copyTunesToStorage() async {
    final dir = await getApplicationDocumentsDirectory();
    final prefs = await SharedPreferences.getInstance();
    const tunes = [
      'tunes/gentle_chime.mp3',
      'tunes/morning_bird.mp3',
      'tunes/digital_pulse.mp3',
      'tunes/zen_bell.mp3',
      'tunes/classic_alarm.mp3',
    ];
    for (final tune in tunes) {
      final file = File('${dir.path}/$tune');
      if (!file.existsSync()) {
        await file.parent.create(recursive: true);
        final data = await rootBundle.load('assets/$tune');
        await file.writeAsBytes(data.buffer.asUint8List());
      }
      await prefs.setString('$_kTuneFilePrefix$tune', file.path);
    }
  }

  /// Get the device file path for a preloaded tune asset path.
  static Future<String?> _devicePath(String assetPath) async {
    final prefs = await SharedPreferences.getInstance();
    // assetPath is like 'assets/tunes/gentle_chime.mp3'
    final key = assetPath.replaceFirst('assets/', '');
    return prefs.getString('$_kTuneFilePrefix$key');
  }

  // Max rings to schedule per alarm — keeps us well under Android's 500-alarm limit
  static const _maxRingsPerAlarm = 40;

  /// Schedule audio callbacks — limits to next 40 rings to stay under Android's 500-alarm cap.
  Future<void> scheduleAlarm(IntervalAlarm alarm) async {
    if (!alarm.isEnabled) return;
    await cancelAlarm(alarm.id);

    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    int index = 0;

    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      if (index >= _maxRingsPerAlarm) break;
      final date = now.add(Duration(days: dayOffset));
      if (!alarm.activeDays.contains(date.weekday)) continue;

      final start = DateTime(date.year, date.month, date.day,
          alarm.startTime.hour, alarm.startTime.minute);
      var end = DateTime(date.year, date.month, date.day,
          alarm.endTime.hour, alarm.endTime.minute);
      if (end.isBefore(start)) end = end.add(const Duration(days: 1));

      DateTime current = start;
      while (!current.isAfter(end) && index < _maxRingsPerAlarm) {
        if (current.isAfter(now)) {
          // Resolve device file path (works in background isolates)
          final ringDevicePath = alarm.alarmTune.isCustom
              ? alarm.alarmTune.assetPath
              : await _devicePath(alarm.alarmTune.assetPath);

          // Schedule main ring
          final ringId = _callbackId(alarm.id, index, false);
          await prefs.setString(
            '$_kCallbackPrefix$ringId',
            jsonEncode({
              'label': alarm.label,
              'tuneFilePath': ringDevicePath ?? alarm.alarmTune.assetPath,
              'isReminder': false,
            }),
          );
          await AndroidAlarmManager.oneShotAt(
            current,
            ringId,
            alarmAudioCallback,
            exact: true,
            wakeup: true,
            rescheduleOnReboot: false,
          );

          // Schedule reminder
          if (alarm.reminderMinutesBefore > 0) {
            final reminderTime = current
                .subtract(Duration(minutes: alarm.reminderMinutesBefore));
            if (reminderTime.isAfter(now)) {
              final remDevicePath = alarm.reminderTune.isCustom
                  ? alarm.reminderTune.assetPath
                  : await _devicePath(alarm.reminderTune.assetPath);
              final remId = _callbackId(alarm.id, index, true);
              await prefs.setString(
                '$_kCallbackPrefix$remId',
                jsonEncode({
                  'label': alarm.label,
                  'tuneFilePath': remDevicePath ?? alarm.reminderTune.assetPath,
                  'isReminder': true,
                }),
              );
              await AndroidAlarmManager.oneShotAt(
                reminderTime,
                remId,
                alarmAudioCallback,
                exact: true,
                wakeup: true,
                rescheduleOnReboot: false,
              );
            }
          }
        }
        current = current.add(Duration(minutes: alarm.intervalMinutes));
        index++;
      }
    }
  }

  /// Cancel all scheduled callbacks for an alarm.
  Future<void> cancelAlarm(String alarmId) async {
    final prefs = await SharedPreferences.getInstance();
    final base = alarmId.hashCode.abs() % 100000;
    for (int i = 0; i < _maxRingsPerAlarm + 10; i++) {
      final ringId = base + i;
      final remId = base + 100 + i;
      await AndroidAlarmManager.cancel(ringId);
      await AndroidAlarmManager.cancel(remId);
      await prefs.remove('$_kCallbackPrefix$ringId');
      await prefs.remove('$_kCallbackPrefix$remId');
    }
  }

  int _callbackId(String alarmId, int index, bool isReminder) {
    final base = alarmId.hashCode.abs() % 100000;
    return isReminder ? base + 100 + index : base + index;
  }
}

/// Top-level callback — runs in a background Dart isolate when alarm fires.
/// android_alarm_manager_plus handles WidgetsFlutterBinding init before calling this.
@pragma('vm:entry-point')
void alarmAudioCallback(int id) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('$_kCallbackPrefix$id');
  if (raw == null) return;

  final data = jsonDecode(raw) as Map<String, dynamic>;
  final label = data['label'] as String;
  // tuneFilePath is always a device file path (copied to storage on startup)
  final tuneFilePath = data['tuneFilePath'] as String;
  final isReminder = data['isReminder'] as bool;

  // Use pre-created channels from NotificationService.initialize() — no channel creation needed
  final soundFile = tuneFilePath.split('/').last.replaceAll('.mp3', '');
  // Channel IDs match those pre-created in NotificationService.initialize()
  final channelId = isReminder ? 'alarm_reminder_$soundFile' : 'alarm_ring_$soundFile';

  final notifications = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  await notifications.initialize(
    const InitializationSettings(android: androidSettings),
  );
  await notifications.show(
    id,
    isReminder ? '🔔 Reminder: $label' : '⏰ $label',
    isReminder ? 'Alarm coming up soon' : 'Time for your interval alarm',
    NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        isReminder ? 'Alarm Reminders' : 'Alarm Rings',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(soundFile),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
        fullScreenIntent: !isReminder,
        category: isReminder
            ? AndroidNotificationCategory.reminder
            : AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
      ),
    ),
  );

  // AudioPlayer as backup
  try {
    final player = AudioPlayer();
    await player.setSource(DeviceFileSource(tuneFilePath));
    await player.resume();
    player.onPlayerComplete.first.then((_) => player.dispose()).timeout(
      const Duration(seconds: 60),
      onTimeout: () => player.dispose(),
    );
  } catch (_) {}
}
