import 'dart:convert';
import 'dart:io';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alarm_model.dart';
import 'debug_log_service.dart';

const _kCallbackPrefix = 'alarmcb_';
const _kTuneFilePrefix = 'tunefile_';

class AlarmSchedulerService {
  static final AlarmSchedulerService _instance =
      AlarmSchedulerService._internal();
  factory AlarmSchedulerService() => _instance;
  AlarmSchedulerService._internal();

  /// Copy Flutter asset tunes to device storage so background isolates can play them.
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
        await DebugLog.log('SETUP', 'Copied tune to storage: $tune');
      }
      await prefs.setString('$_kTuneFilePrefix$tune', file.path);
    }
    await DebugLog.log('SETUP', 'Tunes ready in: ${dir.path}/tunes/');
  }

  static Future<String?> _devicePath(String assetPath) async {
    final prefs = await SharedPreferences.getInstance();
    final key = assetPath.replaceFirst('assets/', '');
    return prefs.getString('$_kTuneFilePrefix$key');
  }

  static const _maxRingsPerAlarm = 80;

  Future<void> scheduleAlarm(IntervalAlarm alarm) async {
    if (!alarm.isEnabled) {
      await DebugLog.log('SCHEDULE', 'Skipped "${alarm.label}" — disabled');
      return;
    }
    await cancelAlarm(alarm.id);

    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    int index = 0;
    int scheduled = 0;

    await DebugLog.log('SCHEDULE', 'Scheduling "${alarm.label}" | now=$now | activeDays=${alarm.activeDays}');

    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      if (index >= _maxRingsPerAlarm) break;
      final date = now.add(Duration(days: dayOffset));
      if (!alarm.activeDays.contains(date.weekday)) continue;

      final start = DateTime(date.year, date.month, date.day,
          alarm.startTime.hour, alarm.startTime.minute);
      var end = DateTime(date.year, date.month, date.day,
          alarm.endTime.hour, alarm.endTime.minute);
      if (end.isBefore(start)) end = end.add(const Duration(days: 1));

      await DebugLog.log('SCHEDULE', 'Day+$dayOffset: window $start → $end (interval=${alarm.intervalMinutes}m)');

      DateTime current = start;
      while (!current.isAfter(end) && index < _maxRingsPerAlarm) {
        if (current.isAfter(now)) {
          final ringDevicePath = alarm.alarmTune.isCustom
              ? alarm.alarmTune.assetPath
              : await _devicePath(alarm.alarmTune.assetPath);

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
            alarmClock: true,
            rescheduleOnReboot: false,
          );
          scheduled++;
          await DebugLog.log('SCHEDULE', 'Ring #$scheduled → id=$ringId at $current | tune=${ringDevicePath?.split('/').last}');

          // Schedule reminder via AlarmManager (immune to app-restart reschedule wiping)
          if (alarm.reminderMinutesBefore > 0) {
            final reminderTime = current.subtract(Duration(minutes: alarm.reminderMinutesBefore));
            if (reminderTime.isAfter(now)) {
              final reminderDevicePath = alarm.reminderTune.isCustom
                  ? alarm.reminderTune.assetPath
                  : await _devicePath(alarm.reminderTune.assetPath);
              final remId = _callbackId(alarm.id, index, true);
              await prefs.setString(
                '$_kCallbackPrefix$remId',
                jsonEncode({
                  'label': alarm.label,
                  'tuneFilePath': reminderDevicePath ?? alarm.reminderTune.assetPath,
                  'isReminder': true,
                }),
              );
              await AndroidAlarmManager.oneShotAt(
                reminderTime,
                remId,
                alarmAudioCallback,
                exact: true,
                wakeup: true,
                alarmClock: false,
                rescheduleOnReboot: false,
              );
              await DebugLog.log('SCHEDULE', 'Reminder → id=$remId at $reminderTime');
            }
          }

          index++;
        }
        current = current.add(Duration(minutes: alarm.intervalMinutes));
      }
    }
    await DebugLog.log('SCHEDULE', '"${alarm.label}" done: $scheduled rings scheduled (index=$index)');
  }

  Future<void> cancelAlarm(String alarmId) async {
    final prefs = await SharedPreferences.getInstance();
    final base = alarmId.hashCode.abs() % 100000;
    int cancelled = 0;
    for (int i = 0; i < _maxRingsPerAlarm + 10; i++) {
      final ringId = base + i;
      if (prefs.containsKey('$_kCallbackPrefix$ringId')) {
        await AndroidAlarmManager.cancel(ringId);
        await prefs.remove('$_kCallbackPrefix$ringId');
        cancelled++;
      }
      // Also clean up any legacy reminder entries from before this fix
      final remId = base + 100 + i;
      if (prefs.containsKey('$_kCallbackPrefix$remId')) {
        await AndroidAlarmManager.cancel(remId);
        await prefs.remove('$_kCallbackPrefix$remId');
        cancelled++;
      }
    }
    if (cancelled > 0) {
      await DebugLog.log('CANCEL', 'Cancelled $cancelled alarm-manager entries for id=$alarmId');
    }
  }

  int _callbackId(String alarmId, int index, bool isReminder) {
    final base = alarmId.hashCode.abs() % 100000;
    return isReminder ? base + 100 + index : base + index;
  }
}

/// Top-level callback — runs in a background Dart isolate when alarm fires.
/// MUST be Future<void> so android_alarm_manager_plus awaits it and keeps the
/// isolate alive. A void return causes the plugin to shut the isolate down
/// immediately, before any async work (notifications/audio) can run.
@pragma('vm:entry-point')
Future<void> alarmAudioCallback(int id) async {
  // This isolate does NOT run main(), so allowRuntimeFetching must be set here.
  GoogleFonts.config.allowRuntimeFetching = false;

  try {
    await _alarmAudioCallbackBody(id);
  } catch (error, stack) {
    await DebugLog.log('CALLBACK', 'TOP-LEVEL ERROR: $error\n$stack');
  }
}

Future<void> _alarmAudioCallbackBody(int id) async {
  await DebugLog.log('CALLBACK', 'alarmAudioCallback fired! id=$id');

  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('$_kCallbackPrefix$id');
  if (raw == null) {
    await DebugLog.log('CALLBACK', 'ERROR: no prefs data for id=$id — alarm may have been cancelled');
    return;
  }

  final data = jsonDecode(raw) as Map<String, dynamic>;
  final label = data['label'] as String;
  final tuneFilePath = data['tuneFilePath'] as String;
  final isReminder = data['isReminder'] as bool;
  await DebugLog.log('CALLBACK', 'Data: label="$label" tune=$tuneFilePath isReminder=$isReminder');

  final fileExists = File(tuneFilePath).existsSync();
  await DebugLog.log('CALLBACK', 'Tune file exists: $fileExists (path: $tuneFilePath)');

  await DebugLog.log('CALLBACK', 'Showing notification | isReminder=$isReminder');

  final notifications = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  try {
    await notifications.initialize(
      const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: _onAlarmNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onAlarmNotificationResponse,
    );
    // Use the silent wake channel — AudioPlayer (below) handles all sound.
    // Previously the channel sound and AudioPlayer played simultaneously on the
    // USAGE_ALARM stream and fought for audio focus, resulting in silence.
    await notifications.show(
      id,
      isReminder ? '🔔 Reminder: $label' : '⏰ $label',
      isReminder ? 'Alarm coming up soon' : 'Time for your interval alarm',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'alarm_wake_v1',
          'Alarm Wakeup',
          importance: Importance.max,
          priority: Priority.max,
          playSound: false,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          enableVibration: true,
          fullScreenIntent: !isReminder,
          category: isReminder
              ? AndroidNotificationCategory.reminder
              : AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          actions: isReminder
              ? null
              : [
                  const AndroidNotificationAction(
                    'stop',
                    'Dismiss',
                    cancelNotification: true,
                    showsUserInterface: false,
                  ),
                ],
        ),
      ),
    );
    await DebugLog.log('CALLBACK', 'Notification shown OK');
  } catch (e) {
    await DebugLog.log('CALLBACK', 'ERROR showing notification: $e');
  }

  // AudioPlayer — use ALARM stream so it plays even on silent mode
  try {
    final player = AudioPlayer();
    await player.setAudioContext(AudioContext(
      android: AudioContextAndroid(
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.alarm,
        audioFocus: AndroidAudioFocus.gain,
        stayAwake: true,
      ),
    ));

    if (!isReminder) {
      // Ring: loop until dismissed or 5-minute auto-stop
      const stopKey = 'alarm_stop_signal';
      await prefs.remove(stopKey);
      await prefs.setInt('alarm_ringing_callback_id', id);
      await prefs.setInt('alarm_ring_start_ms', DateTime.now().millisecondsSinceEpoch);
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setSource(DeviceFileSource(tuneFilePath));
      await player.resume();
      await DebugLog.log('CALLBACK', 'AudioPlayer looping — waiting for stop signal');
      final stopAt = DateTime.now().add(const Duration(minutes: 5));
      int pollCount = 0;
      while (DateTime.now().isBefore(stopAt)) {
        await Future.delayed(const Duration(milliseconds: 500));
        await prefs.reload();
        final val = prefs.getBool(stopKey);
        if (pollCount % 10 == 0) {
          await DebugLog.log('CALLBACK', 'Polling #$pollCount: stopKey=$val');
        }
        pollCount++;
        if (val == true) {
          await DebugLog.log('CALLBACK', 'Stop signal received — stopping audio');
          break;
        }
      }
      await player.dispose();
      await prefs.remove(stopKey);
      await prefs.remove('alarm_ringing_callback_id');
      await prefs.remove('alarm_ring_start_ms');
      await notifications.cancel(id);
    } else {
      // Reminder: play for 10 seconds, looping if the tune is shorter.
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setSource(DeviceFileSource(tuneFilePath));
      await player.resume();
      await DebugLog.log('CALLBACK', 'Reminder: AudioPlayer looping for 10s');
      await Future.delayed(const Duration(seconds: 10));
      // Switch to release mode before dispose — so audioplayers calls mediaPlayer.release()
      // (safe in any state) instead of mediaPlayer.pause() which fails in Prepared state.
      await player.setReleaseMode(ReleaseMode.release);
      await player.dispose();
      await DebugLog.log('CALLBACK', 'Reminder: 10s done, audio stopped');
    }
    await DebugLog.log('CALLBACK', 'AudioPlayer done');
  } catch (e) {
    await DebugLog.log('CALLBACK', 'AudioPlayer ERROR: $e');
  }
}

/// Notification action callback registered inside the background alarm isolate.
/// Must be top-level so flutter_local_notifications can store its handle via
/// PluginUtilities.getCallbackHandle() and invoke it when the action fires.
@pragma('vm:entry-point')
void _onAlarmNotificationResponse(NotificationResponse response) {
  if (response.actionId == 'stop') {
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setBool('alarm_stop_signal', true));
  }
}
