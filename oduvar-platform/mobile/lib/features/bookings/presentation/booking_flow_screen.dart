import 'package:flutter/material.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import 'package:oduvar_mobile/features/auth/presentation/auth_state.dart';
import 'package:oduvar_mobile/features/availability/data/availability_repository.dart';
import 'package:oduvar_mobile/features/availability/presentation/widgets/availability_calendar.dart';
import 'package:oduvar_mobile/features/services/models/service_model.dart';
import '../data/booking_repository.dart';
import '../models/booking_model.dart';
import '../widgets/booking_event_form.dart';
import '../widgets/booking_states.dart';
import '../widgets/booking_step_indicator.dart';
import '../widgets/booking_summary.dart';
import 'booking_flow_state.dart';
import 'booking_state.dart' show BookingErrorKind;
import 'booking_summary_screen.dart';

/// Guided booking: Service -> Duration -> Date -> Time -> Event -> Location & Contact -> Transport -> Review.
/// Nothing is hardcoded: services, priced durations, dates and start times all come from the backend.
class BookingFlowScreen extends StatefulWidget {
  final String oduvarId;
  final String oduvarName;
  final List<OduvarServiceModel> services;
  final AuthState authState;
  final BookingRepository? bookingRepository;
  final AvailabilityRepository? availabilityRepository;
  final DateTime? initialMonth;

  const BookingFlowScreen({
    super.key,
    required this.oduvarId,
    required this.oduvarName,
    required this.services,
    required this.authState,
    this.bookingRepository,
    this.availabilityRepository,
    this.initialMonth,
  });

  @override
  State<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends State<BookingFlowScreen> {
  late final BookingFlowState _flow;

  @override
  void initState() {
    super.initState();
    _flow = BookingFlowState(
      oduvarId: widget.oduvarId,
      oduvarName: widget.oduvarName,
      allServices: widget.services,
      bookingRepository: widget.bookingRepository,
      availabilityRepository: widget.availabilityRepository,
      initialMonth: widget.initialMonth,
    );
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final token = await widget.authState.getAccessToken();
    if (token == null) {
      _flow.goTo(BookingStep.review);
      return;
    }
    final booking = await _flow.submit(token);
    if (booking != null && mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => BookingSummaryScreen(
          booking: booking,
          authState: widget.authState,
          bookingRepository: widget.bookingRepository,
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _flow,
      builder: (context, _) {
        return PopScope(
          canPop: _flow.stepIndex == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _flow.back();
          },
          child: Scaffold(
            backgroundColor: AppTheme.sacredCream,
            appBar: AppBar(
              title: Text('Book ${widget.oduvarName}', overflow: TextOverflow.ellipsis),
              backgroundColor: AppTheme.sacredSurface,
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: BookingStepIndicator(current: _flow.step),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    key: const Key('booking_step_body'),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: _stepBody(),
                  ),
                ),
                _bottomBar(),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Step bodies ─────────────────────────────────────────────────────────

  Widget _stepBody() {
    switch (_flow.step) {
      case BookingStep.service:
        return _serviceStep();
      case BookingStep.duration:
        return _durationStep();
      case BookingStep.date:
        return _dateStep();
      case BookingStep.time:
        return _timeStep();
      case BookingStep.event:
        return BookingEventForm(flow: _flow);
      case BookingStep.contact:
        return BookingContactForm(flow: _flow);
      case BookingStep.transport:
        return _transportStep();
      case BookingStep.review:
        return _reviewStep();
    }
  }

  Widget _title(String t, [String? sub]) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          if (sub != null) Text(sub, style: const TextStyle(fontSize: 12, color: Color(0xFF9B8E84))),
        ]),
      );

  Widget _selectTile({required Key key, required bool selected, required Widget child, required VoidCallback onTap}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected ? AppTheme.primaryMaroon.withAlpha(18) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? AppTheme.primaryMaroon : AppTheme.sacredBorder, width: selected ? 2 : 1),
            ),
            child: Row(children: [
              Expanded(child: child),
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: selected ? AppTheme.primaryMaroon : const Color(0xFF9B8E84)),
            ]),
          ),
        ),
      );

  Widget _serviceStep() {
    if (_flow.services.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text('This Oduvar has no services open for booking right now.',
            key: Key('no_bookable_services'), style: TextStyle(color: Color(0xFF6B5E55))),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title('Select a service', 'Only services this Oduvar currently offers'),
      for (final s in _flow.services)
        _selectTile(
          key: Key('book_service_${s.id}'),
          selected: _flow.service?.id == s.id,
          onTap: () => _flow.selectService(s),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.primaryMaroonDark)),
            Text(s.category, style: const TextStyle(fontSize: 12, color: AppTheme.sandalWood)),
          ]),
        ),
    ]);
  }

  Widget _durationStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title('Select duration', 'Prices are set by the Oduvar and cannot be changed'),
      for (final p in _flow.durationOptions)
        _selectTile(
          key: Key('book_duration_${p.id}'),
          selected: _flow.pricing?.id == p.id,
          onTap: () => _flow.selectPricing(p),
          child: Text('${bookingDurationLabel(p.durationMinutes)} — ${p.formattedAmount}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.primaryMaroonDark)),
        ),
    ]);
  }

  Widget _dateStep() {
    final key = _flow.currentMonthKey;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title('Choose a date', 'Green dates have open times for ${bookingDurationLabel(_flow.pricing?.durationMinutes ?? 0)}'),
      if (_flow.availabilityError != null)
        BookingErrorBanner(message: _flow.availabilityError!),
      AvailabilityCalendar(
        month: _flow.month,
        days: _flow.monthDays(key),
        loading: _flow.monthLoading && _flow.monthDays(key).isEmpty,
        selectedDate: _flow.date,
        onlyAvailableSelectable: true,
        earliestMonth: DateTime.now(),
        onSelectDate: _flow.selectDate,
        onMonthChanged: _flow.changeMonth,
      ),
    ]);
  }

  Widget _timeStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title('Choose a start time', 'Times shown are in the Oduvar\'s local time (${_flow.timezone})'),
      if (_flow.availabilityError != null)
        BookingErrorBanner(message: _flow.availabilityError!),
      SlotList(
        day: _flow.day,
        loading: _flow.slotsLoading,
        selectedSlot: _flow.time,
        onSelectSlot: _flow.selectTime,
      ),
      if (_flow.day == null && !_flow.slotsLoading && _flow.availabilityError != null)
        TextButton(key: const Key('reload_slots'), onPressed: _flow.reloadSlots, child: const Text('Try again')),
    ]);
  }

  Widget _transportStep() {
    final s = _flow.service!;
    String headline;
    String detail;
    switch (s.transport) {
      case 'INCLUDED':
        headline = 'Transport included';
        detail = 'The Oduvar travels to your event at no extra charge.';
        break;
      case 'NOT_INCLUDED':
        headline = 'Transport not included';
        detail = 'Please arrange transport for the Oduvar.';
        break;
      case 'ADDITIONAL_FEE':
        headline = 'Transport: ${s.transportFee == null ? 'additional fee' : formatMoney(s.transportFee!)}';
        detail = 'The Oduvar charges a fixed transport fee, added to the total.';
        break;
      default:
        headline = 'Transport to be discussed';
        detail = 'The Oduvar will agree transport with you after receiving your request. The total is confirmed then.';
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title('Transport', 'Set by the Oduvar for this service'),
      Container(
        key: const Key('book_transport_card'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.sacredBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.directions_car_outlined, color: AppTheme.primaryMaroon),
            const SizedBox(width: 10),
            Expanded(child: Text(headline, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 8),
          Text(detail, style: const TextStyle(fontSize: 13, color: Color(0xFF6B5E55))),
        ]),
      ),
    ]);
  }

  Widget _reviewStep() {
    final f = _flow;
    final s = f.service!;
    final p = f.pricing!;
    final lines = BookingPriceLines.draft(serviceAmount: p.amount, transport: s.transport, transportFee: s.transportFee);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (f.submitError != null) ...[
        BookingErrorBanner(message: f.submitError!),
        if (f.submitErrorKind == BookingErrorKind.conflict)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('choose_another_time'),
              onPressed: () => f.goTo(BookingStep.time),
              icon: const Icon(Icons.schedule),
              label: const Text('Choose another time'),
            ),
          ),
      ],
      BookingSummary(
        oduvarName: widget.oduvarName,
        serviceName: s.name,
        date: f.date!,
        startTime: f.time!,
        durationMinutes: p.durationMinutes,
        eventType: f.eventType,
        location: f.location.trim(),
        price: lines,
        timezoneNote: 'Times are in the Oduvar\'s local time (${f.timezone}).',
      ),
      const SizedBox(height: 10),
      const Text('The final price is confirmed by the server when you send the request.',
          style: TextStyle(fontSize: 11, color: Color(0xFF9B8E84))),
    ]);
  }

  // ─── Bottom bar ──────────────────────────────────────────────────────────

  Widget _bottomBar() {
    final isReview = _flow.step == BookingStep.review;
    final canGo = _flow.canProceedFrom(_flow.step);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppTheme.sacredBorder))),
        child: Row(children: [
          if (_flow.stepIndex > 0)
            Expanded(
              child: OutlinedButton(
                key: const Key('book_back'),
                onPressed: _flow.submitting ? null : _flow.back,
                child: const Text('Back'),
              ),
            ),
          if (_flow.stepIndex > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: isReview
                ? ElevatedButton(
                    key: const Key('book_submit'),
                    onPressed: canGo && !_flow.submitting ? _submit : null,
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryMaroon, foregroundColor: Colors.white),
                    child: _flow.submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Send Booking Request'),
                  )
                : ElevatedButton(
                    key: const Key('book_next'),
                    // Stays tappable when invalid so the step can show what is missing.
                    onPressed: _flow.next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canGo ? AppTheme.primaryMaroon : AppTheme.primaryMaroon.withAlpha(120),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Continue'),
                  ),
          ),
        ]),
      ),
    );
  }
}
