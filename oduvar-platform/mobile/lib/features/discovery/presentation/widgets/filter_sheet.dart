import 'package:flutter/material.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import 'package:oduvar_mobile/features/availability/presentation/widgets/availability_calendar.dart'
    show dateKey, formatDateLong;
import 'package:oduvar_mobile/features/availability/models/availability_model.dart' show durationLabel;
import '../../models/discovery_model.dart';
import '../discovery_state.dart';

/// Opens the filter bottom sheet and applies the result to [state].
Future<void> showDiscoveryFilterSheet(BuildContext context, DiscoveryState state) {
  state.loadOptions();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppTheme.sacredCream,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => DiscoveryFilterSheet(
      state: state,
      onApply: (f) {
        state.applyFilters(f);
        Navigator.of(context).pop();
      },
    ),
  );
}

/// Filter form. Edits a local draft; nothing is applied until [onApply] is pressed.
class DiscoveryFilterSheet extends StatefulWidget {
  final DiscoveryState state;
  final ValueChanged<OduvarSearchFilters> onApply;

  const DiscoveryFilterSheet({super.key, required this.state, required this.onApply});

  @override
  State<DiscoveryFilterSheet> createState() => _DiscoveryFilterSheetState();
}

class _DiscoveryFilterSheetState extends State<DiscoveryFilterSheet> {
  static const _durations = [30, 60, 90, 120, 180];

  late OduvarSearchFilters _draft;
  late final TextEditingController _location;

  @override
  void initState() {
    super.initState();
    _draft = widget.state.filters;
    _location = TextEditingController(text: _draft.location ?? '');
  }

  @override
  void dispose() {
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _draft.availableDate != null ? DateTime.parse(_draft.availableDate!) : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(DateTime(now.year, now.month, now.day)) ? now : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (picked != null) setState(() => _draft = _draft.copyWith(availableDate: dateKey(picked)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final options = widget.state.options;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
                child: Row(children: [
                  const Expanded(
                    child: Text('Filters',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.primaryMaroonDark)),
                  ),
                  IconButton(
                    key: const Key('filter_close'),
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ]),
              ),
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  shrinkWrap: true,
                  children: [
                    _title('Location'),
                    TextField(
                      key: const Key('filter_location'),
                      controller: _location,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: 'City or town, e.g. Salem',
                        isDense: true,
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (v) => _draft = v.trim().isEmpty
                          ? _draft.copyWith(clearLocation: true)
                          : _draft.copyWith(location: v.trim()),
                    ),
                    if (widget.state.optionsLoading && options.isEmpty) _optionsSkeleton(),
                    if (widget.state.optionsFailed && options.isEmpty) _optionsError(),
                    if (options.services.isNotEmpty)
                      _chipSection('Service / Song', options.services, _draft.service, 'service',
                          (v) => _draft = v == null ? _draft.copyWith(clearService: true) : _draft.copyWith(service: v)),
                    if (options.eventTypes.isNotEmpty)
                      _chipSection('Event type', options.eventTypes, _draft.eventType, 'event',
                          (v) => _draft = v == null ? _draft.copyWith(clearEventType: true) : _draft.copyWith(eventType: v)),
                    if (options.instruments.isNotEmpty)
                      _chipSection('Instrument', options.instruments, _draft.instrument, 'instrument',
                          (v) => _draft = v == null ? _draft.copyWith(clearInstrument: true) : _draft.copyWith(instrument: v)),
                    if (options.performanceTypes.isNotEmpty)
                      _chipSection('Performance type', options.performanceTypes, _draft.performanceType, 'perf',
                          (v) => _draft = v == null ? _draft.copyWith(clearPerformanceType: true) : _draft.copyWith(performanceType: v)),
                    _chipSection('Transport', DiscoveryFilterOptions.transports, _draft.transport, 'transport',
                        (v) => _draft = v == null ? _draft.copyWith(clearTransport: true) : _draft.copyWith(transport: v)),
                    _title('Available on'),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('filter_date_button'),
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(_draft.availableDate == null ? 'Any date' : formatDateLong(_draft.availableDate!)),
                        ),
                      ),
                      if (_draft.availableDate != null)
                        IconButton(
                          key: const Key('filter_date_clear'),
                          tooltip: 'Clear date',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _draft = _draft.copyWith(clearAvailableDate: true)),
                        ),
                    ]),
                    _title('Available for'),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final d in _durations)
                        ChoiceChip(
                          key: Key('filter_duration_$d'),
                          label: Text(durationLabel(d)),
                          selected: _draft.availableDuration == d,
                          // Duration only makes sense together with a date.
                          onSelected: _draft.availableDate == null
                              ? null
                              : (sel) => setState(() => _draft = sel
                                  ? _draft.copyWith(availableDuration: d)
                                  : _draft.copyWith(clearAvailableDuration: true)),
                        ),
                    ]),
                    if (_draft.availableDate == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text('Pick a date to filter by duration.',
                            key: Key('duration_hint'), style: TextStyle(fontSize: 12, color: Color(0xFF9B8E84))),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('filter_clear_all'),
                      onPressed: () => setState(() {
                        _draft = OduvarSearchFilters.empty;
                        _location.clear();
                      }),
                      child: const Text('Clear All'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      key: const Key('filter_apply'),
                      onPressed: () => widget.onApply(_draft),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryMaroon, foregroundColor: Colors.white),
                      child: const Text('Apply'),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.sacredSaffron)),
      );

  Widget _chipSection(String title, List<OptionItem> items, String? selected, String keyPrefix,
      void Function(String?) set) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(title),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final o in items)
            ChoiceChip(
              key: Key('filter_${keyPrefix}_${o.key}'),
              label: Text(o.label),
              selected: selected == o.key,
              selectedColor: AppTheme.primaryMaroon.withAlpha(30),
              onSelected: (sel) => setState(() => set(sel ? o.key : null)),
            ),
        ]),
      ],
    );
  }

  Widget _optionsSkeleton() => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          key: const Key('filter_options_loading'),
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                height: 34,
                decoration: BoxDecoration(color: const Color(0xFFEFE8DD), borderRadius: BorderRadius.circular(8)),
              ),
          ],
        ),
      );

  Widget _optionsError() => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          key: const Key('filter_options_error'),
          children: [
            const Icon(Icons.error_outline, size: 16, color: AppTheme.errorRed),
            const SizedBox(width: 6),
            const Expanded(
                child: Text("Couldn't load filter options.", style: TextStyle(fontSize: 12, color: AppTheme.errorRed))),
            TextButton(
                key: const Key('filter_options_retry'),
                onPressed: () => widget.state.loadOptions(force: true),
                child: const Text('Retry')),
          ],
        ),
      );
}
