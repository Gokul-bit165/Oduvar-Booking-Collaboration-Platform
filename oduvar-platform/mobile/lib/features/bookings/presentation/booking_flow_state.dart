import 'package:flutter/foundation.dart';
import 'package:oduvar_mobile/core/network/api_exceptions.dart';
import 'package:oduvar_mobile/features/availability/data/availability_repository.dart';
import 'package:oduvar_mobile/features/availability/models/availability_model.dart';
import 'package:oduvar_mobile/features/services/models/service_model.dart';
import '../data/booking_repository.dart';
import '../models/booking_model.dart';
import 'booking_state.dart' show BookingErrorKind;

enum BookingStep { service, duration, date, time, event, contact, transport, review }

const bookingStepLabels = {
  BookingStep.service: 'Service',
  BookingStep.duration: 'Duration',
  BookingStep.date: 'Date',
  BookingStep.time: 'Time',
  BookingStep.event: 'Event',
  BookingStep.contact: 'Location & Contact',
  BookingStep.transport: 'Transport',
  BookingStep.review: 'Review',
};

String normalizePhone(String raw) => raw.replaceAll(RegExp(r'[\s\-().]'), '');

/// Draft of the booking being built. Everything the client picks is kept when moving Back/Next.
///
/// Availability (month calendar + start times) always comes from the backend Phase 4 endpoints and the
/// durations offered come from the selected service's ACTIVE price options. The price shown is the
/// Oduvar's published price; the server recomputes it on submit and the request never carries an amount.
class BookingFlowState extends ChangeNotifier {
  final String oduvarId;
  final String oduvarName;
  final List<OduvarServiceModel> services; // bookable: active service with >= 1 active price
  final BookingRepository _bookings;
  final AvailabilityRepository _availability;

  BookingFlowState({
    required this.oduvarId,
    required this.oduvarName,
    required List<OduvarServiceModel> allServices,
    BookingRepository? bookingRepository,
    AvailabilityRepository? availabilityRepository,
    DateTime? initialMonth,
  })  : services = allServices.where((s) => s.isActive && s.pricings.any((p) => p.isActive)).toList(),
        _bookings = bookingRepository ?? BookingRepository(),
        _availability = availabilityRepository ?? AvailabilityRepository() {
    final base = initialMonth ?? DateTime.now();
    _month = DateTime(base.year, base.month, 1);
  }

  // ─── Wizard position ─────────────────────────────────────────────────────
  BookingStep _step = BookingStep.service;
  BookingStep get step => _step;
  int get stepIndex => BookingStep.values.indexOf(_step);
  int get stepCount => BookingStep.values.length;

  // ─── Choices ─────────────────────────────────────────────────────────────
  OduvarServiceModel? _service;
  PricingModel? _pricing;
  String? _date;
  String? _time;
  String _eventType = '';
  String _description = '';
  String _location = '';
  String _phone1 = '';
  String _phone2 = '';
  bool _showErrors = false;

  OduvarServiceModel? get service => _service;
  PricingModel? get pricing => _pricing;
  String? get date => _date;
  String? get time => _time;
  String get eventType => _eventType;
  String get description => _description;
  String get location => _location;
  String get phone1 => _phone1;
  String get phone2 => _phone2;
  bool get showErrors => _showErrors;

  /// Only the active price options of the selected service: the ONLY durations the client can pick.
  List<PricingModel> get durationOptions =>
      (_service?.pricings.where((p) => p.isActive).toList() ?? [])..sort((a, b) => a.durationMinutes.compareTo(b.durationMinutes));

  // ─── Availability (from the backend) ─────────────────────────────────────
  late DateTime _month;
  DateTime get month => _month;
  final Map<String, List<CalendarDayModel>> _monthDays = {};
  bool _monthLoading = false;
  bool _slotsLoading = false;
  DayAvailabilityModel? _day;
  String? _availabilityError;
  String _timezone = 'Asia/Kolkata';

  bool get monthLoading => _monthLoading;
  bool get slotsLoading => _slotsLoading;
  DayAvailabilityModel? get day => _day;
  String? get availabilityError => _availabilityError;
  String get timezone => _timezone;
  List<CalendarDayModel> monthDays(String key) => _monthDays[key] ?? const [];

  String _monthKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
  String get currentMonthKey => _monthKey(_month);

  // ─── Submission ──────────────────────────────────────────────────────────
  bool _submitting = false;
  String? _submitError;
  BookingErrorKind _submitErrorKind = BookingErrorKind.none;
  bool get submitting => _submitting;
  String? get submitError => _submitError;
  BookingErrorKind get submitErrorKind => _submitErrorKind;

  // ─── Selection ───────────────────────────────────────────────────────────

  void selectService(OduvarServiceModel s) {
    if (_service?.id == s.id) return;
    _service = s;
    _pricing = null; // a different service has different priced durations
    _clearWhen();
    notifyListeners();
  }

  void selectPricing(PricingModel p) {
    if (_pricing?.id == p.id) return;
    _pricing = p;
    _clearWhen(); // availability depends on the duration
    notifyListeners();
  }

  void _clearWhen() {
    _date = null;
    _time = null;
    _day = null;
    _monthDays.clear();
    _availabilityError = null;
  }

  Future<void> selectDate(String date) async {
    _date = date;
    _time = null;
    await _loadDay();
  }

  void selectTime(String t) {
    _time = t;
    notifyListeners();
  }

  void setEventType(String v) {
    _eventType = v;
    notifyListeners();
  }

  void setDescription(String v) {
    _description = v;
    notifyListeners();
  }

  void setLocation(String v) {
    _location = v;
    notifyListeners();
  }

  void setPhone1(String v) {
    _phone1 = v;
    notifyListeners();
  }

  void setPhone2(String v) {
    _phone2 = v;
    notifyListeners();
  }

  // ─── Validation (client-side convenience only; the server validates again) ─

  String? get eventTypeError => _eventType.isEmpty ? 'Please choose the type of event' : null;
  String? get descriptionError => _description.trim().length < 3 ? 'Please describe the event (at least 3 characters)' : null;
  String? get locationError => _location.trim().length < 3 ? 'Please enter the event location' : null;

  static final _phoneRe = RegExp(r'^\+?[0-9]{10,15}$');
  String? get phone1Error {
    if (_phone1.trim().isEmpty) return 'Phone number is required';
    return _phoneRe.hasMatch(normalizePhone(_phone1)) ? null : 'Enter a valid phone number (10-15 digits)';
  }

  String? get phone2Error {
    if (_phone2.trim().isEmpty) return null; // optional
    return _phoneRe.hasMatch(normalizePhone(_phone2)) ? null : 'Enter a valid phone number (10-15 digits)';
  }

  bool get eventStepValid => eventTypeError == null && descriptionError == null;
  bool get contactStepValid => locationError == null && phone1Error == null && phone2Error == null;

  bool canProceedFrom(BookingStep s) {
    switch (s) {
      case BookingStep.service:
        return _service != null;
      case BookingStep.duration:
        return _pricing != null;
      case BookingStep.date:
        return _date != null;
      case BookingStep.time:
        return _time != null;
      case BookingStep.event:
        return eventStepValid;
      case BookingStep.contact:
        return contactStepValid;
      case BookingStep.transport:
        return true;
      case BookingStep.review:
        return _service != null && _pricing != null && _date != null && _time != null && eventStepValid && contactStepValid;
    }
  }

  // ─── Navigation ──────────────────────────────────────────────────────────

  /// Advance if the current step is valid; otherwise reveal its validation messages.
  Future<bool> next() async {
    if (!canProceedFrom(_step)) {
      _showErrors = true;
      notifyListeners();
      return false;
    }
    if (_step == BookingStep.review) return true;
    _showErrors = false;
    _step = BookingStep.values[stepIndex + 1];
    notifyListeners();
    if (_step == BookingStep.date) await loadMonth();
    return true;
  }

  void back() {
    if (stepIndex == 0) return;
    _showErrors = false;
    _step = BookingStep.values[stepIndex - 1];
    notifyListeners();
  }

  Future<void> goTo(BookingStep s) async {
    _step = s;
    _showErrors = false;
    notifyListeners();
    if (s == BookingStep.date) await loadMonth();
    if (s == BookingStep.time && _date != null) await _loadDay();
  }

  // ─── Backend availability ────────────────────────────────────────────────

  Future<void> changeMonth(DateTime m) async {
    _month = DateTime(m.year, m.month, 1);
    notifyListeners();
    await loadMonth();
  }

  bool _timezoneLoaded = false;

  Future<void> loadMonth() async {
    if (_pricing == null) return;
    final key = currentMonthKey;
    _monthLoading = true;
    _availabilityError = null;
    notifyListeners();
    try {
      if (!_timezoneLoaded) {
        // The Oduvar's schedule timezone, shown so times are never ambiguous.
        _timezone = (await _availability.getAvailability(oduvarId: oduvarId)).rules.timezone;
        _timezoneLoaded = true;
      }
      final res = await _availability.getMonth(oduvarId: oduvarId, month: key, durationMinutes: _pricing!.durationMinutes);
      _monthDays[key] = res.days;
    } catch (e) {
      _availabilityError = e is ApiException ? e.message : e.toString();
    }
    _monthLoading = false;
    notifyListeners();
  }

  Future<void> _loadDay() async {
    if (_date == null || _pricing == null) return;
    _slotsLoading = true;
    _day = null;
    _availabilityError = null;
    notifyListeners();
    try {
      _day = await _availability.getDay(oduvarId: oduvarId, date: _date!, durationMinutes: _pricing!.durationMinutes);
    } catch (e) {
      _availabilityError = e is ApiException ? e.message : e.toString();
    }
    _slotsLoading = false;
    notifyListeners();
  }

  Future<void> reloadSlots() => _loadDay();

  // ─── Submit ──────────────────────────────────────────────────────────────

  /// Exactly what is sent to the server. Note: NO price fields.
  Map<String, dynamic> toPayload() => {
        'oduvarId': oduvarId,
        'oduvarServiceId': _service!.id,
        'servicePricingId': _pricing!.id,
        'date': _date,
        'startTime': _time,
        'durationMinutes': _pricing!.durationMinutes,
        'eventType': _eventType,
        'description': _description.trim(),
        'eventLocation': _location.trim(),
        'phone1': normalizePhone(_phone1),
        if (_phone2.trim().isNotEmpty) 'phone2': normalizePhone(_phone2),
        'transport': _service!.transport,
      };

  Future<BookingModel?> submit(String token) async {
    if (!canProceedFrom(BookingStep.review) || _submitting) return null;
    _submitting = true;
    _submitError = null;
    _submitErrorKind = BookingErrorKind.none;
    notifyListeners();
    try {
      final booking = await _bookings.createBooking(token, toPayload());
      _submitting = false;
      notifyListeners();
      return booking;
    } catch (e) {
      if (e is UnauthorizedException || e is ForbiddenException) {
        _submitErrorKind = BookingErrorKind.unauthorized;
      } else if (e is NetworkException) {
        _submitErrorKind = BookingErrorKind.network;
      } else if (e is ApiException && e.statusCode == 409) {
        _submitErrorKind = BookingErrorKind.conflict;
      } else if (e is ApiException && e.statusCode == 400) {
        _submitErrorKind = BookingErrorKind.validation;
      } else {
        _submitErrorKind = BookingErrorKind.other;
      }
      _submitError = e is ApiException ? e.message : e.toString().replaceFirst('Exception: ', '');
      _submitting = false;
      notifyListeners();
      return null;
    }
  }
}
