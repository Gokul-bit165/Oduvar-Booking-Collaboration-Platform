import 'package:flutter/material.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import 'package:oduvar_mobile/features/auth/presentation/auth_state.dart';
import 'availability_state.dart';
import 'widgets/availability_calendar.dart';
import 'widgets/availability_status_views.dart';

/// Oduvar's own calendar: month view + date selection. Status comes from the
/// backend; BOOKED / PENDING will appear here once the booking phase supplies them.
class OduvarCalendarScreen extends StatefulWidget {
  final AvailabilityState availabilityState;
  final AuthState authState;
  final DateTime? initialMonth;

  const OduvarCalendarScreen({
    super.key,
    required this.availabilityState,
    required this.authState,
    this.initialMonth,
  });

  @override
  State<OduvarCalendarScreen> createState() => _OduvarCalendarScreenState();
}

class _OduvarCalendarScreenState extends State<OduvarCalendarScreen> {
  late DateTime _month;
  String? _selected;

  @override
  void initState() {
    super.initState();
    final base = widget.initialMonth ?? DateTime.now();
    _month = DateTime(base.year, base.month, 1);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMonth());
  }

  Future<void> _loadMonth() async {
    final token = await widget.authState.getAccessToken();
    if (token == null) return;
    await widget.availabilityState.loadMonth(token: token, month: monthKey(_month));
  }

  Future<void> _select(String date) async {
    setState(() => _selected = date);
    final token = await widget.authState.getAccessToken();
    if (token == null) return;
    await widget.availabilityState.loadDay(token: token, date: date);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.availabilityState,
      builder: (context, _) {
        final state = widget.availabilityState;
        final key = monthKey(_month);
        final hasError = state.errorMessage != null && state.monthDays(key).isEmpty && !state.monthLoading;
        return Scaffold(
          backgroundColor: AppTheme.sacredCream,
          appBar: AppBar(title: const Text('My Calendar'), backgroundColor: AppTheme.sacredSurface),
          body: hasError
              ? AvailabilityErrorView(
                  message: state.errorMessage!, kind: state.errorKind, onRetry: _loadMonth)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    AvailabilityCalendar(
                      month: _month,
                      days: state.monthDays(key),
                      loading: state.monthLoading && state.monthDays(key).isEmpty,
                      selectedDate: _selected,
                      earliestMonth: DateTime.now(),
                      onSelectDate: _select,
                      onMonthChanged: (m) {
                        setState(() {
                          _month = m;
                          _selected = null;
                        });
                        _loadMonth();
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_selected != null)
                      SlotList(day: state.selectedDay, loading: state.dayLoading),
                    if (_selected == null)
                      const Text('Select a date to see your working hours and open times.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF9B8E84))),
                  ],
                ),
        );
      },
    );
  }
}
