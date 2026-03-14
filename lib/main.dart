import 'dart:io';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'providers/alarm_provider.dart';
import 'services/alarm_scheduler_service.dart';
import 'services/notification_service.dart';
import 'screens/home_screen.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Disable google_fonts network fetching — use only bundled/cached fonts.
  // Without this, it spams errors when the device has no internet.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppTheme.midnight,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Initialize the alarm manager (required before scheduling any alarms)
  await AndroidAlarmManager.initialize();

  // Copy tune assets to device storage so background isolates can play them
  await AlarmSchedulerService.copyTunesToStorage();

  // Initialize notifications (for visual banners)
  await NotificationService().initialize();
  await NotificationService().requestPermissions();

  if (Platform.isAndroid) {
    // SCHEDULE_EXACT_ALARM — without this, setAlarmClock() silently fails on
    // Android 12+. Opens the "Alarms & reminders" special-access settings page.
    final exactAlarmStatus = await Permission.scheduleExactAlarm.status;
    if (!exactAlarmStatus.isGranted) {
      await Permission.scheduleExactAlarm.request();
    }

    // Battery optimization exemption — critical for OEM phones (OnePlus, Xiaomi,
    // Samsung) that aggressively kill background processes.
    final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
    if (!batteryStatus.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }

    // Ensure alarm volume is audible — separate stream from ringer, can be 0.
    try {
      await const MethodChannel('app_settings').invokeMethod('ensureAlarmVolume');
    } catch (_) {}
  }

  runApp(const IntervalAlarmApp());
}

class IntervalAlarmApp extends StatelessWidget {
  const IntervalAlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AlarmProvider()..loadAlarms(),
      child: MaterialApp(
        title: 'Interval Alarm',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const HomeScreen(),
      ),
    );
  }
}
