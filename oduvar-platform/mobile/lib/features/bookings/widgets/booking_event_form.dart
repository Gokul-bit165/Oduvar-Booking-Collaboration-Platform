import 'package:flutter/material.dart';
import 'package:oduvar_mobile/core/theme/app_theme.dart';
import '../models/booking_model.dart';
import '../presentation/booking_flow_state.dart';

InputDecoration _decoration(String label, {String? hint, String? error}) => InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: error,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );

/// Step "Event": event type + description.
class BookingEventForm extends StatefulWidget {
  final BookingFlowState flow;

  const BookingEventForm({super.key, required this.flow});

  @override
  State<BookingEventForm> createState() => _BookingEventFormState();
}

class _BookingEventFormState extends State<BookingEventForm> {
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    _description = TextEditingController(text: widget.flow.description); // survives Back/Next
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.flow;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('What kind of event is this?', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in kBookingEventTypes)
            ChoiceChip(
              key: Key('book_event_${e.key}'),
              label: Text(e.value),
              selected: f.eventType == e.key,
              selectedColor: AppTheme.primaryMaroon.withAlpha(30),
              onSelected: (_) => f.setEventType(e.key),
            ),
        ]),
        if (f.showErrors && f.eventTypeError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(f.eventTypeError!, key: const Key('event_type_error'), style: const TextStyle(fontSize: 12, color: AppTheme.errorRed)),
          ),
        const SizedBox(height: 18),
        TextField(
          key: const Key('book_description'),
          controller: _description,
          maxLines: 4,
          maxLength: 1000,
          onChanged: f.setDescription,
          decoration: _decoration('Event details', hint: 'e.g. Kumbabishekam, please sing Thevaram at the sanctum',
              error: f.showErrors ? f.descriptionError : null),
        ),
      ],
    );
  }
}

/// Step "Location & Contact". The event location is the CLIENT's event address, entirely separate from
/// the Oduvar's profile location.
class BookingContactForm extends StatefulWidget {
  final BookingFlowState flow;

  const BookingContactForm({super.key, required this.flow});

  @override
  State<BookingContactForm> createState() => _BookingContactFormState();
}

class _BookingContactFormState extends State<BookingContactForm> {
  late final TextEditingController _location;
  late final TextEditingController _phone1;
  late final TextEditingController _phone2;

  @override
  void initState() {
    super.initState();
    _location = TextEditingController(text: widget.flow.location);
    _phone1 = TextEditingController(text: widget.flow.phone1);
    _phone2 = TextEditingController(text: widget.flow.phone2);
  }

  @override
  void dispose() {
    _location.dispose();
    _phone1.dispose();
    _phone2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.flow;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('book_location'),
          controller: _location,
          maxLines: 2,
          onChanged: f.setLocation,
          decoration: _decoration('Event location', hint: 'Full address of where the event takes place',
              error: f.showErrors ? f.locationError : null),
        ),
        const SizedBox(height: 14),
        TextField(
          key: const Key('book_phone1'),
          controller: _phone1,
          keyboardType: TextInputType.phone,
          onChanged: f.setPhone1,
          decoration: _decoration('Phone number', hint: '+91 98765 43210', error: f.showErrors ? f.phone1Error : null),
        ),
        const SizedBox(height: 14),
        TextField(
          key: const Key('book_phone2'),
          controller: _phone2,
          keyboardType: TextInputType.phone,
          onChanged: f.setPhone2,
          decoration: _decoration('Alternate phone (optional)', error: f.showErrors ? f.phone2Error : null),
        ),
        const SizedBox(height: 10),
        const Row(children: [
          Icon(Icons.lock_outline, size: 14, color: Color(0xFF9B8E84)),
          SizedBox(width: 6),
          Expanded(
            child: Text('Your phone numbers are visible only to this Oduvar for this booking.',
                style: TextStyle(fontSize: 12, color: Color(0xFF9B8E84))),
          ),
        ]),
      ],
    );
  }
}
