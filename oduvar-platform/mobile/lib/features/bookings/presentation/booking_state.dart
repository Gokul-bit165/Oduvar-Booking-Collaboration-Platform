import 'package:flutter/foundation.dart';
import 'package:oduvar_mobile/core/network/api_exceptions.dart';
import '../data/booking_repository.dart';
import '../models/booking_model.dart';

enum BookingListStatus { initial, loading, loaded, error }

enum BookingErrorKind { none, unauthorized, network, conflict, validation, other }

/// Bookings lists + actions for both roles. (The guided booking flow keeps its own draft state in
/// [BookingFlowState]; this class is what dashboards, lists and the details screen listen to.)
class BookingState extends ChangeNotifier {
  final BookingRepository _repository;

  BookingState({BookingRepository? repository}) : _repository = repository ?? BookingRepository();

  BookingListStatus _status = BookingListStatus.initial;
  List<BookingModel> _items = [];
  String? _errorMessage;
  BookingErrorKind _errorKind = BookingErrorKind.none;
  String? _busyId; // booking currently being acted on

  BookingListStatus get status => _status;
  bool get isLoading => _status == BookingListStatus.loading;
  List<BookingModel> get items => List.unmodifiable(_items);
  String? get errorMessage => _errorMessage;
  BookingErrorKind get errorKind => _errorKind;
  String? get busyId => _busyId;

  void _fail(Object e) {
    if (e is UnauthorizedException || e is ForbiddenException) {
      _errorKind = BookingErrorKind.unauthorized;
    } else if (e is NetworkException) {
      _errorKind = BookingErrorKind.network;
    } else if (e is ApiException && e.statusCode == 409) {
      _errorKind = BookingErrorKind.conflict;
    } else if (e is ApiException && e.statusCode == 400) {
      _errorKind = BookingErrorKind.validation;
    } else {
      _errorKind = BookingErrorKind.other;
    }
    _errorMessage = e is ApiException ? e.message : e.toString().replaceFirst('Exception: ', '');
  }

  /// Add a booking WITHOUT notifying (safe to call from initState); no-op if it is already present.
  void seed(BookingModel b) {
    if (_items.any((x) => x.id == b.id)) return;
    _items = [b, ..._items];
  }

  /// Add or replace one booking (e.g. the confirmation screen passes the freshly created booking).
  void upsert(BookingModel b) {
    _items = _items.any((x) => x.id == b.id) ? _items.map((x) => x.id == b.id ? b : x).toList() : [b, ..._items];
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    _errorKind = BookingErrorKind.none;
    notifyListeners();
  }

  // ─── Grouping (dates are compared as YYYY-MM-DD strings; "today" is passed in, never read from a clock here) ─────

  // Client dashboard groups
  List<BookingModel> upcoming(String today) =>
      _items.where((b) => b.status == BookingStatus.confirmed && b.date.compareTo(today) >= 0).toList()..sort(_byWhen);
  List<BookingModel> get pending => _items.where((b) => b.status == BookingStatus.pending).toList()..sort(_byWhen);
  List<BookingModel> get completed => _items.where((b) => b.status == BookingStatus.completed).toList();
  List<BookingModel> get cancelled =>
      _items.where((b) => b.status == BookingStatus.cancelled || b.status == BookingStatus.rejected).toList();

  // Oduvar dashboard groups
  List<BookingModel> todays(String today) =>
      _items.where((b) => b.status == BookingStatus.confirmed && b.date == today).toList()..sort(_byWhen);
  List<BookingModel> upcomingConfirmed(String today) =>
      _items.where((b) => b.status == BookingStatus.confirmed && b.date.compareTo(today) > 0).toList()..sort(_byWhen);

  static int _byWhen(BookingModel a, BookingModel b) => '${a.date} ${a.startTime}'.compareTo('${b.date} ${b.startTime}');

  // ─── Loading ─────────────────────────────────────────────────────────────

  Future<void> loadForClient(String token) => _load(() => _repository.listMine(token));
  Future<void> loadForOduvar(String token) => _load(() => _repository.listForOduvar(token));

  Future<void> _load(Future<BookingPage> Function() fetch) async {
    _status = BookingListStatus.loading;
    _errorMessage = null;
    _errorKind = BookingErrorKind.none;
    notifyListeners();
    try {
      _items = (await fetch()).items;
      _status = BookingListStatus.loaded;
    } catch (e) {
      _fail(e);
      _status = BookingListStatus.error;
    }
    notifyListeners();
  }

  // ─── Actions ─────────────────────────────────────────────────────────────

  void _replace(BookingModel updated) {
    _items = _items.map((b) => b.id == updated.id ? updated : b).toList();
  }

  Future<BookingModel?> _act(String id, Future<BookingModel> Function() op) async {
    _busyId = id;
    _errorMessage = null;
    _errorKind = BookingErrorKind.none;
    notifyListeners();
    try {
      final updated = await op();
      _replace(updated);
      _busyId = null;
      notifyListeners();
      return updated;
    } catch (e) {
      _fail(e);
      _busyId = null;
      notifyListeners();
      return null;
    }
  }

  Future<BookingModel?> accept(String token, String id) => _act(id, () => _repository.accept(token, id));
  Future<BookingModel?> reject(String token, String id, {String? reason}) =>
      _act(id, () => _repository.reject(token, id, reason: reason));
  Future<BookingModel?> complete(String token, String id) => _act(id, () => _repository.complete(token, id));
  Future<BookingModel?> cancel(String token, String id, {String? reason}) =>
      _act(id, () => _repository.cancel(token, id, reason: reason));

  /// Refresh one booking (details screen) using the role-appropriate endpoint.
  Future<BookingModel?> refreshOne(String token, String id, {required bool asOduvar}) async {
    try {
      final b = asOduvar ? await _repository.getForOduvar(token, id) : await _repository.getMine(token, id);
      _replace(b);
      notifyListeners();
      return b;
    } catch (e) {
      _fail(e);
      notifyListeners();
      return null;
    }
  }
}
