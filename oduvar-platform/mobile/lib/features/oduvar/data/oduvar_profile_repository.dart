import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../models/oduvar_profile_model.dart';

class OduvarProfileRepository {
  final ApiClient _client;

  OduvarProfileRepository({ApiClient? client}) : _client = client ?? ApiClient();

  // ─── My Profile ───────────────────────────────────────────────────────────

  Future<OduvarProfileModel?> getMyProfile(String token) async {
    final data = await _client.get('/oduvars/me/profile', token: token);
    final profileJson = data['profile'];
    if (profileJson == null) return null;
    return OduvarProfileModel.fromJson(profileJson as Map<String, dynamic>);
  }

  Future<OduvarProfileModel> createProfile(
      String token, Map<String, dynamic> payload) async {
    final data = await _client.post(
      '/oduvars/me/profile',
      token: token,
      body: payload,
    );
    return OduvarProfileModel.fromJson(
        data['profile'] as Map<String, dynamic>);
  }

  Future<OduvarProfileModel> updateProfile(
      String token, Map<String, dynamic> payload) async {
    final data = await _client.put(
      '/oduvars/me/profile',
      token: token,
      body: payload,
    );
    return OduvarProfileModel.fromJson(
        data['profile'] as Map<String, dynamic>);
  }

  Future<void> deleteProfile(String token) async {
    await _client.delete('/oduvars/me/profile', token: token);
  }

  // ─── Public Profile ───────────────────────────────────────────────────────

  Future<OduvarProfileModel> getPublicProfile(String oduvarId) async {
    final data =
        await _client.get('/oduvars/$oduvarId/profile');
    return OduvarProfileModel.fromJson(
        data['profile'] as Map<String, dynamic>);
  }

  // ─── Photos ───────────────────────────────────────────────────────────────

  Future<OduvarPhotoModel> uploadPhoto(String token, File imageFile) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/oduvars/me/profile/photos');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('photo', imageFile.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 201 && decoded['success'] == true) {
      return OduvarPhotoModel.fromJson(
          decoded['data']['photo'] as Map<String, dynamic>);
    }
    final err = decoded['error'] ?? {};
    throw Exception(err['message'] ?? 'Photo upload failed');
  }

  Future<void> deletePhoto(String token, String photoId) async {
    await _client.delete(
        '/oduvars/me/profile/photos/$photoId', token: token);
  }

  Future<void> reorderPhotos(
      String token, List<Map<String, dynamic>> photos) async {
    await _client.put(
      '/oduvars/me/profile/photos/reorder',
      token: token,
      body: {'photos': photos},
    );
  }

  // ─── Reference data ───────────────────────────────────────────────────────

  Future<List<SkillModel>> getSkills() async {
    final data = await _client.get('/skills');
    return (data['skills'] as List)
        .map((s) => SkillModel.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  Future<List<InstrumentModel>> getInstruments() async {
    final data = await _client.get('/instruments');
    return (data['instruments'] as List)
        .map((i) => InstrumentModel.fromJson(i as Map<String, dynamic>))
        .toList();
  }

  Future<List<Map<String, String>>> getSongCategories() async {
    final data = await _client.get('/song-categories');
    return (data['songCategories'] as List)
        .map((c) => Map<String, String>.from(c as Map))
        .toList();
  }

  Future<List<String>> getPerformanceTypes() async {
    final data = await _client.get('/performance-types');
    return (data['performanceTypes'] as List)
        .map((t) => (t as Map)['key'] as String)
        .toList();
  }
}
