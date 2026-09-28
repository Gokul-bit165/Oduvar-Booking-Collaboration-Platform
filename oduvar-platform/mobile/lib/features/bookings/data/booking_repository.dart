import 'package:oduvar_mobile/core/network/api_client.dart';
import 'package:oduvar_mobile/core/constants/api_constants.dart';
import '../models/booking_model.dart';

/// Booking API access. The create payload never contains an amount: the server prices the booking.
class BookingRepository {
  final ApiClient _client;

  BookingRepository({ApiClient? client}) : _client = client ?? ApiClient();

  // ─── Client ──────────────────────────────────────────────────────────────

  Future<BookingModel> createBooking(String token, Map<String, dynamic> payload) async {
    final data = await _client.post(ApiConstants.bookings, token: token, body: payload);
    return BookingModel.fromJson(data['booking'] as Map<String, dynamic>);
  }

  Future<BookingPage> listMine(String token, {List<BookingStatus>? statuses}) async {
    final qs = _query(statuses);
    final data = await _client.get('${ApiConstants.bookings}$qs', token: token);
    return BookingPage.fromJson(data as Map<String, dynamic>);
  }

  Future<BookingModel> getMine(String token, String id) async {
    final data = await _client.get(ApiConstants.booking(id), token: token);
    return BookingModel.fromJson(data['booking'] as Map<String, dynamic>);
  }

  Future<BookingModel> cancel(String token, String id, {String? reason}) async {
    final data = await _client.post(ApiConstants.cancelBooking(id), token: token, body: {if (reason != null && reason.isNotEmpty) 'reason': reason});
    return BookingModel.fromJson(data['booking'] as Map<String, dynamic>);
  }

  // ─── Oduvar ──────────────────────────────────────────────────────────────

  Future<BookingPage> listForOduvar(String token, {List<BookingStatus>? statuses}) async {
    final qs = _query(statuses);
    final data = await _client.get('${ApiConstants.myOduvarBookings}$qs', token: token);
    return BookingPage.fromJson(data as Map<String, dynamic>);
  }

  Future<BookingModel> getForOduvar(String token, String id) async {
    final data = await _client.get(ApiConstants.oduvarBooking(id), token: token);
    return BookingModel.fromJson(data['booking'] as Map<String, dynamic>);
  }

  Future<BookingModel> accept(String token, String id) => _action(token, id, 'accept');
  Future<BookingModel> complete(String token, String id) => _action(token, id, 'complete');
  Future<BookingModel> reject(String token, String id, {String? reason}) =>
      _action(token, id, 'reject', body: {if (reason != null && reason.isNotEmpty) 'reason': reason});

  Future<BookingModel> _action(String token, String id, String action, {Map<String, dynamic>? body}) async {
    final data = await _client.post(ApiConstants.oduvarBookingAction(id, action), token: token, body: body ?? {});
    return BookingModel.fromJson(data['booking'] as Map<String, dynamic>);
  }

  String _query(List<BookingStatus>? statuses) {
    final q = <String, String>{
      'pageSize': '100',
      if (statuses != null && statuses.isNotEmpty) 'status': statuses.map((s) => s.apiValue).join(','),
    };
    return '?${Uri(queryParameters: q).query}';
  }
}
