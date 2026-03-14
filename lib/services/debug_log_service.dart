import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLogKey = 'debug_logs_v1';
const _kMaxLogs = 300;

// Short alias used throughout the codebase
typedef DebugLog = DebugLogService;

class DebugLogService {
  static final DebugLogService _instance = DebugLogService._internal();
  factory DebugLogService() => _instance;
  DebugLogService._internal();

  /// Add a log entry. Category examples: 'SCHEDULE', 'CANCEL', 'CALLBACK', 'NOTIF', 'AUDIO', 'ERROR'
  static Future<void> log(String category, String message) async {
    final timestamp = DateTime.now().toIso8601String().substring(11, 23); // HH:mm:ss.mmm
    final entry = '[$timestamp] [$category] $message';
    debugPrint('🔔 $entry');
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kLogKey);
      final logs = raw != null ? (jsonDecode(raw) as List).cast<String>() : <String>[];
      logs.add(entry);
      // Keep only the last _kMaxLogs entries
      final trimmed = logs.length > _kMaxLogs ? logs.sublist(logs.length - _kMaxLogs) : logs;
      await prefs.setString(_kLogKey, jsonEncode(trimmed));
    } catch (_) {}
  }

  /// Read all stored logs (newest last)
  static Future<List<String>> getLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kLogKey);
      if (raw == null) return [];
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  /// Clear all logs
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLogKey);
  }
}
