import 'package:flutter/material.dart';
import '../models/alarm_model.dart';
import '../utils/theme.dart';
import '../utils/helpers.dart';

class AlarmCard extends StatelessWidget {
  final IntervalAlarm alarm;
  final int colorIndex;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  const AlarmCard({
    super.key,
    required this.alarm,
    required this.colorIndex,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = AppTheme.getColor(colorIndex);
    final isActive = alarm.isEnabled;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isActive ? 1.0 : 0.45,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? accentColor.withOpacity(0.25)
                  : AppTheme.cardBorder,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: accentColor.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left accent bar
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: isActive ? accentColor : AppTheme.cardBorder,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
                  ),
                ),
                // Card content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Label row + toggle
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                alarm.label,
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Transform.scale(
                              scale: 0.8,
                              child: Switch(
                                value: isActive,
                                onChanged: (_) => onToggle(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Large time range
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _TimeChip(
                              time: alarm.startTime,
                              color: isActive ? AppTheme.textPrimary : AppTheme.textSecondary,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(
                                Icons.arrow_right_alt_rounded,
                                color: isActive ? accentColor : AppTheme.textMuted,
                                size: 18,
                              ),
                            ),
                            _TimeChip(
                              time: alarm.endTime,
                              color: isActive ? AppTheme.textPrimary : AppTheme.textSecondary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Info + days row
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _Pill(
                                  icon: Icons.repeat_rounded,
                                  text: TimeHelper.formatInterval(alarm.intervalMinutes),
                                  color: accentColor,
                                ),
                                _Pill(
                                  icon: Icons.notifications_outlined,
                                  text: '${alarm.totalRings}×',
                                  color: accentColor,
                                ),
                                if (alarm.reminderMinutesBefore > 0)
                                  _Pill(
                                    icon: Icons.access_time_rounded,
                                    text: '${alarm.reminderMinutesBefore}m',
                                    color: AppTheme.accentAmber,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _DayDots(alarm: alarm, accentColor: accentColor),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final DateTime time;
  final Color color;

  const _TimeChip({required this.time, required this.color});

  @override
  Widget build(BuildContext context) {
    final h = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final m = time.minute.toString().padLeft(2, '0');
    final ampm = time.hour >= 12 ? 'PM' : 'AM';
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$h:$m',
          style: AppTheme.timeLarge.copyWith(
            fontSize: 28,
            letterSpacing: -1,
            color: color,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          ampm,
          style: AppTheme.bodyMedium.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _Pill({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTheme.bodyMedium.copyWith(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayDots extends StatelessWidget {
  final IntervalAlarm alarm;
  final Color accentColor;

  const _DayDots({required this.alarm, required this.accentColor});

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    if (alarm.activeDays.length == 7) {
      return Text(
        'Every day',
        style: AppTheme.bodyMedium.copyWith(
          fontSize: 11,
          color: AppTheme.textMuted,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(7, (i) {
        final isOn = alarm.activeDays.contains(i + 1);
        return Container(
          margin: const EdgeInsets.only(left: 3),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: isOn ? accentColor.withOpacity(0.2) : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isOn ? accentColor.withOpacity(0.5) : AppTheme.cardBorder,
            ),
          ),
          child: Center(
            child: Text(
              _letters[i],
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: isOn ? accentColor : AppTheme.textMuted,
              ),
            ),
          ),
        );
      }),
    );
  }
}
