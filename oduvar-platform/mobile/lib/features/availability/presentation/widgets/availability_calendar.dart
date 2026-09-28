import 'package:flutter/material.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import '../../models/availability_model.dart';

const List<String> kMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String monthKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

String dateKey(DateTime d) => '${monthKey(d)}-${d.day.toString().padLeft(2, '0')}';

/// "2026-10-20" -> "October 20"
String formatDateShort(String date) =>
    '${kMonthNames[int.parse(date.substring(5, 7)) - 1]} ${int.parse(date.substring(8, 10))}';

/// "2026-10-20" -> "October 20, 2026"
String formatDateLong(String date) => '${formatDateShort(date)}, ${date.substring(0, 4)}';

/// Month-grid calendar. Status is always supplied by the backend (never derived
/// here). Status is conveyed by icon + label as well as colour.
///
/// PENDING / BOOKED are supported visually for the future booking phase and
/// only appear if the backend returns them.
class AvailabilityCalendar extends StatelessWidget {
  final DateTime month; // any date in the month being shown
  final List<CalendarDayModel> days;
  final String? selectedDate;
  final bool loading;

  /// If true only AVAILABLE days can be tapped (client booking flow).
  final bool onlyAvailableSelectable;
  final ValueChanged<String> onSelectDate;
  final ValueChanged<DateTime> onMonthChanged;
  final DateTime? earliestMonth;

  const AvailabilityCalendar({
    super.key,
    required this.month,
    required this.days,
    required this.onSelectDate,
    required this.onMonthChanged,
    this.selectedDate,
    this.loading = false,
    this.onlyAvailableSelectable = false,
    this.earliestMonth,
  });

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final count = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1; // Monday-first grid
    final status = {for (final d in days) d.date: d.status};
    final canGoBack = earliestMonth == null ||
        first.isAfter(DateTime(earliestMonth!.year, earliestMonth!.month, 1));

    final cells = <Widget>[
      for (var i = 0; i < leading; i++) const SizedBox.shrink(),
      for (var d = 1; d <= count; d++)
        _cell(DateTime(month.year, month.month, d), status),
    ];
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }

    return Container(
      key: const Key('availability_calendar'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.sacredBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('calendar_prev_month'),
                tooltip: 'Previous month',
                onPressed: canGoBack ? () => onMonthChanged(DateTime(month.year, month.month - 1, 1)) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${kMonthNames[month.month - 1]} ${month.year}',
                  key: const Key('calendar_month_title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primaryMaroonDark),
                ),
              ),
              IconButton(
                key: const Key('calendar_next_month'),
                tooltip: 'Next month',
                onPressed: () => onMonthChanged(DateTime(month.year, month.month + 1, 1)),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Row(
            children: [
              for (final d in const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
                Expanded(
                  child: Center(
                    child: Text(d,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF9B8E84))),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(
                  key: Key('calendar_loading'), color: AppTheme.primaryMaroon),
            )
          else
            for (var r = 0; r < cells.length ~/ 7; r++)
              Row(children: [for (var c = 0; c < 7; c++) Expanded(child: cells[r * 7 + c])]),
          const SizedBox(height: 10),
          _legend(),
        ],
      ),
    );
  }

  Widget _cell(DateTime date, Map<String, DayStatus> status) {
    final key = dateKey(date);
    final s = status[key];
    final selected = key == selectedDate;
    final style = _styleFor(s);
    final tappable = s != null && (!onlyAvailableSelectable || s == DayStatus.available);

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Semantics(
        label: '${formatDateShort(key)}, ${style.label}',
        button: tappable,
        child: InkWell(
          key: Key('cal_day_$key'),
          borderRadius: BorderRadius.circular(10),
          onTap: tappable ? () => onSelectDate(key) : null,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: style.bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? AppTheme.primaryMaroon : style.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${date.day}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: style.fg)),
                if (s != null) Icon(style.icon, size: 12, color: style.fg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _legend() {
    Widget item(DayStatus s) {
      final st = _styleFor(s);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(st.icon, size: 14, color: st.fg),
          const SizedBox(width: 4),
          Text(st.label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B5E55))),
        ],
      );
    }

    return Wrap(
      key: const Key('calendar_legend'),
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 4,
      children: [item(DayStatus.available), item(DayStatus.unavailable)],
    );
  }

  _DayStyle _styleFor(DayStatus? s) {
    switch (s) {
      case DayStatus.available:
        return const _DayStyle(Color(0xFFE7F4EA), AppTheme.successGreen, AppTheme.successGreen,
            Icons.check_circle_outline, 'Available');
      case DayStatus.pending:
        return const _DayStyle(Color(0xFFFEF3C7), AppTheme.warningOrange, AppTheme.warningOrange,
            Icons.hourglass_empty, 'Pending');
      case DayStatus.booked:
        return const _DayStyle(Color(0xFFDBEAFE), AppTheme.infoBlue, AppTheme.infoBlue,
            Icons.event_busy, 'Booked');
      case DayStatus.unavailable:
        return const _DayStyle(Color(0xFFF1EDE8), Color(0xFF6B5E55), AppTheme.sacredBorder,
            Icons.block, 'Unavailable');
      case null:
        return const _DayStyle(Colors.white, Color(0xFF9B8E84), AppTheme.sacredBorder,
            Icons.circle_outlined, '');
    }
  }
}

class _DayStyle {
  final Color bg;
  final Color fg;
  final Color border;
  final IconData icon;
  final String label;
  const _DayStyle(this.bg, this.fg, this.border, this.icon, this.label);
}

/// Duration selector: shows only durations the Oduvar allows.
class DurationSelector extends StatelessWidget {
  final List<int> options;
  final int? selected;
  final ValueChanged<int> onChanged;

  const DurationSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('duration_selector'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Duration',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primaryMaroonDark)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in options)
              ChoiceChip(
                key: Key('duration_$d'),
                label: Text(durationLabel(d)),
                selected: d == selected,
                selectedColor: AppTheme.primaryMaroon.withAlpha(30),
                onSelected: (_) => onChanged(d),
              ),
          ],
        ),
      ],
    );
  }
}

/// Bookable start times, exactly as returned by the backend.
class SlotList extends StatelessWidget {
  final DayAvailabilityModel? day;
  final bool loading;
  final String? selectedSlot;
  final ValueChanged<String>? onSelectSlot;

  const SlotList({
    super.key,
    required this.day,
    this.loading = false,
    this.selectedSlot,
    this.onSelectSlot,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(key: Key('slots_loading'), color: AppTheme.primaryMaroon),
        ),
      );
    }
    final d = day;
    if (d == null) return const SizedBox.shrink();

    return Column(
      key: const Key('slot_list'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(formatDateShort(d.date),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primaryMaroonDark)),
        if (d.workingWindows.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('Working hours: ${d.workingWindows.map((w) => w.label).join(', ')}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B5E55))),
          ),
        const SizedBox(height: 10),
        if (d.slots.isEmpty)
          const Row(
            key: Key('no_slots'),
            children: [
              Icon(Icons.block, size: 16, color: Color(0xFF6B5E55)),
              SizedBox(width: 6),
              Expanded(
                child: Text('No available times for this date and duration',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B5E55))),
              ),
            ],
          )
        else ...[
          const Text('Available times',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B5E55))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in d.slots)
                ChoiceChip(
                  key: Key('slot_$s'),
                  label: Text(formatTime12(s)),
                  selected: s == selectedSlot,
                  selectedColor: AppTheme.primaryMaroon.withAlpha(30),
                  onSelected: onSelectSlot == null ? null : (_) => onSelectSlot!(s),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
