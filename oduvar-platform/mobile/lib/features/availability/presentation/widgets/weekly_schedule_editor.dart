import 'package:flutter/material.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import '../../models/availability_model.dart';

/// Half-hour time options "00:00".."23:30". End times additionally allow 23:59.
List<String> timeOptions({bool includeEndOfDay = false}) => [
      for (var m = 0; m < 24 * 60; m += 30)
        '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}',
      if (includeEndOfDay) '23:59',
    ];

class TimeDropdown extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool isEnd;
  final bool hasError;

  const TimeDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.isEnd = false,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final options = timeOptions(includeEndOfDay: isEnd);
    if (!options.contains(value)) options.add(value);
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: hasError ? AppTheme.errorRed : AppTheme.sacredBorder),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          isDense: true,
          value: value,
          items: [
            for (final t in options) DropdownMenuItem(value: t, child: Text(formatTime12(t))),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

/// Weekly Schedule Editor: each day is edited independently; a day may have
/// several working windows (split shifts). Validation here is for immediate
/// feedback only — the backend is authoritative.
class WeeklyScheduleEditor extends StatelessWidget {
  final List<WeeklyAvailabilityModel> days;
  final ValueChanged<List<WeeklyAvailabilityModel>> onChanged;

  const WeeklyScheduleEditor({super.key, required this.days, required this.onChanged});

  void _update(int index, WeeklyAvailabilityModel day) {
    final next = [...days];
    next[index] = day;
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('weekly_schedule_editor'),
      children: [
        for (var i = 0; i < days.length; i++) _dayCard(i, days[i]),
      ],
    );
  }

  Widget _dayCard(int index, WeeklyAvailabilityModel day) {
    final name = day.dayOfWeek;
    return Container(
      key: Key('day_card_$name'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.sacredBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dayLabel(name),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.primaryMaroonDark),
                ),
              ),
              Text(
                day.isActive ? 'ON' : 'OFF',
                key: Key('day_state_$name'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: day.isActive ? AppTheme.successGreen : const Color(0xFF6B5E55),
                ),
              ),
              Switch(
                key: Key('day_switch_$name'),
                value: day.isActive,
                activeThumbColor: AppTheme.successGreen,
                onChanged: (on) {
                  if (on && day.windows.isEmpty) {
                    _update(index, day.copyWith(
                      isActive: true,
                      windows: const [TimeWindowModel(startTime: '09:00', endTime: '18:00')],
                    ));
                  } else {
                    _update(index, day.copyWith(isActive: on));
                  }
                },
              ),
            ],
          ),
          if (!day.isActive)
            const Text('Unavailable', style: TextStyle(fontSize: 13, color: Color(0xFF9B8E84)))
          else ...[
            for (var w = 0; w < day.windows.length; w++) _windowRow(index, day, w),
            if (!day.hasValidWindows)
              Padding(
                key: Key('day_error_$name'),
                padding: const EdgeInsets.only(top: 6),
                child: const Row(
                  children: [
                    Icon(Icons.error_outline, size: 16, color: AppTheme.errorRed),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Start time must be before end time, and windows must not overlap',
                        style: TextStyle(fontSize: 12, color: AppTheme.errorRed),
                      ),
                    ),
                  ],
                ),
              ),
            if (day.windows.length < 4)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: Key('add_window_$name'),
                  onPressed: () {
                    final last = day.windows.isEmpty ? null : day.windows.last;
                    final start = last != null && timeToMinutes(last.endTime) <= 20 * 60
                        ? _plus(last.endTime, 60)
                        : '17:00';
                    final end = _plus(start, 180);
                    _update(index, day.copyWith(
                      windows: [...day.windows, TimeWindowModel(startTime: start, endTime: end)],
                    ));
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add another window'),
                ),
              ),
          ],
        ],
      ),
    );
  }

  static String _plus(String t, int minutes) {
    final m = (timeToMinutes(t) + minutes).clamp(0, 23 * 60 + 30);
    final rounded = (m ~/ 30) * 30;
    return '${(rounded ~/ 60).toString().padLeft(2, '0')}:${(rounded % 60).toString().padLeft(2, '0')}';
  }

  Widget _windowRow(int index, WeeklyAvailabilityModel day, int w) {
    final win = day.windows[w];
    final name = day.dayOfWeek;
    void setWindow(TimeWindowModel nw) {
      final list = [...day.windows];
      list[w] = nw;
      _update(index, day.copyWith(windows: list));
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: TimeDropdown(
              key: Key('start_${name}_$w'),
              label: 'Start',
              value: win.startTime,
              hasError: !win.isValid,
              onChanged: (v) => setWindow(win.copyWith(startTime: v)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TimeDropdown(
              key: Key('end_${name}_$w'),
              label: 'End',
              value: win.endTime,
              isEnd: true,
              hasError: !win.isValid,
              onChanged: (v) => setWindow(win.copyWith(endTime: v)),
            ),
          ),
          if (day.windows.length > 1)
            IconButton(
              key: Key('remove_window_${name}_$w'),
              tooltip: 'Remove window',
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                final list = [...day.windows]..removeAt(w);
                _update(index, day.copyWith(windows: list));
              },
            ),
        ],
      ),
    );
  }
}
