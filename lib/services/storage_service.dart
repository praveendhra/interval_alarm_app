import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alarm_model.dart';

class StorageService {
  static const String _alarmsKey = 'interval_alarms';

  static Future<List<IntervalAlarm>> loadAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_alarmsKey);
    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((j) => IntervalAlarm.fromJson(j)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveAlarms(List<IntervalAlarm> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(alarms.map((a) => a.toJson()).toList());
    await prefs.setString(_alarmsKey, jsonString);
  }

  static Future<void> clearAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_alarmsKey);
  }
}
