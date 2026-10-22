import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/alarm_model.dart';
import 'debug_log_service.dart';

/// Schedules interval alarms on iOS.
///
/// iOS has no AlarmManager equivalent and never runs app code in the
/// background at an exact time, so every ring and reminder is a local
/// notification scheduled ahead of time. Two iOS rules shape this class:
///
/// * An app can have at most 64 pending notifications. When the weekly
///   pattern of all alarms fits in 64, each slot is scheduled as a repeating
///   notification (daily or weekly), so alarms keep working even if the app
///   is never opened again. When it doesn't fit, the next 64 rings are
///   scheduled one-shot and topped up every time the app comes to the
///   foreground ([needsAppOpen] becomes true when that only covers the
///   next two days, so the UI can say so).
/// * Notification sounds must be short (under 30 s) PCM files in
///   `Library/Sounds`. Tunes are converted there by native code
///   (AppDelegate.swift), looped to ~28 s for rings and ~10 s for reminders.
class IosAlarmScheduler {
  IosAlarmScheduler._();

  static const _soundChannel = MethodChannel('interval_alarm/notification_sound');
  static const int maxPending = 64;
  static const double _ringSeconds = 28;
  static const double _reminderSeconds = 10;

  /// True when there are more upcoming rings than iOS can hold, so later
  /// rings are only scheduled when the app is opened again.
  static final ValueNotifier<bool> needsAppOpen = ValueNotifier(false);

  static Future<void> _queue = Future.value();

  /// Replace every pending notification with a fresh schedule for [alarms].
  /// Calls are serialized, so rapid toggles never interleave.
  static Future<void> sync(List<IntervalAlarm> alarms) {
    final snapshot = List<IntervalAlarm>.of(alarms);
    final next = _queue.then((_) => _sync(snapshot)).catchError((Object e, StackTrace s) async {
      await DebugLog.log('IOS', 'sync failed: $e\n$s');
    });
    _queue = next;
    return next;
  }

  static Future<void> _sync(List<IntervalAlarm> alarms) async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.cancelAll();

    final enabled = alarms.where((a) => a.isEnabled).toList();
    if (enabled.isEmpty) {
      needsAppOpen.value = false;
      await DebugLog.log('IOS', 'No enabled alarms — nothing scheduled');
      return;
    }

    final now = tz.TZDateTime.now(tz.local);
    final sounds = <String, String?>{};
    Future<String?> soundFor(AlarmTune tune, bool reminder) async {
      final key = '${reminder ? 'rem' : 'ring'}_${tune.id}';
      if (!sounds.containsKey(key)) sounds[key] = await _prepareSound(tune, reminder);
      return sounds[key];
    }

    // Weekly pattern: group each (alarm, kind, hh:mm) by the weekdays it occurs on.
    final slots = <String, _Slot>{};
    for (final alarm in enabled) {
      for (final ev in _eventsForWeek(alarm, DateTime(now.year, now.month, now.day))) {
        final key = '${alarm.id}|${ev.reminder}|${ev.at.hour}:${ev.at.minute}';
        slots.putIfAbsent(key, () => _Slot(alarm, ev.reminder, ev.at.hour, ev.at.minute)).weekdays.add(ev.at.weekday);
      }
    }
    // Daily slots cost one notification each and repeat forever, so they go
    // first. Slots that only run on some weekdays repeat weekly if they fit
    // in what's left; otherwise those alarms get their soonest rings as
    // one-shot notifications, topped up each time the app is opened.
    final daily = slots.values.where((s) => s.weekdays.length == 7).toList();
    final weekly = slots.values.where((s) => s.weekdays.length < 7).toList();
    final weeklyCount = weekly.fold<int>(0, (n, s) => n + s.weekdays.length);

    var id = 1;
    var oneShot = <_Event>[];
    if (daily.length > maxPending) {
      // Even the daily slots don't fit: everything becomes one-shot.
      oneShot = _upcoming(enabled, now);
    } else {
      for (final slot in daily) {
        final sound = await soundFor(slot.reminder ? slot.alarm.reminderTune : slot.alarm.alarmTune, slot.reminder);
        await _schedule(plugin, id++, slot.alarm, slot.reminder, _nextTime(now, slot.hour, slot.minute, null), sound, DateTimeComponents.time);
      }
      if (daily.length + weeklyCount <= maxPending) {
        for (final slot in weekly) {
          final sound = await soundFor(slot.reminder ? slot.alarm.reminderTune : slot.alarm.alarmTune, slot.reminder);
          for (final weekday in slot.weekdays) {
            await _schedule(plugin, id++, slot.alarm, slot.reminder, _nextTime(now, slot.hour, slot.minute, weekday), sound, DateTimeComponents.dayOfWeekAndTime);
          }
        }
      } else {
        final weeklyKeys = weekly.map((s) => '${s.alarm.id}|${s.reminder}|${s.hour}:${s.minute}').toSet();
        oneShot = _upcoming(enabled, now)
            .where((e) => weeklyKeys.contains('${e.alarm.id}|${e.reminder}|${e.at.hour}:${e.at.minute}'))
            .toList();
      }
    }

    final oneShotTotal = oneShot.length;
    final room = maxPending - (id - 1);
    final taken = oneShot.take(room).toList();
    for (final ev in taken) {
      final sound = await soundFor(ev.reminder ? ev.alarm.reminderTune : ev.alarm.alarmTune, ev.reminder);
      final at = tz.TZDateTime(tz.local, ev.at.year, ev.at.month, ev.at.day, ev.at.hour, ev.at.minute);
      await _schedule(plugin, id++, ev.alarm, ev.reminder, at, sound, null);
    }

    // Only nag when what's scheduled runs out within two days.
    final truncated = oneShotTotal > taken.length;
    needsAppOpen.value = truncated && (taken.isEmpty || taken.last.at.isBefore(now.add(const Duration(days: 2))));
    await DebugLog.log('IOS', 'Scheduled ${id - 1} notifications (${daily.length} daily, ${taken.length} one-shot of $oneShotTotal)');
  }

  /// Every upcoming ring/reminder over the next 8 days, soonest first.
  static List<_Event> _upcoming(List<IntervalAlarm> alarms, tz.TZDateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final events = <_Event>[
      for (final alarm in alarms) ..._eventsForWeek(alarm, today, days: 8).where((e) => e.at.isAfter(now)),
    ]..sort((a, b) => a.at.compareTo(b.at));
    return events;
  }

  /// Every ring and reminder of [alarm] for [days] days starting at [today]
  /// (including ones earlier today, which the weekly pattern needs).
  static List<_Event> _eventsForWeek(IntervalAlarm alarm, DateTime today, {int days = 7}) {
    final events = <_Event>[];
    for (var offset = 0; offset < days; offset++) {
      final date = today.add(Duration(days: offset));
      if (!alarm.activeDays.contains(date.weekday)) continue;
      final start = DateTime(date.year, date.month, date.day, alarm.startTime.hour, alarm.startTime.minute);
      var end = DateTime(date.year, date.month, date.day, alarm.endTime.hour, alarm.endTime.minute);
      if (end.isBefore(start)) end = end.add(const Duration(days: 1));
      final step = Duration(minutes: alarm.intervalMinutes < 1 ? 1 : alarm.intervalMinutes);
      for (var t = start; !t.isAfter(end); t = t.add(step)) {
        events.add(_Event(alarm, false, t));
        if (alarm.reminderMinutesBefore > 0) {
          events.add(_Event(alarm, true, t.subtract(Duration(minutes: alarm.reminderMinutesBefore))));
        }
      }
    }
    return events;
  }

  static tz.TZDateTime _nextTime(tz.TZDateTime now, int hour, int minute, int? weekday) {
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (!t.isAfter(now) || (weekday != null && t.weekday != weekday)) {
      t = tz.TZDateTime(tz.local, t.year, t.month, t.day + 1, hour, minute);
    }
    return t;
  }

  static Future<void> _schedule(
    FlutterLocalNotificationsPlugin plugin,
    int id,
    IntervalAlarm alarm,
    bool reminder,
    tz.TZDateTime at,
    String? sound,
    DateTimeComponents? repeat,
  ) async {
    final details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentSound: true,
        sound: sound,
        interruptionLevel: InterruptionLevel.active,
      ),
    );
    await plugin.zonedSchedule(
      id,
      reminder ? '🔔 Reminder: ${alarm.label}' : '⏰ ${alarm.label}',
      reminder ? 'Next ring in ${alarm.reminderMinutesBefore} min' : 'Time for your interval alarm',
      at,
      details,
      androidScheduleMode: AndroidScheduleMode.inexact,
      matchDateTimeComponents: repeat,
      payload: alarm.id,
    );
  }

  /// Converts [tune] into `Library/Sounds/<name>.caf` once and returns the
  /// file name iOS should play, or null to fall back to the default sound.
  static Future<String?> _prepareSound(AlarmTune tune, bool reminder) async {
    try {
      final name = '${reminder ? 'rem' : 'ring'}_${tune.id}.caf';
      final library = await getLibraryDirectory();
      final dest = File('${library.path}/Sounds/$name');
      if (await dest.exists()) return name;

      String src;
      if (tune.isCustom) {
        src = tune.assetPath;
      } else {
        // copyTunesToStorage() placed bundled tunes in Documents/tunes/.
        final docs = await getApplicationDocumentsDirectory();
        src = '${docs.path}/${tune.assetPath.replaceFirst('assets/', '')}';
      }
      if (!await File(src).exists()) return null;

      await _soundChannel.invokeMethod<bool>('convert', {
        'src': src,
        'dest': dest.path,
        'seconds': reminder ? _reminderSeconds : _ringSeconds,
      });
      return name;
    } catch (e) {
      await DebugLog.log('IOS', 'Sound conversion failed for ${tune.id}: $e');
      return null;
    }
  }
}

class _Event {
  _Event(this.alarm, this.reminder, this.at);
  final IntervalAlarm alarm;
  final bool reminder;
  final DateTime at;
}

class _Slot {
  _Slot(this.alarm, this.reminder, this.hour, this.minute);
  final IntervalAlarm alarm;
  final bool reminder;
  final int hour;
  final int minute;
  final Set<int> weekdays = {};
}
