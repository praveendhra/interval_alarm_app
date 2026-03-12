import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/alarm_model.dart';
import '../services/storage_service.dart';
import '../services/alarm_scheduler_service.dart';
import '../services/notification_service.dart';

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

  Future<void> _scheduleAlarm(IntervalAlarm alarm) async {
    await NotificationService().scheduleAlarm(alarm);
    await AlarmSchedulerService().scheduleAlarm(alarm);
  }

  Future<void> _cancelAlarm(String id) async {
    await NotificationService().cancelAlarm(id);
    await AlarmSchedulerService().cancelAlarm(id);
  }

  /// Add a new alarm
  Future<void> addAlarm(IntervalAlarm alarm) async {
    final newAlarm = alarm.copyWith(id: _uuid.v4());
    _alarms.insert(0, newAlarm);
    await _save();

    if (newAlarm.isEnabled) {
      await _scheduleAlarm(newAlarm);
    }

    notifyListeners();
  }

  /// Update an existing alarm
  Future<void> updateAlarm(IntervalAlarm alarm) async {
    final index = _alarms.indexWhere((a) => a.id == alarm.id);
    if (index == -1) return;

    _alarms[index] = alarm;
    await _save();

    await _cancelAlarm(alarm.id);
    if (alarm.isEnabled) {
      await _scheduleAlarm(alarm);
    }

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

    if (updated.isEnabled) {
      await _scheduleAlarm(updated);
    } else {
      await _cancelAlarm(updated.id);
    }

    notifyListeners();
  }

  /// Delete an alarm
  Future<void> deleteAlarm(String id) async {
    await _cancelAlarm(id);
    _alarms.removeWhere((a) => a.id == id);
    await _save();
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
    for (final alarm in _alarms) {
      if (alarm.isEnabled) {
        await _scheduleAlarm(alarm);
      }
    }
  }
}
