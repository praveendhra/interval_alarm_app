import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/alarm_provider.dart';
import 'services/alarm_scheduler_service.dart';
import 'services/notification_service.dart';
import 'screens/home_screen.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
