import 'package:oduvar_mobile/core/network/api_client.dart';
import 'package:oduvar_mobile/core/constants/api_constants.dart';
import '../models/discovery_model.dart';

/// Discovery API access. Searching, filtering, sorting and paging all happen on the server.
class OduvarDiscoveryRepository {
  final ApiClient _client;

  OduvarDiscoveryRepository({ApiClient? client}) : _client = client ?? ApiClient();

  Future<SearchPage> search({
    String search = '',
    OduvarSearchFilters filters = OduvarSearchFilters.empty,
    DiscoverySort sort = DiscoverySort.relevance,
    int page = 1,
    int pageSize = 20,
  }) async {
    final query = <String, String>{
      if (search.trim().isNotEmpty) 'search': search.trim(),
      ...filters.toQuery(),
      'sort': sort.apiValue,
      'page': '$page',
      'pageSize': '$pageSize',
    };
    final qs = Uri(queryParameters: query).query;
    final data = await _client.get('${ApiConstants.oduvarSearch}?$qs');
    return SearchPage.fromJson(data as Map<String, dynamic>);
  }

  /// Filter choices come from the backend reference data (no second hardcoded list in the app).
  Future<DiscoveryFilterOptions> getFilterOptions() async {
    final results = await Future.wait([
      _client.get(ApiConstants.services),
      _client.get(ApiConstants.eventTypes),
      _client.get(ApiConstants.instruments),
      _client.get(ApiConstants.performanceTypes),
    ]);

    final categories = <String>[];
    for (final s in (results[0]['services'] as List? ?? [])) {
      final c = (s as Map<String, dynamic>)['category'] as String?;
      if (c != null && !categories.contains(c)) categories.add(c);
    }

    List<OptionItem> keyLabel(dynamic list) => (list as List? ?? [])
        .map((e) => OptionItem((e as Map)['key'] as String, e['label'] as String))
        .toList();

    return DiscoveryFilterOptions(
      services: [for (final c in categories) OptionItem(c, c)],
      eventTypes: keyLabel(results[1]['eventTypes']),
      instruments: (results[2]['instruments'] as List? ?? [])
          .map((e) => OptionItem((e as Map)['slug'] as String, e['name'] as String))
          .toList(),
      performanceTypes: keyLabel(results[3]['performanceTypes']),
    );
  }
}
