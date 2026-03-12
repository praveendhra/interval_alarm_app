import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../models/alarm_model.dart';
import '../providers/alarm_provider.dart';
import '../utils/theme.dart';
import '../utils/helpers.dart';
import '../widgets/tune_picker.dart';

class CreateAlarmScreen extends StatefulWidget {
  final IntervalAlarm? existingAlarm;

  const CreateAlarmScreen({super.key, this.existingAlarm});

  @override
  State<CreateAlarmScreen> createState() => _CreateAlarmScreenState();
}

class _CreateAlarmScreenState extends State<CreateAlarmScreen> {
  late TextEditingController _labelController;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late int _intervalMinutes;
  late int _reminderMinutes;
  late AlarmTune _alarmTune;
  late AlarmTune _reminderTune;
  late List<int> _activeDays;

  bool get isEditing => widget.existingAlarm != null;

  // Interval options in minutes
  static const List<int> intervalOptions = [
    1, 2, 3, 5, 10, 15, 20, 30, 45, 60, 90, 120
  ];

  // Reminder options in minutes
  static const List<int> reminderOptions = [0, 1, 2, 3, 5, 10, 15, 20, 30];

  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    final alarm = widget.existingAlarm;

    _labelController = TextEditingController(
      text: alarm?.label ?? '',
    );
    _startTime = alarm != null
        ? TimeOfDay.fromDateTime(alarm.startTime)
        : const TimeOfDay(hour: 8, minute: 0);
    _endTime = alarm != null
        ? TimeOfDay.fromDateTime(alarm.endTime)
        : const TimeOfDay(hour: 17, minute: 0);
    _intervalMinutes = alarm?.intervalMinutes ?? 30;
    _reminderMinutes = alarm?.reminderMinutesBefore ?? 5;
    _alarmTune = alarm?.alarmTune ?? PreloadedTunes.alarmTunes.first;
    _reminderTune = alarm?.reminderTune ?? PreloadedTunes.reminderTunes.first;
    _activeDays = alarm?.activeDays ?? [1, 2, 3, 4, 5, 6, 7];
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Edit Alarm' : 'New Alarm',
          style: AppTheme.displayMedium.copyWith(fontSize: 20),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              'Save',
              style: AppTheme.headlineMedium.copyWith(
                color: AppTheme.accentOrange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Label ────────────────────────────────────
            _buildSection(
              'LABEL',
              _buildLabelInput(),
            ),

            // ── Time Selection ───────────────────────────
            _buildSection(
              'TIME WINDOW',
              _buildTimeSelection(),
            ),

            // ── Interval ─────────────────────────────────
            _buildSection(
              'INTERVAL',
              _buildIntervalPicker(),
            ),

            // ── Preview ──────────────────────────────────
            _buildSection(
              'SCHEDULE PREVIEW',
              _buildSchedulePreview(),
            ),

            // ── Reminder ─────────────────────────────────
            _buildSection(
              'REMINDER BEFORE EACH RING',
              _buildReminderPicker(),
            ),

            // ── Days ─────────────────────────────────────
            _buildSection(
              'ACTIVE DAYS',
              _buildDaySelector(),
            ),

            // ── Alarm Tune ───────────────────────────────
            _buildSection(
              '',
              TunePicker(
                title: 'Alarm Tune',
                tunes: PreloadedTunes.alarmTunes,
                selectedTune: _alarmTune,
                onSelected: (tune) => setState(() => _alarmTune = tune),
              ),
            ),

            // ── Reminder Tune ────────────────────────────
            _buildSection(
              '',
              TunePicker(
                title: 'Reminder Tune',
                tunes: PreloadedTunes.reminderTunes,
                selectedTune: _reminderTune,
                onSelected: (tune) => setState(() => _reminderTune = tune),
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty) ...[
            Text(label, style: AppTheme.labelLarge),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }

  // ── Label Input ──────────────────────────────────────────────
  Widget _buildLabelInput() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: TextField(
        controller: _labelController,
        style: AppTheme.headlineLarge.copyWith(fontSize: 18),
        decoration: InputDecoration(
          hintText: 'e.g. Medicine Reminder, Study Timer...',
          hintStyle: AppTheme.bodyLarge.copyWith(color: AppTheme.textMuted),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(18),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 16, right: 8),
            child: Icon(Icons.label_rounded, color: AppTheme.accentOrange, size: 22),
          ),
        ),
      ),
    );
  }

  // ── Time Selection ───────────────────────────────────────────
  Widget _buildTimeSelection() {
    return Row(
      children: [
        Expanded(
          child: _TimePickerCard(
            label: 'Start',
            time: _startTime,
            color: AppTheme.accentTeal,
            onTap: () => _pickTime(true),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Icon(Icons.arrow_forward_rounded, color: AppTheme.textMuted),
        ),
        Expanded(
          child: _TimePickerCard(
            label: 'End',
            time: _endTime,
            color: AppTheme.accentRose,
            onTap: () => _pickTime(false),
          ),
        ),
      ],
    );
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.accentOrange,
              surface: AppTheme.cardDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  // ── Interval Picker ──────────────────────────────────────────
  Widget _buildIntervalPicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: intervalOptions.map((minutes) {
        final isSelected = _intervalMinutes == minutes;
        return GestureDetector(
          onTap: () => setState(() => _intervalMinutes = minutes),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.accentOrange.withOpacity(0.15)
                  : AppTheme.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppTheme.accentOrange
                    : AppTheme.cardBorder,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Text(
              TimeHelper.formatDuration(minutes),
              style: AppTheme.headlineMedium.copyWith(
                color: isSelected
                    ? AppTheme.accentOrange
                    : AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Schedule Preview ─────────────────────────────────────────
  Widget _buildSchedulePreview() {
    final startDt = TimeHelper.todayAt(_startTime);
    final endDt = TimeHelper.todayAt(_endTime);

    // Handle overnight
    final adjustedEnd = endDt.isBefore(startDt)
        ? endDt.add(const Duration(days: 1))
        : endDt;

    final tempAlarm = IntervalAlarm(
      id: 'preview',
      label: 'Preview',
      startTime: startDt,
      endTime: adjustedEnd,
      intervalMinutes: _intervalMinutes,
      reminderMinutesBefore: _reminderMinutes,
      alarmTune: _alarmTune,
      reminderTune: _reminderTune,
    );

    final ringTimes = tempAlarm.getRingTimes();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceGlow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded,
                  color: AppTheme.accentAmber, size: 18),
              const SizedBox(width: 8),
              Text(
                '${ringTimes.length} rings total',
                style: AppTheme.headlineMedium.copyWith(
                  color: AppTheme.accentAmber,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ringTimes.take(20).map((time) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Text(
                  TimeHelper.formatTimeShort(time),
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontFamily: 'SpaceMono',
                  ),
                ),
              );
            }).toList(),
          ),
          if (ringTimes.length > 20) ...[
            const SizedBox(height: 8),
            Text(
              '+ ${ringTimes.length - 20} more rings',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Reminder Picker ──────────────────────────────────────────
  Widget _buildReminderPicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: reminderOptions.map((minutes) {
        final isSelected = _reminderMinutes == minutes;
        final label = minutes == 0 ? 'None' : '${minutes}m before';
        return GestureDetector(
          onTap: () => setState(() => _reminderMinutes = minutes),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.accentTeal.withOpacity(0.15)
                  : AppTheme.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppTheme.accentTeal
                    : AppTheme.cardBorder,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Text(
              label,
              style: AppTheme.headlineMedium.copyWith(
                color: isSelected
                    ? AppTheme.accentTeal
                    : AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Day Selector ─────────────────────────────────────────────
  Widget _buildDaySelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final day = i + 1;
        final isActive = _activeDays.contains(day);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isActive && _activeDays.length > 1) {
                _activeDays.remove(day);
              } else if (!isActive) {
                _activeDays.add(day);
                _activeDays.sort();
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isActive
                  ? AppTheme.accentPurple.withOpacity(0.2)
                  : AppTheme.cardDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isActive
                    ? AppTheme.accentPurple
                    : AppTheme.cardBorder,
                width: isActive ? 1.5 : 1,
              ),
            ),
            child: Center(
              child: Text(
                TimeHelper.dayName(day),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? AppTheme.accentPurple
                      : AppTheme.textMuted,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ── Save ─────────────────────────────────────────────────────
  void _save() {
    final label = _labelController.text.trim();
    if (label.isEmpty) {
      _showError('Please enter a label for your alarm.');
      return;
    }

    final startDt = TimeHelper.todayAt(_startTime);
    var endDt = TimeHelper.todayAt(_endTime);

    // Handle overnight
    if (endDt.isBefore(startDt) || endDt.isAtSameMomentAs(startDt)) {
      endDt = endDt.add(const Duration(days: 1));
    }

    final alarm = IntervalAlarm(
      id: widget.existingAlarm?.id ?? '',
      label: label,
      startTime: startDt,
      endTime: endDt,
      intervalMinutes: _intervalMinutes,
      reminderMinutesBefore: _reminderMinutes,
      alarmTune: _alarmTune,
      reminderTune: _reminderTune,
      activeDays: _activeDays,
    );

    final provider = context.read<AlarmProvider>();

    if (isEditing) {
      provider.updateAlarm(alarm);
    } else {
      provider.addAlarm(alarm);
    }

    Navigator.pop(context);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ── Time Picker Card Widget ─────────────────────────────────────
class _TimePickerCard extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final Color color;
  final VoidCallback onTap;

  const _TimePickerCard({
    required this.label,
    required this.time,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: AppTheme.labelLarge.copyWith(
                color: color,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                  style: AppTheme.timeMedium.copyWith(color: color),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    period,
                    style: AppTheme.bodyMedium.copyWith(
                      color: color.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
