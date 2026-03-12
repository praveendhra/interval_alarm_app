import 'dart:convert';

class AlarmTune {
  final String id;
  final String name;
  final String assetPath;
  final bool isCustom; // true = user-imported MP3 from device storage
  final String? originalFileName; // original file name for display

  const AlarmTune({
    required this.id,
    required this.name,
    required this.assetPath,
    this.isCustom = false,
    this.originalFileName,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'assetPath': assetPath,
        'isCustom': isCustom,
        'originalFileName': originalFileName,
      };

  factory AlarmTune.fromJson(Map<String, dynamic> json) => AlarmTune(
        id: json['id'],
        name: json['name'],
        assetPath: json['assetPath'],
        isCustom: json['isCustom'] ?? false,
        originalFileName: json['originalFileName'],
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AlarmTune && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// Preloaded tunes bundled with the app (5 generated tunes)
class PreloadedTunes {
  static const List<AlarmTune> alarmTunes = [
    AlarmTune(
      id: 'gentle_chime',
      name: 'Gentle Chime',
      assetPath: 'assets/tunes/gentle_chime.mp3',
    ),
    AlarmTune(
      id: 'morning_bird',
      name: 'Morning Bird',
      assetPath: 'assets/tunes/morning_bird.mp3',
    ),
    AlarmTune(
      id: 'digital_pulse',
      name: 'Digital Pulse',
      assetPath: 'assets/tunes/digital_pulse.mp3',
    ),
    AlarmTune(
      id: 'zen_bell',
      name: 'Zen Bell',
      assetPath: 'assets/tunes/zen_bell.mp3',
    ),
    AlarmTune(
      id: 'classic_alarm',
      name: 'Classic Alarm',
      assetPath: 'assets/tunes/classic_alarm.mp3',
    ),
  ];

  // Reminders reuse the same 5 tunes — softer ones listed first
  static const List<AlarmTune> reminderTunes = [
    AlarmTune(
      id: 'gentle_chime',
      name: 'Gentle Chime',
      assetPath: 'assets/tunes/gentle_chime.mp3',
    ),
    AlarmTune(
      id: 'zen_bell',
      name: 'Zen Bell',
      assetPath: 'assets/tunes/zen_bell.mp3',
    ),
    AlarmTune(
      id: 'morning_bird',
      name: 'Morning Bird',
      assetPath: 'assets/tunes/morning_bird.mp3',
    ),
    AlarmTune(
      id: 'digital_pulse',
      name: 'Digital Pulse',
      assetPath: 'assets/tunes/digital_pulse.mp3',
    ),
    AlarmTune(
      id: 'classic_alarm',
      name: 'Classic Alarm',
      assetPath: 'assets/tunes/classic_alarm.mp3',
    ),
  ];

  static AlarmTune getAlarmTuneById(String id) {
    return alarmTunes.firstWhere(
      (t) => t.id == id,
      orElse: () => alarmTunes.first,
    );
  }

  static AlarmTune getReminderTuneById(String id) {
    return reminderTunes.firstWhere(
      (t) => t.id == id,
      orElse: () => reminderTunes.first,
    );
  }
}

class IntervalAlarm {
  final String id;
  final String label;
  final DateTime startTime;
  final DateTime endTime;
  final int intervalMinutes;
  final int reminderMinutesBefore;
  final AlarmTune alarmTune;
  final AlarmTune reminderTune;
  final bool isEnabled;
  final List<int> activeDays; // 1=Mon, 7=Sun
  final DateTime createdAt;

  IntervalAlarm({
    required this.id,
    required this.label,
    required this.startTime,
    required this.endTime,
    required this.intervalMinutes,
    required this.reminderMinutesBefore,
    required this.alarmTune,
    required this.reminderTune,
    this.isEnabled = true,
    this.activeDays = const [1, 2, 3, 4, 5, 6, 7],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Calculate all ring times from start to end (inclusive)
  List<DateTime> getRingTimes() {
    final List<DateTime> times = [];
    DateTime current = startTime;
    while (current.isBefore(endTime) || current.isAtSameMomentAs(endTime)) {
      times.add(current);
      current = current.add(Duration(minutes: intervalMinutes));
    }
    // Ensure end time is included if not already
    if (times.isEmpty || !times.last.isAtSameMomentAs(endTime)) {
      times.add(endTime);
    }
    return times;
  }

  /// Calculate all reminder times (reminderMinutesBefore each ring)
  List<DateTime> getReminderTimes() {
    if (reminderMinutesBefore <= 0) return [];
    return getRingTimes()
        .map((t) => t.subtract(Duration(minutes: reminderMinutesBefore)))
        .where((t) => t.isAfter(DateTime.now().subtract(const Duration(minutes: 1))))
        .toList();
  }

  /// Get total number of rings
  int get totalRings => getRingTimes().length;

  /// Get next upcoming ring time across the next 7 days
  DateTime? getNextRingTime() {
    final now = DateTime.now();
    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      final date = now.add(Duration(days: dayOffset));
      if (!activeDays.contains(date.weekday)) continue;

      final start = DateTime(date.year, date.month, date.day,
          startTime.hour, startTime.minute);
      var end = DateTime(date.year, date.month, date.day,
          endTime.hour, endTime.minute);
      if (end.isBefore(start)) end = end.add(const Duration(days: 1));

      DateTime current = start;
      while (!current.isAfter(end)) {
        if (current.isAfter(now)) return current;
        current = current.add(Duration(minutes: intervalMinutes));
      }
    }
    return null;
  }

  IntervalAlarm copyWith({
    String? id,
    String? label,
    DateTime? startTime,
    DateTime? endTime,
    int? intervalMinutes,
    int? reminderMinutesBefore,
    AlarmTune? alarmTune,
    AlarmTune? reminderTune,
    bool? isEnabled,
    List<int>? activeDays,
  }) {
    return IntervalAlarm(
      id: id ?? this.id,
      label: label ?? this.label,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      reminderMinutesBefore: reminderMinutesBefore ?? this.reminderMinutesBefore,
      alarmTune: alarmTune ?? this.alarmTune,
      reminderTune: reminderTune ?? this.reminderTune,
      isEnabled: isEnabled ?? this.isEnabled,
      activeDays: activeDays ?? this.activeDays,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'intervalMinutes': intervalMinutes,
        'reminderMinutesBefore': reminderMinutesBefore,
        'alarmTune': alarmTune.toJson(),
        'reminderTune': reminderTune.toJson(),
        'isEnabled': isEnabled,
        'activeDays': activeDays,
        'createdAt': createdAt.toIso8601String(),
      };

  factory IntervalAlarm.fromJson(Map<String, dynamic> json) => IntervalAlarm(
        id: json['id'],
        label: json['label'],
        startTime: DateTime.parse(json['startTime']),
        endTime: DateTime.parse(json['endTime']),
        intervalMinutes: json['intervalMinutes'],
        reminderMinutesBefore: json['reminderMinutesBefore'],
        alarmTune: AlarmTune.fromJson(json['alarmTune']),
        reminderTune: AlarmTune.fromJson(json['reminderTune']),
        isEnabled: json['isEnabled'] ?? true,
        activeDays: List<int>.from(json['activeDays'] ?? [1, 2, 3, 4, 5, 6, 7]),
        createdAt: DateTime.parse(json['createdAt']),
      );

  String toJsonString() => jsonEncode(toJson());

  factory IntervalAlarm.fromJsonString(String jsonString) =>
      IntervalAlarm.fromJson(jsonDecode(jsonString));
}
