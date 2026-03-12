import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TimeHelper {
  static String formatTime(DateTime time) {
    return DateFormat('hh:mm a').format(time);
  }

  static String formatTimeShort(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }

  static String formatDate(DateTime date) {
    return DateFormat('EEE, MMM d').format(date);
  }

  static String formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  static String formatInterval(int minutes) {
    if (minutes < 60) return 'Every $minutes min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return 'Every $hours hr';
    return 'Every ${hours}h ${mins}m';
  }

  static String dayName(int day) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[day - 1];
  }

  static String dayLetter(int day) {
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return letters[day - 1];
  }

  /// Build a DateTime for today at the given TimeOfDay
  static DateTime todayAt(TimeOfDay time) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, time.hour, time.minute);
  }

  /// Calculate remaining time until next ring (rounds up partial minutes)
  static String timeUntil(DateTime target) {
    final diff = target.difference(DateTime.now());
    if (diff.isNegative) return 'Passed';
    if (diff.inDays > 0) return 'in ${diff.inDays}d ${diff.inHours % 24}h';
    if (diff.inHours > 0) {
      final mins = (diff.inSeconds % 3600 / 60).ceil();
      return 'in ${diff.inHours}h ${mins}m';
    }
    if (diff.inSeconds > 0) {
      if (diff.inSeconds < 60) return 'in ${diff.inSeconds}s';
      final mins = (diff.inSeconds / 60).ceil();
      return 'in ${mins}m';
    }
    return 'now';
  }
}

class AlarmColors {
  static const List<Color> palette = [
    Color(0xFFFF6B35),
    Color(0xFF00D4AA),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFFFF4D6A),
    Color(0xFFFFAA33),
    Color(0xFF06B6D4),
    Color(0xFFEC4899),
  ];

  static Color getColor(int index) {
    return palette[index % palette.length];
  }
}
