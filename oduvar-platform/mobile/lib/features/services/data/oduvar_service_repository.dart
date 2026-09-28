import 'package:oduvar_mobile/core/network/api_client.dart';
import 'package:oduvar_mobile/core/constants/api_constants.dart';
import '../models/service_model.dart';

class OduvarServiceRepository {
  final ApiClient _client;

  OduvarServiceRepository({ApiClient? client}) : _client = client ?? ApiClient();

  // ─── Reference Services ────────────────────────────────────────────────────

  Future<List<ServiceModel>> getBaseServices() async {
    final data = await _client.get(ApiConstants.services);
    final rawList = data['services'] as List? ?? [];
    return rawList.map((s) => ServiceModel.fromJson(s as Map<String, dynamic>)).toList();
  }

  // ─── My Services ───────────────────────────────────────────────────────────

  Future<List<OduvarServiceModel>> getMyServices(String token) async {
    final data = await _client.get(ApiConstants.myServices, token: token);
    final rawList = data['services'] as List? ?? [];
    return rawList.map((s) => OduvarServiceModel.fromJson(s as Map<String, dynamic>)).toList();
  }

  Future<OduvarServiceModel> createService(
      String token, Map<String, dynamic> payload) async {
    final data = await _client.post(
      ApiConstants.myServices,
      token: token,
      body: payload,
    );
    return OduvarServiceModel.fromJson(data['service'] as Map<String, dynamic>);
  }

  Future<OduvarServiceModel> updateService(
      String token, String serviceId, Map<String, dynamic> payload) async {
    final data = await _client.put(
      ApiConstants.oduvarService(serviceId),
      token: token,
      body: payload,
    );
    return OduvarServiceModel.fromJson(data['service'] as Map<String, dynamic>);
  }

  Future<void> deleteService(String token, String serviceId) async {
    await _client.delete(
      ApiConstants.oduvarService(serviceId),
      token: token,
    );
  }

  // ─── Pricing management ────────────────────────────────────────────────────

  Future<PricingModel> createPricing(
      String token, String serviceId, Map<String, dynamic> payload) async {
    final data = await _client.post(
      ApiConstants.servicePricing(serviceId),
      token: token,
      body: payload,
    );
    return PricingModel.fromJson(data['pricing'] as Map<String, dynamic>);
  }

  Future<PricingModel> updatePricing(
      String token, String serviceId, String pricingId, Map<String, dynamic> payload) async {
    final data = await _client.put(
      ApiConstants.servicePricingItem(serviceId, pricingId),
      token: token,
      body: payload,
    );
    return PricingModel.fromJson(data['pricing'] as Map<String, dynamic>);
  }

  Future<void> deletePricing(String token, String serviceId, String pricingId) async {
    await _client.delete(
      ApiConstants.servicePricingItem(serviceId, pricingId),
      token: token,
    );
  }

  // ─── Public Services ───────────────────────────────────────────────────────

  Future<List<OduvarServiceModel>> getPublicOduvarServices(String oduvarId) async {
    final data = await _client.get(ApiConstants.publicOduvarServices(oduvarId));
    final rawList = data['services'] as List? ?? [];
    return rawList.map((s) => OduvarServiceModel.fromJson(s as Map<String, dynamic>)).toList();
  }
}
