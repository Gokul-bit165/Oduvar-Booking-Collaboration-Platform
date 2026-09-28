import 'package:flutter/material.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import 'package:oduvar_mobile/features/auth/presentation/auth_state.dart';
import '../models/availability_model.dart';
import 'availability_state.dart';
import 'blocked_dates_screen.dart';
import 'oduvar_calendar_screen.dart';
import 'widgets/availability_status_views.dart';
import 'widgets/weekly_schedule_editor.dart';

/// Oduvar Availability Settings: weekly schedule + booking rules (min / max
/// duration, buffer) in one form with a single Save, plus links to Blocked
/// Dates and the Calendar.
class AvailabilitySettingsScreen extends StatefulWidget {
  final AvailabilityState availabilityState;
  final AuthState authState;

  const AvailabilitySettingsScreen({
    super.key,
    required this.availabilityState,
    required this.authState,
  });

  @override
  State<AvailabilitySettingsScreen> createState() => _AvailabilitySettingsScreenState();
}

class _AvailabilitySettingsScreenState extends State<AvailabilitySettingsScreen> {
  List<WeeklyAvailabilityModel>? _days;
  BookingRulesModel? _rules;

  static const _minOptions = [30, 60, 90, 120];
  static const _maxOptions = [30, 60, 90, 120, 150, 180, 240, 300, 360, 480];
  static const _bufferOptions = [0, 15, 30, 45, 60, 90, 120];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final token = await widget.authState.getAccessToken();
    if (token == null) return;
    await widget.availabilityState.load(token: token);
    if (!mounted) return;
    setState(() {
      _days = null;
      _rules = null;
    });
  }

  bool get _rulesValid =>
      _rules != null && _rules!.maximumDurationMinutes >= _rules!.minimumDurationMinutes;

  bool get _canSave =>
      _days != null && _days!.every((d) => d.hasValidWindows) && _rulesValid;

  Future<void> _save() async {
    final token = await widget.authState.getAccessToken();
    if (token == null || !_canSave) return;
    final ok = await widget.availabilityState
        .saveWeekly(token, days: _days!, rules: _rules!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Availability saved'
          : widget.availabilityState.errorMessage ?? 'Could not save availability'),
      backgroundColor: ok ? AppTheme.successGreen : AppTheme.errorRed,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.availabilityState,
      builder: (context, _) {
        final state = widget.availabilityState;
        if (_days == null && state.status == AvailabilityStatus.loaded) {
          _days = [...state.weekly];
          _rules = state.rules;
        }
        return Scaffold(
          backgroundColor: AppTheme.sacredCream,
          appBar: AppBar(
            title: const Text('Availability'),
            backgroundColor: AppTheme.sacredSurface,
          ),
          body: _body(state),
        );
      },
    );
  }

  Widget _body(AvailabilityState state) {
    if (state.isLoading && _days == null) return const AvailabilityLoadingView();
    if (_days == null) {
      if (state.status == AvailabilityStatus.error) {
        return AvailabilityErrorView(
          message: state.errorMessage ?? 'Failed to load availability',
          kind: state.errorKind,
          onRetry: _load,
        );
      }
      return const AvailabilityLoadingView();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('WEEKLY SCHEDULE'),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'Times are in your schedule timezone: ${_rules!.timezone}',
            key: const Key('timezone_note'),
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B5E55)),
          ),
        ),
        WeeklyScheduleEditor(days: _days!, onChanged: (d) => setState(() => _days = d)),
        const SizedBox(height: 14),
        _sectionTitle('BOOKING RULES'),
        _rulesCard(),
        const SizedBox(height: 14),
        _navTile(
          key: const Key('open_blocked_dates'),
          icon: Icons.event_busy_outlined,
          title: 'Blocked Dates & Times',
          subtitle: '${state.overrides.length} date-specific ${state.overrides.length == 1 ? 'entry' : 'entries'}',
          onTap: _openBlockedDates,
        ),
        const SizedBox(height: 8),
        _navTile(
          key: const Key('open_calendar'),
          icon: Icons.calendar_month_outlined,
          title: 'Calendar',
          subtitle: 'See which dates are available',
          onTap: _openCalendar,
        ),
        const SizedBox(height: 20),
        if (state.status == AvailabilityStatus.error && state.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(state.errorMessage!,
                key: const Key('save_error'),
                style: const TextStyle(color: AppTheme.errorRed, fontSize: 13)),
          ),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            key: const Key('save_availability_button'),
            onPressed: _canSave && !state.isSaving ? _save : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryMaroon,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: state.isSaving
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save Availability'),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.sacredSaffron, letterSpacing: 1.2)),
      );

  Widget _rulesCard() {
    final r = _rules!;
    Widget dd(Key key, String label, int value, List<int> options, ValueChanged<int> onChanged,
        {String Function(int)? fmt}) {
      final opts = options.contains(value) ? options : ([...options, value]..sort());
      return InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            key: key,
            isExpanded: true,
            isDense: true,
            value: value,
            items: [
              for (final o in opts)
                DropdownMenuItem(value: o, child: Text(fmt != null ? fmt(o) : durationLabel(o))),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.sacredBorder),
      ),
      child: Column(
        children: [
          dd(const Key('min_duration_dropdown'), 'Minimum booking', r.minimumDurationMinutes, _minOptions,
              (v) => setState(() => _rules = r.copyWith(minimumDurationMinutes: v))),
          const SizedBox(height: 12),
          dd(const Key('max_duration_dropdown'), 'Maximum booking', r.maximumDurationMinutes, _maxOptions,
              (v) => setState(() => _rules = r.copyWith(maximumDurationMinutes: v))),
          if (!_rulesValid)
            const Padding(
              key: Key('rules_error'),
              padding: EdgeInsets.only(top: 6),
              child: Row(children: [
                Icon(Icons.error_outline, size: 16, color: AppTheme.errorRed),
                SizedBox(width: 6),
                Expanded(
                  child: Text('Maximum booking must be at least the minimum booking',
                      style: TextStyle(fontSize: 12, color: AppTheme.errorRed)),
                ),
              ]),
            ),
          const SizedBox(height: 12),
          dd(const Key('buffer_dropdown'), 'Buffer between appointments', r.bufferMinutes, _bufferOptions,
              (v) => setState(() => _rules = r.copyWith(bufferMinutes: v)),
              fmt: (m) => m == 0 ? 'No buffer' : durationLabel(m)),
        ],
      ),
    );
  }

  Widget _navTile({
    required Key key,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.sacredBorder),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primaryMaroon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primaryMaroonDark)),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF9B8E84))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF9B8E84)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openBlockedDates() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlockedDatesScreen(
          availabilityState: widget.availabilityState,
          authState: widget.authState,
        ),
      ),
    );
  }

  Future<void> _openCalendar() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OduvarCalendarScreen(
          availabilityState: widget.availabilityState,
          authState: widget.authState,
        ),
      ),
    );
  }
}
