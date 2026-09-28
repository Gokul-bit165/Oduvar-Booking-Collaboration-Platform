import 'package:flutter/foundation.dart';
import '../models/service_model.dart';
import '../data/oduvar_service_repository.dart';

enum ServiceStateStatus { initial, loading, loaded, saving, error }

class OduvarServiceState extends ChangeNotifier {
  final OduvarServiceRepository _repository;

  ServiceStateStatus _status = ServiceStateStatus.initial;
  String? _errorMessage;
  List<OduvarServiceModel> _services = [];
  List<ServiceModel> _availableBaseServices = [];

  OduvarServiceState({OduvarServiceRepository? repository})
      : _repository = repository ?? OduvarServiceRepository();

  ServiceStateStatus get status => _status;
  bool get isLoading => _status == ServiceStateStatus.loading;
  bool get isSaving => _status == ServiceStateStatus.saving;
  String? get errorMessage => _errorMessage;
  List<OduvarServiceModel> get services => List.unmodifiable(_services);
  List<ServiceModel> get availableBaseServices => List.unmodifiable(_availableBaseServices);

  List<OduvarServiceModel> get activeServices =>
      _services.where((s) => s.isActive).toList();

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ─── Load Reference Services ───────────────────────────────────────────────

  Future<void> loadBaseServices() async {
    try {
      _availableBaseServices = await _repository.getBaseServices();
      notifyListeners();
    } catch (_) {
      // Keep cached or fallback silently
    }
  }

  // ─── Load My Services ──────────────────────────────────────────────────────

  Future<void> loadMyServices(String token) async {
    _status = ServiceStateStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await loadBaseServices();
      _services = await _repository.getMyServices(token);
      _status = ServiceStateStatus.loaded;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _status = ServiceStateStatus.error;
    }
    notifyListeners();
  }

  // ─── Create Service ────────────────────────────────────────────────────────

  Future<bool> createService(String token, Map<String, dynamic> payload) async {
    _status = ServiceStateStatus.saving;
    _errorMessage = null;
    notifyListeners();

    try {
      final newService = await _repository.createService(token, payload);
      _services = [..._services, newService];
      _status = ServiceStateStatus.loaded;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _status = ServiceStateStatus.error;
      notifyListeners();
      return false;
    }
  }

  // ─── Update Service ────────────────────────────────────────────────────────

  Future<bool> updateService(
      String token, String serviceId, Map<String, dynamic> payload) async {
    _status = ServiceStateStatus.saving;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _repository.updateService(token, serviceId, payload);
      _services = _services.map((s) => s.id == serviceId ? updated : s).toList();
      _status = ServiceStateStatus.loaded;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _status = ServiceStateStatus.error;
      notifyListeners();
      return false;
    }
  }

  // ─── Toggle Service Active ─────────────────────────────────────────────────

  Future<bool> toggleServiceActive(String token, OduvarServiceModel service) async {
    final newActive = !service.isActive;
    return updateService(token, service.id, {'isActive': newActive});
  }

  // ─── Delete Service ────────────────────────────────────────────────────────

  Future<bool> deleteService(String token, String serviceId) async {
    _status = ServiceStateStatus.saving;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.deleteService(token, serviceId);
      _services = _services.where((s) => s.id != serviceId).toList();
      _status = ServiceStateStatus.loaded;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _status = ServiceStateStatus.error;
      notifyListeners();
      return false;
    }
  }

  // ─── Pricing Operations ───────────────────────────────────────────────────

  Future<bool> addPricing(
      String token, String serviceId, int durationMinutes, double amount) async {
    try {
      final newPricing = await _repository.createPricing(token, serviceId, {
        'durationMinutes': durationMinutes,
        'amount': amount,
        'currency': 'INR',
      });

      _services = _services.map((s) {
        if (s.id == serviceId) {
          final updatedPricings = [...s.pricings, newPricing]
            ..sort((a, b) => a.durationMinutes.compareTo(b.durationMinutes));
          return OduvarServiceModel(
            id: s.id,
            profileId: s.profileId,
            serviceId: s.serviceId,
            name: s.name,
            category: s.category,
            baseDescription: s.baseDescription,
            customDescription: s.customDescription,
            transport: s.transport,
            transportFee: s.transportFee,
            isActive: s.isActive,
            pricings: updatedPricings,
          );
        }
        return s;
      }).toList();

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deletePricing(
      String token, String serviceId, String pricingId) async {
    try {
      await _repository.deletePricing(token, serviceId, pricingId);

      _services = _services.map((s) {
        if (s.id == serviceId) {
          return OduvarServiceModel(
            id: s.id,
            profileId: s.profileId,
            serviceId: s.serviceId,
            name: s.name,
            category: s.category,
            baseDescription: s.baseDescription,
            customDescription: s.customDescription,
            transport: s.transport,
            transportFee: s.transportFee,
            isActive: s.isActive,
            pricings: s.pricings.where((p) => p.id != pricingId).toList(),
          );
        }
        return s;
      }).toList();

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
}
