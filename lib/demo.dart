import 'package:flutter/material.dart';

import 'models/alarm_model.dart';
import 'screens/alarm_detail_screen.dart';
import 'screens/create_alarm_screen.dart';
import 'screens/home_screen.dart';
import 'screens/my_tunes_screen.dart';
import 'services/storage_service.dart';

/// Build-time switches used only by CI to capture App Store screenshots:
///   flutter build ios --simulator --dart-define=DEMO=true --dart-define=SCREEN=detail
/// Release builds never set them, so none of this runs for users.
class Demo {
  static const enabled = bool.fromEnvironment('DEMO');
  static const screen = String.fromEnvironment('SCREEN', defaultValue: 'home');

  /// Seed two sample alarms on a fresh install.
  static Future<void> seed() async {
    if (!enabled) return;
    if ((await StorageService.loadAlarms()).isNotEmpty) return;
    DateTime at(int h, int m) => DateTime(2026, 1, 1, h, m);
    await StorageService.saveAlarms([
      IntervalAlarm(
        id: 'demo-focus',
        label: 'Focus sprints',
        startTime: at(9, 0),
        endTime: at(12, 0),
        intervalMinutes: 30,
        reminderMinutesBefore: 5,
        alarmTune: PreloadedTunes.getAlarmTuneById('digital_pulse'),
        reminderTune: PreloadedTunes.getReminderTuneById('gentle_chime'),
        activeDays: const [1, 2, 3, 4, 5],
      ),
      IntervalAlarm(
        id: 'demo-water',
        label: 'Drink water',
        startTime: at(8, 0),
        endTime: at(20, 0),
        intervalMinutes: 120,
        reminderMinutesBefore: 0,
        alarmTune: PreloadedTunes.getAlarmTuneById('zen_bell'),
        reminderTune: PreloadedTunes.getReminderTuneById('zen_bell'),
      ),
      IntervalAlarm(
        id: 'demo-meds',
        label: 'Stretch break',
        startTime: at(13, 0),
        endTime: at(17, 0),
        intervalMinutes: 60,
        reminderMinutesBefore: 2,
        alarmTune: PreloadedTunes.getAlarmTuneById('morning_bird'),
        reminderTune: PreloadedTunes.getReminderTuneById('gentle_chime'),
        activeDays: const [1, 3, 5],
        isEnabled: false,
      ),
    ]);
  }

  static Widget home() {
    switch (screen) {
      case 'create':
        return const CreateAlarmScreen();
      case 'detail':
        return const AlarmDetailScreen(alarmId: 'demo-focus');
      case 'tunes':
        return const MyTunesScreen();
      default:
        return const HomeScreen();
    }
  }
}
