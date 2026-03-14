import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/alarm_model.dart';
import '../providers/alarm_provider.dart';
import '../utils/theme.dart';
import '../utils/helpers.dart';
import 'create_alarm_screen.dart';

class AlarmDetailScreen extends StatelessWidget {
  final String alarmId;

  const AlarmDetailScreen({super.key, required this.alarmId});

  void _confirmDelete(BuildContext context, AlarmProvider provider, IntervalAlarm alarm) {
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      provider.deleteAlarm(alarm.id);
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  @override
  Widget build(BuildContext context) {
    return Consumer<AlarmProvider>(
      builder: (context, provider, _) {
        final alarm = provider.getAlarm(alarmId);
        if (alarm == null) {
          return Scaffold(
            backgroundColor: AppTheme.midnight,
            appBar: AppBar(backgroundColor: Colors.transparent),
            body: const Center(child: Text('Alarm not found')),
          );
        }

        final ringTimes = alarm.getRingTimes();
        final nextRing = alarm.getNextRingTime();

        return Scaffold(
          backgroundColor: AppTheme.midnight,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(alarm.label, style: AppTheme.displayMedium.copyWith(fontSize: 20)),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
                onPressed: () => _confirmDelete(context, provider, alarm),
              ),
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: AppTheme.accentOrange),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateAlarmScreen(existingAlarm: alarm),
                    ),
                  );
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Status Card ──────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: AppTheme.glowCard(
                    alarm.isEnabled ? AppTheme.accentTeal : AppTheme.textMuted,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        alarm.isEnabled
                            ? Icons.alarm_on_rounded
                            : Icons.alarm_off_rounded,
                        size: 48,
                        color: alarm.isEnabled
                            ? AppTheme.accentTeal
                            : AppTheme.textMuted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        alarm.isEnabled ? 'Active' : 'Inactive',
                        style: AppTheme.headlineLarge.copyWith(
                          color: alarm.isEnabled
                              ? AppTheme.accentTeal
                              : AppTheme.textMuted,
                        ),
                      ),
                      if (nextRing != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Next ring ${TimeHelper.timeUntil(nextRing)}',
                          style: AppTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 16),
                      Switch(
                        value: alarm.isEnabled,
                        onChanged: (_) => provider.toggleAlarm(alarm.id),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Time Info ────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _DetailCard(
                        label: 'Start',
                        value: TimeHelper.formatTime(alarm.startTime),
                        icon: Icons.play_circle_outline_rounded,
                        color: AppTheme.accentTeal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DetailCard(
                        label: 'End',
                        value: TimeHelper.formatTime(alarm.endTime),
                        icon: Icons.stop_circle_outlined,
                        color: AppTheme.accentRose,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _DetailCard(
                        label: 'Interval',
                        value: TimeHelper.formatDuration(alarm.intervalMinutes),
                        icon: Icons.repeat_rounded,
                        color: AppTheme.accentOrange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DetailCard(
                        label: 'Reminder',
                        value: alarm.reminderMinutesBefore > 0
                            ? '${alarm.reminderMinutesBefore}m before'
                            : 'Off',
                        icon: Icons.notifications_outlined,
                        color: AppTheme.accentAmber,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Tunes ────────────────────────────────
                _buildInfoRow(
                  'Alarm Tune',
                  alarm.alarmTune.name,
                  Icons.music_note_rounded,
                  AppTheme.accentPurple,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Reminder Tune',
                  alarm.reminderTune.name,
                  Icons.music_note_outlined,
                  AppTheme.accentBlue,
                ),

                const SizedBox(height: 24),

                // ── Ring Timeline ────────────────────────
                Text('ALL RINGS', style: AppTheme.labelLarge),
                const SizedBox(height: 12),

                ...ringTimes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final time = entry.value;
                  final isPast = time.isBefore(DateTime.now());
                  final isNext = nextRing != null &&
                      time.isAtSameMomentAs(nextRing);

                  return _RingTimelineItem(
                    index: index + 1,
                    time: time,
                    isPast: isPast,
                    isNext: isNext,
                    hasReminder: alarm.reminderMinutesBefore > 0,
                    reminderMinutes: alarm.reminderMinutesBefore,
                    isLast: index == ringTimes.length - 1,
                  );
                }),

                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(label, style: AppTheme.bodyMedium),
          const Spacer(),
          Text(
            value,
            style: AppTheme.headlineMedium.copyWith(fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _DetailCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(
            label.toUpperCase(),
            style: AppTheme.labelLarge.copyWith(
              color: color,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTheme.timeMedium.copyWith(
              fontSize: 20,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingTimelineItem extends StatelessWidget {
  final int index;
  final DateTime time;
  final bool isPast;
  final bool isNext;
  final bool hasReminder;
  final int reminderMinutes;
  final bool isLast;

  const _RingTimelineItem({
    required this.index,
    required this.time,
    required this.isPast,
    required this.isNext,
    required this.hasReminder,
    required this.reminderMinutes,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = isNext
        ? AppTheme.accentOrange
        : isPast
            ? AppTheme.textMuted
            : AppTheme.textSecondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline dot + line
        SizedBox(
          width: 32,
          child: Column(
            children: [
              Container(
                width: isNext ? 14 : 10,
                height: isNext ? 14 : 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isNext ? AppTheme.accentOrange : color.withOpacity(0.5),
                  boxShadow: isNext
                      ? [
                          BoxShadow(
                            color: AppTheme.accentOrange.withOpacity(0.5),
                            blurRadius: 10,
                          )
                        ]
                      : null,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 40,
                  color: AppTheme.cardBorder,
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // Ring info
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Text(
                  'Ring $index',
                  style: AppTheme.bodyMedium.copyWith(
                    color: color,
                    fontWeight: isNext ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                const Spacer(),
                if (hasReminder)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentAmber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '🔔 ${TimeHelper.formatTimeShort(time.subtract(Duration(minutes: reminderMinutes)))}',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.accentAmber.withOpacity(0.8),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  TimeHelper.formatTimeShort(time),
                  style: AppTheme.headlineMedium.copyWith(
                    color: color,
                    fontSize: 15,
                    fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (isPast) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.check_circle, size: 16, color: AppTheme.success),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
