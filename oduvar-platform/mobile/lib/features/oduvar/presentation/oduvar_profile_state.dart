import 'dart:io';
import 'package:flutter/foundation.dart';
import '../data/oduvar_profile_repository.dart';
import '../models/oduvar_profile_model.dart';

enum ProfileStatus { initial, loading, loaded, saving, error }

class OduvarProfileState extends ChangeNotifier {
  final OduvarProfileRepository _repo;

  OduvarProfileState({OduvarProfileRepository? repository})
      : _repo = repository ?? OduvarProfileRepository();

  ProfileStatus _status = ProfileStatus.initial;
  OduvarProfileModel? _profile;
  String? _errorMessage;

  // Reference data
  List<SkillModel> _availableSkills = [];
  List<InstrumentModel> _availableInstruments = [];
  List<String> _performanceTypes = [];
  List<Map<String, String>> _songCategories = [];
  bool _referenceDataLoaded = false;

  // Getters
  ProfileStatus get status => _status;
  OduvarProfileModel? get profile => _profile;
  String? get errorMessage => _errorMessage;
  List<SkillModel> get availableSkills => _availableSkills;
  List<InstrumentModel> get availableInstruments => _availableInstruments;
  List<String> get performanceTypes => _performanceTypes;
  List<Map<String, String>> get songCategories => _songCategories;
  bool get referenceDataLoaded => _referenceDataLoaded;
  bool get hasProfile => _profile != null;

  // ─── Load my profile ───────────────────────────────────────────────────────

  Future<void> loadMyProfile(String token) async {
    _status = ProfileStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _profile = await _repo.getMyProfile(token);
      _status = ProfileStatus.loaded;
    } catch (e) {
      _status = ProfileStatus.error;
      _errorMessage = _friendlyError(e);
    }
    notifyListeners();
  }

  // ─── Save / create / update ────────────────────────────────────────────────

  Future<bool> saveProfile(String token, Map<String, dynamic> payload) async {
    _status = ProfileStatus.saving;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_profile == null) {
        _profile = await _repo.createProfile(token, payload);
      } else {
        _profile = await _repo.updateProfile(token, payload);
      }
      _status = ProfileStatus.loaded;
      notifyListeners();
      return true;
    } catch (e) {
      _status = ProfileStatus.error;
      _errorMessage = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  // ─── Photo management ──────────────────────────────────────────────────────

  Future<bool> uploadPhoto(String token, File imageFile) async {
    if (_profile == null) return false;
    if (_profile!.photos.length >= 5) {
      _errorMessage = 'Maximum 5 gallery photos allowed';
      notifyListeners();
      return false;
    }

    try {
      final photo = await _repo.uploadPhoto(token, imageFile);
      _profile = _profile!.copyWith(
        photos: [..._profile!.photos, photo],
      );
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deletePhoto(String token, String photoId) async {
    if (_profile == null) return false;
    try {
      await _repo.deletePhoto(token, photoId);
      _profile = _profile!.copyWith(
        photos: _profile!.photos.where((p) => p.id != photoId).toList(),
      );
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> reorderPhotos(
      String token, List<Map<String, dynamic>> reorderPayload) async {
    if (_profile == null) return false;
    try {
      await _repo.reorderPhotos(token, reorderPayload);
      // Refresh profile to get updated order
      await loadMyProfile(token);
      return true;
    } catch (e) {
      _errorMessage = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  // ─── Reference data ────────────────────────────────────────────────────────

  Future<void> loadReferenceData() async {
    if (_referenceDataLoaded) return;
    try {
      final results = await Future.wait([
        _repo.getSkills(),
        _repo.getInstruments(),
        _repo.getSongCategories(),
        _repo.getPerformanceTypes(),
      ]);
      _availableSkills = results[0] as List<SkillModel>;
      _availableInstruments = results[1] as List<InstrumentModel>;
      _songCategories = results[2] as List<Map<String, String>>;
      _performanceTypes = results[3] as List<String>;
      _referenceDataLoaded = true;
      notifyListeners();
    } catch (_) {
      // Non-fatal: fallback to local defaults
    }
  }

  // ─── Reset ─────────────────────────────────────────────────────────────────

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void reset() {
    _profile = null;
    _status = ProfileStatus.initial;
    _errorMessage = null;
    notifyListeners();
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('PROFILE_PHOTO_LIMIT')) return 'Maximum 5 gallery photos allowed';
    if (msg.contains('PHOTO_NOT_FOUND')) return 'Photo not found';
    if (msg.contains('PHOTO_FORBIDDEN')) return 'You do not own this photo';
    if (msg.contains('PROFILE_NOT_FOUND')) return 'Profile not found';
    if (msg.contains('PROFILE_EXISTS')) return 'Profile already exists';
    if (msg.contains('SocketException') || msg.contains('NetworkException')) {
      return 'Cannot connect to server. Check your network.';
    }
    return 'Something went wrong. Please try again.';
  }
}
