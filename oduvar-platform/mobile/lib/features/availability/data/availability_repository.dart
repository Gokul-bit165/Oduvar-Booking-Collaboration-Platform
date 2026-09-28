import 'package:oduvar_mobile/core/network/api_client.dart';
import 'package:oduvar_mobile/core/constants/api_constants.dart';
import '../models/availability_model.dart';

class MonthAvailability {
  final String month;
  final List<CalendarDayModel> days;
  const MonthAvailability({required this.month, required this.days});
}

/// Thin API layer. When [oduvarId] is null the owner ("me") endpoints are used
/// and a token is required; otherwise the public read-only endpoint is used.
class AvailabilityRepository {
  final ApiClient _client;

  AvailabilityRepository({ApiClient? client}) : _client = client ?? ApiClient();

  String _base(String? oduvarId) =>
      oduvarId == null ? ApiConstants.myAvailability : ApiConstants.publicAvailability(oduvarId);

  Future<AvailabilityModel> getAvailability({String? token, String? oduvarId}) async {
    final data = await _client.get(_base(oduvarId), token: token);
    return AvailabilityModel.fromJson(data as Map<String, dynamic>);
  }

  Future<AvailabilityModel> saveWeekly(String token, Map<String, dynamic> payload) async {
    final data = await _client.put(ApiConstants.myWeeklyAvailability, token: token, body: payload);
    return AvailabilityModel.fromJson(data as Map<String, dynamic>);
  }

  Future<List<AvailabilityOverrideModel>> getOverrides(String token) async {
    final data = await _client.get(ApiConstants.myAvailabilityOverrides, token: token);
    return (data['overrides'] as List? ?? [])
        .map((o) => AvailabilityOverrideModel.fromJson(o as Map<String, dynamic>))
        .toList();
  }

  Future<AvailabilityOverrideModel> createOverride(String token, Map<String, dynamic> payload) async {
    final data = await _client.post(ApiConstants.myAvailabilityOverrides, token: token, body: payload);
    return AvailabilityOverrideModel.fromJson(data['override'] as Map<String, dynamic>);
  }

  Future<AvailabilityOverrideModel> updateOverride(
      String token, String id, Map<String, dynamic> payload) async {
    final data = await _client.put(ApiConstants.myAvailabilityOverride(id), token: token, body: payload);
    return AvailabilityOverrideModel.fromJson(data['override'] as Map<String, dynamic>);
  }

  Future<void> deleteOverride(String token, String id) async {
    await _client.delete(ApiConstants.myAvailabilityOverride(id), token: token);
  }

  /// Per-day status for a month (YYYY-MM), computed by the backend.
  Future<MonthAvailability> getMonth({
    String? token,
    String? oduvarId,
    required String month,
    int? durationMinutes,
  }) async {
    final q = 'month=$month${durationMinutes != null ? '&duration=$durationMinutes' : ''}';
    final data = await _client.get('${_base(oduvarId)}?$q', token: token);
    return MonthAvailability(
      month: month,
      days: (data['days'] as List? ?? [])
          .map((d) => CalendarDayModel.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Backend-generated bookable start times for one date.
  Future<DayAvailabilityModel> getDay({
    String? token,
    String? oduvarId,
    required String date,
    int? durationMinutes,
  }) async {
    final q = 'date=$date${durationMinutes != null ? '&duration=$durationMinutes' : ''}';
    final data = await _client.get('${_base(oduvarId)}?$q', token: token);
    return DayAvailabilityModel.fromJson(data['day'] as Map<String, dynamic>);
  }
}
