import 'package:flutter/material.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import 'availability_state.dart';
import 'widgets/availability_calendar.dart';
import 'widgets/availability_status_views.dart';

/// Client-facing availability: Duration → date → backend-generated start times.
/// Designed to be embedded in the future booking flow ([onSlotSelected]); it
/// never creates a booking and never computes availability locally.
class PublicAvailabilityScreen extends StatefulWidget {
  final String oduvarId;
  final AvailabilityState availabilityState;
  final DateTime? initialMonth;

  /// Restrict the durations offered (e.g. to a selected service's priced durations).
  /// Defaults to the Oduvar's min..max in 30-minute steps.
  final List<int>? durationOptions;
  final void Function(String date, String time, int durationMinutes)? onSlotSelected;

  const PublicAvailabilityScreen({
    super.key,
    required this.oduvarId,
    required this.availabilityState,
    this.initialMonth,
    this.durationOptions,
    this.onSlotSelected,
  });

  @override
  State<PublicAvailabilityScreen> createState() => _PublicAvailabilityScreenState();
}

class _PublicAvailabilityScreenState extends State<PublicAvailabilityScreen> {
  late DateTime _month;
  int? _duration;
  String? _selectedDate;
  String? _selectedSlot;

  @override
  void initState() {
    super.initState();
    final base = widget.initialMonth ?? DateTime.now();
    _month = DateTime(base.year, base.month, 1);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    await widget.availabilityState.load(oduvarId: widget.oduvarId);
    if (!mounted || widget.availabilityState.status != AvailabilityStatus.loaded) return;
    final opts = _options;
    setState(() => _duration = opts.isEmpty ? null : opts.first);
    await _loadMonth();
  }

  List<int> get _options {
    final rules = widget.availabilityState.rules;
    final all = widget.durationOptions ?? rules.durationOptions;
    return all
        .where((d) => d >= rules.minimumDurationMinutes && d <= rules.maximumDurationMinutes)
        .toList();
  }

  Future<void> _loadMonth() => widget.availabilityState.loadMonth(
        oduvarId: widget.oduvarId,
        month: monthKey(_month),
        durationMinutes: _duration,
      );

  Future<void> _selectDate(String date) async {
    setState(() {
      _selectedDate = date;
      _selectedSlot = null;
    });
    await widget.availabilityState.loadDay(
      oduvarId: widget.oduvarId,
      date: date,
      durationMinutes: _duration,
    );
  }

  Future<void> _changeDuration(int d) async {
    setState(() {
      _duration = d;
      _selectedSlot = null;
    });
    widget.availabilityState.clearMonths();
    await _loadMonth();
    if (_selectedDate != null) await _selectDate(_selectedDate!);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.availabilityState,
      builder: (context, _) {
        final state = widget.availabilityState;
        return Scaffold(
          backgroundColor: AppTheme.sacredCream,
          appBar: AppBar(title: const Text('Availability'), backgroundColor: AppTheme.sacredSurface),
          body: _body(state),
        );
      },
    );
  }

  Widget _body(AvailabilityState state) {
    if (state.isLoading) return const AvailabilityLoadingView();
    if (state.status == AvailabilityStatus.error) {
      return AvailabilityErrorView(
        message: state.errorMessage ?? 'Failed to load availability',
        kind: state.errorKind,
        onRetry: _init,
      );
    }
    final key = monthKey(_month);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DurationSelector(options: _options, selected: _duration, onChanged: _changeDuration),
        const SizedBox(height: 16),
        AvailabilityCalendar(
          month: _month,
          days: state.monthDays(key),
          loading: state.monthLoading && state.monthDays(key).isEmpty,
          selectedDate: _selectedDate,
          onlyAvailableSelectable: true,
          earliestMonth: DateTime.now(),
          onSelectDate: _selectDate,
          onMonthChanged: (m) {
            setState(() {
              _month = m;
              _selectedDate = null;
              _selectedSlot = null;
            });
            _loadMonth();
          },
        ),
        const SizedBox(height: 16),
        if (_selectedDate != null)
          SlotList(
            day: state.selectedDay,
            loading: state.dayLoading,
            selectedSlot: _selectedSlot,
            onSelectSlot: (s) {
              setState(() => _selectedSlot = s);
              if (_duration != null) widget.onSlotSelected?.call(_selectedDate!, s, _duration!);
            },
          )
        else
          const Text('Choose a duration, then an available date to see open times.',
              style: TextStyle(fontSize: 13, color: Color(0xFF9B8E84))),
        if (state.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(state.errorMessage!,
                key: const Key('public_inline_error'),
                style: const TextStyle(fontSize: 12, color: AppTheme.errorRed)),
          ),
        const SizedBox(height: 12),
        Text(
          'All times are in the Oduvar\'s local time (${state.rules.timezone}).',
          key: const Key('public_timezone_note'),
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B5E55)),
        ),
      ],
    );
  }
}
