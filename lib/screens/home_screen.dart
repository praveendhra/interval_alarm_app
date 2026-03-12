import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/alarm_provider.dart';
import '../models/alarm_model.dart';
import '../utils/theme.dart';
import '../utils/helpers.dart';
import '../widgets/alarm_card.dart';
import '../widgets/empty_state.dart';
import '../services/notification_service.dart';
import '../services/audio_service.dart';
import 'create_alarm_screen.dart';
import 'alarm_detail_screen.dart';
import 'my_tunes_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _now = DateTime.now();
        _colonVisible = !_colonVisible;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
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
            'INTERVAL',
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
                  // Opens notification settings — tap this once and set importance to HIGH
                  const MethodChannel('app_settings').invokeMethod('openNotificationSettings');
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: Colors.red,
                    size: 20,
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
                                  onDelete: () => _confirmDelete(alarm),
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

  void _confirmDelete(IntervalAlarm alarm) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Icon(Icons.delete_rounded, color: AppTheme.error, size: 40),
            const SizedBox(height: 16),
            Text('Delete "${alarm.label}"?', style: AppTheme.headlineLarge),
            const SizedBox(height: 8),
            Text(
              'This will cancel all scheduled rings and reminders.',
              style: AppTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: const BorderSide(color: AppTheme.cardBorder),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      context.read<AlarmProvider>().deleteAlarm(alarm.id);
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
