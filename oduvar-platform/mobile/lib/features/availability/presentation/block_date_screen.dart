import 'package:flutter/material.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import 'package:oduvar_mobile/features/auth/presentation/auth_state.dart';
import '../models/availability_model.dart';
import 'availability_state.dart';
import 'widgets/availability_calendar.dart';
import 'widgets/weekly_schedule_editor.dart';

/// Block Date/Time: create or edit a date-specific override.
///  - Unavailable (all day or a time range) removes hours from that date.
///  - Available (time range required) REPLACES the weekly hours for that date.
class BlockDateScreen extends StatefulWidget {
  final AvailabilityState availabilityState;
  final AuthState authState;
  final AvailabilityOverrideModel? existing;
  final DateTime? initialDate;

  const BlockDateScreen({
    super.key,
    required this.availabilityState,
    required this.authState,
    this.existing,
    this.initialDate,
  });

  @override
  State<BlockDateScreen> createState() => _BlockDateScreenState();
}

class _BlockDateScreenState extends State<BlockDateScreen> {
  late String _date;
  late bool _available;
  late bool _allDay;
  late String _start;
  late String _end;
  final _reason = TextEditingController();

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final o = widget.existing;
    if (o != null) {
      _date = o.date;
      _available = o.isAvailable;
      _allDay = o.isAllDay && !o.isAvailable;
      _start = o.startTime ?? '09:00';
      _end = o.endTime ?? '18:00';
      _reason.text = o.reason ?? '';
    } else {
      _date = dateKey(widget.initialDate ?? DateTime.now().add(const Duration(days: 1)));
      _available = false;
      _allDay = true;
      _start = '14:00';
      _end = '16:00';
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _rangeValid => (_allDay && !_available) || timeToMinutes(_start) < timeToMinutes(_end);

  Future<void> _pickDate() async {
    final current = DateTime.parse(_date);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isBefore(DateTime(now.year, now.month, now.day)) ? now : current,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (picked != null) setState(() => _date = dateKey(picked));
  }

  Future<void> _save() async {
    if (!_rangeValid) return;
    final token = await widget.authState.getAccessToken();
    if (token == null) return;
    final useRange = _available || !_allDay;
    final model = AvailabilityOverrideModel(
      id: widget.existing?.id ?? '',
      date: _date,
      type: _available ? 'AVAILABLE' : 'UNAVAILABLE',
      startTime: useRange ? _start : null,
      endTime: useRange ? _end : null,
      reason: _reason.text.trim(),
    );
    final state = widget.availabilityState;
    final ok = _isEdit ? await state.updateOverride(token, model) : await state.createOverride(token, model);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(state.errorMessage ?? 'Could not save'),
        backgroundColor: AppTheme.errorRed,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.availabilityState,
      builder: (context, _) {
        final saving = widget.availabilityState.isSaving;
        return Scaffold(
          backgroundColor: AppTheme.sacredCream,
          appBar: AppBar(
            title: Text(_isEdit ? 'Edit Blocked Time' : 'Block Date/Time'),
            backgroundColor: AppTheme.sacredSurface,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Date', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                key: const Key('override_date_button'),
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(formatDateLong(_date)),
              ),
              const SizedBox(height: 16),
              const Text('Type', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              SegmentedButton<bool>(
                key: const Key('override_type'),
                segments: const [
                  ButtonSegment(
                      value: false,
                      icon: Icon(Icons.block),
                      label: Text('Unavailable', key: Key('type_unavailable'))),
                  ButtonSegment(
                      value: true,
                      icon: Icon(Icons.check_circle_outline),
                      label: Text('Available', key: Key('type_available'))),
                ],
                selected: {_available},
                onSelectionChanged: (s) => setState(() {
                  _available = s.first;
                  if (_available) _allDay = false;
                }),
              ),
              const SizedBox(height: 6),
              Text(
                _available
                    ? 'Replaces your normal weekly hours on this date.'
                    : 'Removes the chosen hours from your normal schedule.',
                key: const Key('override_type_hint'),
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B5E55)),
              ),
              if (!_available)
                SwitchListTile(
                  key: const Key('all_day_switch'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('All day'),
                  value: _allDay,
                  activeThumbColor: AppTheme.primaryMaroon,
                  onChanged: (v) => setState(() => _allDay = v),
                ),
              if (!_allDay || _available) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TimeDropdown(
                        key: const Key('override_start'),
                        label: 'Start',
                        value: _start,
                        hasError: !_rangeValid,
                        onChanged: (v) => setState(() => _start = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TimeDropdown(
                        key: const Key('override_end'),
                        label: 'End',
                        value: _end,
                        isEnd: true,
                        hasError: !_rangeValid,
                        onChanged: (v) => setState(() => _end = v),
                      ),
                    ),
                  ],
                ),
                if (!_rangeValid)
                  const Padding(
                    key: Key('override_range_error'),
                    padding: EdgeInsets.only(top: 6),
                    child: Text('Start time must be before end time',
                        style: TextStyle(fontSize: 12, color: AppTheme.errorRed)),
                  ),
              ],
              const SizedBox(height: 16),
              TextField(
                key: const Key('override_reason'),
                controller: _reason,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: 'Reason (optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  key: const Key('save_override_button'),
                  onPressed: _rangeValid && !saving ? _save : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryMaroon,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: saving
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
