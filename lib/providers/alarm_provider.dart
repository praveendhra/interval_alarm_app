import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/alarm_model.dart';
import '../services/storage_service.dart';
import '../services/alarm_scheduler_service.dart';
import '../services/notification_service.dart';
import '../services/debug_log_service.dart';
import '../services/ios_alarm_scheduler.dart';

class AlarmProvider extends ChangeNotifier {
  List<IntervalAlarm> _alarms = [];
  bool _isLoading = true;
  final _uuid = const Uuid();

  List<IntervalAlarm> get alarms => _alarms;
  bool get isLoading => _isLoading;
  int get activeCount => _alarms.where((a) => a.isEnabled).length;

  /// Load alarms from storage and reschedule all active notifications
  Future<void> loadAlarms() async {
    _isLoading = true;
    notifyListeners();

    _alarms = await StorageService.loadAlarms();
    _isLoading = false;
    notifyListeners();

    // Reschedule all active alarms with correct timezone on every app start
    await rescheduleAll();
  }

  // iOS schedules every alarm together (64-notification budget), so per-alarm
  // schedule/cancel calls are no-ops there and each change ends with _syncIos().
  Future<void> _syncIos() async {
    if (Platform.isIOS) await IosAlarmScheduler.sync(_alarms);
  }

  Future<void> _scheduleAlarm(IntervalAlarm alarm) async {
    if (Platform.isIOS) return;
    // NotificationService pre-scheduled ring notifications were removed —
    // they consumed AlarmManager quota (same 500-alarm pool) redundantly,
    // since AlarmSchedulerService's callback shows the notification itself.
    await AlarmSchedulerService().scheduleAlarm(alarm);
  }

  Future<void> _cancelAlarm(String id) async {
    if (Platform.isIOS) return;
    await NotificationService().cancelAlarm(id); // clears any legacy pre-scheduled entries
    await AlarmSchedulerService().cancelAlarm(id);
  }

  /// Add a new alarm
  Future<void> addAlarm(IntervalAlarm alarm) async {
    final newAlarm = alarm.copyWith(id: _uuid.v4());
    _alarms.insert(0, newAlarm);
    await _save();
    await DebugLog.log('PROVIDER', 'Alarm ADDED: "${newAlarm.label}" id=${newAlarm.id} enabled=${newAlarm.isEnabled}');

    if (newAlarm.isEnabled) {
      await _scheduleAlarm(newAlarm);
    }
    await _syncIos();

    notifyListeners();
  }

  /// Update an existing alarm
  Future<void> updateAlarm(IntervalAlarm alarm) async {
    final index = _alarms.indexWhere((a) => a.id == alarm.id);
    if (index == -1) return;

    _alarms[index] = alarm;
    await _save();
    await DebugLog.log('PROVIDER', 'Alarm UPDATED: "${alarm.label}" enabled=${alarm.isEnabled}');

    await _cancelAlarm(alarm.id);
    if (alarm.isEnabled) {
      await _scheduleAlarm(alarm);
    }
    await _syncIos();

    notifyListeners();
  }

  /// Toggle alarm on/off
  Future<void> toggleAlarm(String id) async {
    final index = _alarms.indexWhere((a) => a.id == id);
    if (index == -1) return;

    final alarm = _alarms[index];
    final updated = alarm.copyWith(isEnabled: !alarm.isEnabled);
    _alarms[index] = updated;
    await _save();
    await DebugLog.log('PROVIDER', 'Alarm TOGGLED: "${updated.label}" → enabled=${updated.isEnabled}');

    if (updated.isEnabled) {
      await _scheduleAlarm(updated);
    } else {
      await _cancelAlarm(updated.id);
    }
    await _syncIos();

    notifyListeners();
  }

  /// Delete an alarm
  Future<void> deleteAlarm(String id) async {
    final alarm = _alarms.firstWhere((a) => a.id == id, orElse: () => _alarms.first);
    await DebugLog.log('PROVIDER', 'Alarm DELETED: "${alarm.label}"');
    await _cancelAlarm(id);
    _alarms.removeWhere((a) => a.id == id);
    await _save();
    await _syncIos();
    notifyListeners();
  }

  /// Get alarm by ID
  IntervalAlarm? getAlarm(String id) {
    try {
      return _alarms.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    await StorageService.saveAlarms(_alarms);
  }

  /// Reschedule all active alarms (e.g., after app restart)
  Future<void> rescheduleAll() async {
    if (Platform.isIOS) return _syncIos();
    for (final alarm in List.of(_alarms)) {
      if (alarm.isEnabled) {
        await _scheduleAlarm(alarm);
      }
    }
  }
}
