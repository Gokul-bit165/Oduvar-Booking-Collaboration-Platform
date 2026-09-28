import 'package:flutter/foundation.dart';
import 'package:oduvar_mobile/core/network/api_exceptions.dart';
import '../models/availability_model.dart';
import '../data/availability_repository.dart';

enum AvailabilityStatus { initial, loading, loaded, saving, error }

/// Kinds of failure the UI distinguishes.
enum AvailabilityErrorKind { none, unauthorized, validation, network, other }

class AvailabilityState extends ChangeNotifier {
  final AvailabilityRepository _repository;

  AvailabilityStatus _status = AvailabilityStatus.initial;
  AvailabilityErrorKind _errorKind = AvailabilityErrorKind.none;
  String? _errorMessage;
  AvailabilityModel _availability = AvailabilityModel.empty();
  final Map<String, List<CalendarDayModel>> _months = {};
  bool _monthLoading = false;
  bool _dayLoading = false;
  DayAvailabilityModel? _selectedDay;

  AvailabilityState({AvailabilityRepository? repository})
      : _repository = repository ?? AvailabilityRepository();

  AvailabilityStatus get status => _status;
  bool get isLoading => _status == AvailabilityStatus.loading;
  bool get isSaving => _status == AvailabilityStatus.saving;
  bool get monthLoading => _monthLoading;
  bool get dayLoading => _dayLoading;
  String? get errorMessage => _errorMessage;
  AvailabilityErrorKind get errorKind => _errorKind;
  AvailabilityModel get availability => _availability;
  BookingRulesModel get rules => _availability.rules;
  List<WeeklyAvailabilityModel> get weekly => _availability.weekly;
  List<AvailabilityOverrideModel> get overrides => List.unmodifiable(_availability.overrides);
  DayAvailabilityModel? get selectedDay => _selectedDay;
  List<CalendarDayModel> monthDays(String month) => _months[month] ?? const [];

  void clearError() {
    _errorMessage = null;
    _errorKind = AvailabilityErrorKind.none;
    notifyListeners();
  }

  void _fail(Object e) {
    if (e is UnauthorizedException || e is ForbiddenException) {
      _errorKind = AvailabilityErrorKind.unauthorized;
    } else if (e is NetworkException) {
      _errorKind = AvailabilityErrorKind.network;
    } else if (e is ApiException && e.code == 'VALIDATION_ERROR') {
      _errorKind = AvailabilityErrorKind.validation;
    } else {
      _errorKind = AvailabilityErrorKind.other;
    }
    _errorMessage = e is ApiException ? e.message : e.toString().replaceFirst('Exception: ', '');
  }

  void _invalidateCalendar() {
    _months.clear();
    _selectedDay = null;
  }

  // ─── Load ────────────────────────────────────────────────────────────────

  /// Owner ([token]) or public ([oduvarId]) availability settings.
  Future<void> load({String? token, String? oduvarId}) async {
    _status = AvailabilityStatus.loading;
    _errorMessage = null;
    _errorKind = AvailabilityErrorKind.none;
    notifyListeners();
    try {
      _availability = await _repository.getAvailability(token: token, oduvarId: oduvarId);
      _status = AvailabilityStatus.loaded;
    } catch (e) {
      _fail(e);
      _status = AvailabilityStatus.error;
    }
    notifyListeners();
  }

  // ─── Weekly schedule + booking rules ─────────────────────────────────────

  Future<bool> saveWeekly(
    String token, {
    required List<WeeklyAvailabilityModel> days,
    required BookingRulesModel rules,
  }) async {
    _status = AvailabilityStatus.saving;
    _errorMessage = null;
    _errorKind = AvailabilityErrorKind.none;
    notifyListeners();
    try {
      final saved = await _repository.saveWeekly(token, {
        'days': days.map((d) => d.toJson()).toList(),
        'minimumDurationMinutes': rules.minimumDurationMinutes,
        'maximumDurationMinutes': rules.maximumDurationMinutes,
        'bufferMinutes': rules.bufferMinutes,
      });
      _availability = AvailabilityModel(
        rules: saved.rules,
        weekly: saved.weekly,
        overrides: _availability.overrides,
      );
      _invalidateCalendar();
      _status = AvailabilityStatus.loaded;
      notifyListeners();
      return true;
    } catch (e) {
      _fail(e);
      _status = AvailabilityStatus.error;
      notifyListeners();
      return false;
    }
  }

  // ─── Overrides ───────────────────────────────────────────────────────────

  List<AvailabilityOverrideModel> _sorted(List<AvailabilityOverrideModel> l) =>
      [...l]..sort((a, b) => a.date.compareTo(b.date));

  Future<bool> _mutate(Future<List<AvailabilityOverrideModel>> Function() op) async {
    _status = AvailabilityStatus.saving;
    _errorMessage = null;
    _errorKind = AvailabilityErrorKind.none;
    notifyListeners();
    try {
      final next = await op();
      _availability = AvailabilityModel(
        rules: _availability.rules,
        weekly: _availability.weekly,
        overrides: _sorted(next),
      );
      _invalidateCalendar();
      _status = AvailabilityStatus.loaded;
      notifyListeners();
      return true;
    } catch (e) {
      _fail(e);
      _status = AvailabilityStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> createOverride(String token, AvailabilityOverrideModel o) => _mutate(() async {
        final created = await _repository.createOverride(token, o.toPayload());
        return [..._availability.overrides, created];
      });

  Future<bool> updateOverride(String token, AvailabilityOverrideModel o) => _mutate(() async {
        final updated = await _repository.updateOverride(token, o.id, o.toPayload());
        return _availability.overrides.map((x) => x.id == o.id ? updated : x).toList();
      });

  Future<bool> deleteOverride(String token, String id) => _mutate(() async {
        await _repository.deleteOverride(token, id);
        return _availability.overrides.where((x) => x.id != id).toList();
      });

  // ─── Calendar (all availability is computed by the backend) ───────────────

  Future<void> loadMonth({
    String? token,
    String? oduvarId,
    required String month,
    int? durationMinutes,
  }) async {
    _monthLoading = true;
    _errorMessage = null;
    _errorKind = AvailabilityErrorKind.none;
    notifyListeners();
    try {
      final m = await _repository.getMonth(
        token: token,
        oduvarId: oduvarId,
        month: month,
        durationMinutes: durationMinutes,
      );
      _months[month] = m.days;
    } catch (e) {
      _fail(e);
    }
    _monthLoading = false;
    notifyListeners();
  }

  Future<void> loadDay({
    String? token,
    String? oduvarId,
    required String date,
    int? durationMinutes,
  }) async {
    _dayLoading = true;
    _selectedDay = null;
    _errorMessage = null;
    _errorKind = AvailabilityErrorKind.none;
    notifyListeners();
    try {
      _selectedDay = await _repository.getDay(
        token: token,
        oduvarId: oduvarId,
        date: date,
        durationMinutes: durationMinutes,
      );
    } catch (e) {
      _fail(e);
    }
    _dayLoading = false;
    notifyListeners();
  }

  void clearMonths() {
    _months.clear();
    _selectedDay = null;
  }
}
