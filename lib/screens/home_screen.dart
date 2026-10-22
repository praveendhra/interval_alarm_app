import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/alarm_provider.dart';
import '../models/alarm_model.dart';
import '../utils/theme.dart';
import '../utils/helpers.dart';
import '../widgets/alarm_card.dart';
import '../widgets/empty_state.dart';
import '../services/notification_service.dart';
import '../services/audio_service.dart';
import '../services/ios_alarm_scheduler.dart';
import 'create_alarm_screen.dart';
import 'alarm_detail_screen.dart';
import 'my_tunes_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late Timer _timer;
  late DateTime _now;
  bool _colonVisible = true;

  static const _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  static const _months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _now = DateTime.now();
        _colonVisible = !_colonVisible;
      });
    });
    // Check on launch too (e.g. app opened via full-screen intent)
    WidgetsBinding.instance.addPostFrameCallback((_) => _stopIfRinging());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (Platform.isIOS) {
      // Top up the 64-notification window each time the app is opened.
      context.read<AlarmProvider>().rescheduleAll();
    } else {
      _stopIfRinging();
    }
  }

  Future<void> _stopIfRinging() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // flush background-isolate writes into main engine's cache
    if (prefs.containsKey('alarm_ringing_callback_id')) {
      // Guard: ignore if alarm just started (<3s) — fullScreenIntent notification
      // briefly pauses/resumes the app, which would otherwise kill the next ring
      // in sequence immediately after it starts.
      // Default to now so a missing timestamp is treated as age=0 (just started),
      // not age=epoch (which would bypass the guard entirely).
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final startMs = prefs.getInt('alarm_ring_start_ms') ?? nowMs;
      final ageMs = nowMs - startMs;
      if (ageMs < 3000) return;
      await prefs.setBool('alarm_stop_signal', true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Alarm stopped'),
            backgroundColor: AppTheme.cardDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnight,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(),
            _buildDigitalClock(),
            _buildNextRingBanner(),
            _buildIosLimitBanner(),
            _buildAlarmsList(),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'CADENCE',
            style: AppTheme.labelLarge.copyWith(
              fontSize: 11,
              letterSpacing: 5,
              color: AppTheme.textMuted,
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  if (Platform.isIOS) {
                    await openAppSettings();
                    return;
                  }
                  // Opens notification settings — tap this once and set importance to HIGH
                  const MethodChannel('app_settings').invokeMethod('openNotificationSettings');
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: AppTheme.textSecondary,
                    size: 20,
                    semanticLabel: 'Notification settings',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  await AudioService().playTune(PreloadedTunes.alarmTunes.first);
                  await NotificationService().showTestNotification();
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.accentAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(
                    Icons.volume_up_rounded,
                    color: AppTheme.accentAmber,
                    size: 20,
                    semanticLabel: 'Test alarm sound',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyTunesScreen()),
                ),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: const Icon(
                    Icons.library_music_rounded,
                    color: AppTheme.textSecondary,
                    size: 20,
                    semanticLabel: 'My tunes',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDigitalClock() {
    final rawHour = _now.hour;
    final hour = rawHour == 0 ? 12 : (rawHour > 12 ? rawHour - 12 : rawHour);
    final hourStr = hour.toString().padLeft(2, '0');
    final minute = _now.minute.toString().padLeft(2, '0');
    final second = _now.second.toString().padLeft(2, '0');
    final ampm = rawHour >= 12 ? 'PM' : 'AM';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date
          Text(
            '${_days[_now.weekday - 1]}  ·  ${_months[_now.month - 1]} ${_now.day}',
            style: AppTheme.labelLarge.copyWith(
              fontSize: 12,
              letterSpacing: 3,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          // Clock row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // HH:MM with gradient
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppTheme.accentOrange, AppTheme.accentAmber],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: Text(
                  '$hourStr${_colonVisible ? ':' : ' '}$minute',
                  style: AppTheme.timeLarge.copyWith(
                    fontSize: 82,
                    letterSpacing: -4,
                    height: 1,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // AM/PM + seconds column
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.accentOrange, AppTheme.accentAmber],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ampm,
                        style: AppTheme.labelLarge.copyWith(
                          fontSize: 11,
                          letterSpacing: 1,
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      second,
                      style: AppTheme.labelLarge.copyWith(
                        fontSize: 20,
                        letterSpacing: 1,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIosLimitBanner() {
    return ValueListenableBuilder<bool>(
      valueListenable: IosAlarmScheduler.needsAppOpen,
      builder: (_, show, __) {
        if (!show) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.accentAmber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppTheme.accentAmber, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'iPhone holds 64 upcoming alerts. Open the app daily to keep later rings scheduled.',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.accentAmber, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNextRingBanner() {
    return Consumer<AlarmProvider>(
      builder: (_, provider, __) {
        DateTime? nextRing;
        String? label;
        for (final alarm in provider.alarms) {
          if (!alarm.isEnabled) continue;
          final next = alarm.getNextRingTime();
          if (next != null && (nextRing == null || next.isBefore(nextRing))) {
            nextRing = next;
            label = alarm.label;
          }
        }

        if (nextRing == null) return const SizedBox(height: 12);

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.accentTeal.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accentTeal.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.notifications_active_rounded,
                  color: AppTheme.accentTeal,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Next: $label · ${TimeHelper.formatTimeShort(nextRing)}',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.accentTeal,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  TimeHelper.timeUntil(nextRing),
                  style: AppTheme.labelLarge.copyWith(
                    color: AppTheme.accentTeal,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlarmsList() {
    return Expanded(
      child: Consumer<AlarmProvider>(
        builder: (context, provider, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Row(
                  children: [
                    Text(
                      'MY ALARMS',
                      style: AppTheme.labelLarge.copyWith(
                        fontSize: 11,
                        letterSpacing: 3,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    if (provider.alarms.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accentOrange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.accentOrange.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          '${provider.activeCount} on',
                          style: AppTheme.labelLarge.copyWith(
                            fontSize: 10,
                            color: AppTheme.accentOrange,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // List or empty
              Expanded(
                child: provider.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppTheme.accentOrange),
                      )
                    : provider.alarms.isEmpty
                        ? const EmptyState()
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                            itemCount: provider.alarms.length,
                            itemBuilder: (context, index) {
                              final alarm = provider.alarms[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: AlarmCard(
                                  alarm: alarm,
                                  colorIndex: index,
                                  onTap: () => _openDetail(alarm),
                                  onToggle: () => provider.toggleAlarm(alarm.id),
                                ),
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFAB() {
    return GestureDetector(
      onTap: _createAlarm,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.accentOrange, AppTheme.accentAmber],
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentOrange.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, color: Colors.black, size: 22),
            const SizedBox(width: 6),
            Text(
              'NEW ALARM',
              style: AppTheme.labelLarge.copyWith(
                fontSize: 12,
                letterSpacing: 2,
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _createAlarm() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const CreateAlarmScreen(),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: animation, child: child),
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _openDetail(IntervalAlarm alarm) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AlarmDetailScreen(alarmId: alarm.id)),
    );
  }

}
