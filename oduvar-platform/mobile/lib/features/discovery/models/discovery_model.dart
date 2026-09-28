// Phase 5: discovery / search models.

/// Small id + name (+ optional category) reference used for skills, instruments and services on a card.
class DiscoveryTag {
  final String id;
  final String name;
  final String? category;

  const DiscoveryTag({required this.id, required this.name, this.category});

  factory DiscoveryTag.fromJson(Map<String, dynamic> j) => DiscoveryTag(
        id: j['id'] as String,
        name: j['name'] as String,
        category: j['category'] as String?,
      );
}

/// Public-safe search result. Contains no phone/email/auth data.
class OduvarDiscoveryModel {
  /// The Oduvar's user id: used by the public profile / services / availability endpoints.
  final String id;
  final String profileId;
  final String name;
  final String? profilePhoto;
  final String? location;
  final String? bioPreview;
  final List<DiscoveryTag> skills;
  final List<String> performanceTypes;
  final List<String> songCategories;
  final List<String> eventTypes;
  final List<DiscoveryTag> instruments;
  final List<DiscoveryTag> services;
  final String transport;
  final bool collaborationEnabled;

  /// null when the Oduvar has no reviews (never a fabricated 0).
  final double? rating;
  final int reviewCount;

  const OduvarDiscoveryModel({
    required this.id,
    required this.profileId,
    required this.name,
    this.profilePhoto,
    this.location,
    this.bioPreview,
    this.skills = const [],
    this.performanceTypes = const [],
    this.songCategories = const [],
    this.eventTypes = const [],
    this.instruments = const [],
    this.services = const [],
    this.transport = 'TO_BE_DISCUSSED',
    this.collaborationEnabled = true,
    this.rating,
    this.reviewCount = 0,
  });

  factory OduvarDiscoveryModel.fromJson(Map<String, dynamic> j) {
    List<DiscoveryTag> tags(String key) =>
        (j[key] as List? ?? []).map((e) => DiscoveryTag.fromJson(e as Map<String, dynamic>)).toList();
    List<String> strings(String key) => List<String>.from(j[key] as List? ?? []);
    return OduvarDiscoveryModel(
      id: j['id'] as String,
      profileId: j['profileId'] as String? ?? '',
      name: j['name'] as String,
      profilePhoto: j['profilePhoto'] as String?,
      location: j['location'] as String?,
      bioPreview: j['bioPreview'] as String?,
      skills: tags('skills'),
      performanceTypes: strings('performanceTypes'),
      songCategories: strings('songCategories'),
      eventTypes: strings('eventTypes'),
      instruments: tags('instruments'),
      services: tags('services'),
      transport: j['transport'] as String? ?? 'TO_BE_DISCUSSED',
      collaborationEnabled: j['collaborationEnabled'] as bool? ?? true,
      rating: (j['rating'] as num?)?.toDouble(),
      reviewCount: j['reviewCount'] as int? ?? 0,
    );
  }

  /// Distinct service categories the Oduvar currently offers (active services only; the API filters them).
  List<String> get serviceCategories {
    final seen = <String>[];
    for (final s in services) {
      final c = s.category ?? s.name;
      if (!seen.contains(c)) seen.add(c);
    }
    return seen;
  }
}

class SearchPage {
  final List<OduvarDiscoveryModel> items;
  final int page;
  final int pageSize;
  final int total;
  final bool hasNext;

  const SearchPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.hasNext,
  });

  factory SearchPage.fromJson(Map<String, dynamic> j) => SearchPage(
        items: (j['items'] as List? ?? [])
            .map((e) => OduvarDiscoveryModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        page: j['page'] as int? ?? 1,
        pageSize: j['pageSize'] as int? ?? 20,
        total: j['total'] as int? ?? 0,
        hasNext: j['hasNext'] as bool? ?? false,
      );
}

enum DiscoverySort { relevance, name, location, rating }

extension DiscoverySortX on DiscoverySort {
  String get apiValue => name;
  String get label {
    switch (this) {
      case DiscoverySort.relevance:
        return 'Relevance';
      case DiscoverySort.name:
        return 'Name';
      case DiscoverySort.location:
        return 'Location';
      case DiscoverySort.rating:
        return 'Top rated';
    }
  }
}

/// Filters chosen in the filter sheet. Search text and sort are tracked separately.
/// Immutable; use [copyWith] (pass [clearX] flags to unset a value).
class OduvarSearchFilters {
  final String? location;
  final String? service; // service category, e.g. "Thevaram"
  final String? eventType; // key, e.g. TEMPLE
  final String? instrument; // slug
  final String? performanceType; // VOCAL | INSTRUMENTAL | BOTH
  final String? transport; // INCLUDED | NOT_INCLUDED | ADDITIONAL_FEE | TO_BE_DISCUSSED
  final String? availableDate; // YYYY-MM-DD
  final int? availableDuration; // minutes (requires availableDate)

  const OduvarSearchFilters({
    this.location,
    this.service,
    this.eventType,
    this.instrument,
    this.performanceType,
    this.transport,
    this.availableDate,
    this.availableDuration,
  });

  static const OduvarSearchFilters empty = OduvarSearchFilters();

  /// Number of filters currently set (the sort order and search text are not filters).
  int get activeCount => [
        location,
        service,
        eventType,
        instrument,
        performanceType,
        transport,
        availableDate,
        availableDuration,
      ].where((v) => v != null && v.toString().isNotEmpty).length;

  bool get isEmpty => activeCount == 0;

  OduvarSearchFilters copyWith({
    String? location,
    String? service,
    String? eventType,
    String? instrument,
    String? performanceType,
    String? transport,
    String? availableDate,
    int? availableDuration,
    bool clearLocation = false,
    bool clearService = false,
    bool clearEventType = false,
    bool clearInstrument = false,
    bool clearPerformanceType = false,
    bool clearTransport = false,
    bool clearAvailableDate = false,
    bool clearAvailableDuration = false,
  }) {
    final dateCleared = clearAvailableDate;
    return OduvarSearchFilters(
      location: clearLocation ? null : (location ?? this.location),
      service: clearService ? null : (service ?? this.service),
      eventType: clearEventType ? null : (eventType ?? this.eventType),
      instrument: clearInstrument ? null : (instrument ?? this.instrument),
      performanceType: clearPerformanceType ? null : (performanceType ?? this.performanceType),
      transport: clearTransport ? null : (transport ?? this.transport),
      availableDate: dateCleared ? null : (availableDate ?? this.availableDate),
      // A duration is meaningless without a date (the API rejects it), so it goes with the date.
      availableDuration:
          (dateCleared || clearAvailableDuration) ? null : (availableDuration ?? this.availableDuration),
    );
  }

  Map<String, String> toQuery() => {
        if (location != null && location!.trim().isNotEmpty) 'location': location!.trim(),
        'service': ?service,
        'eventType': ?eventType,
        'instrument': ?instrument,
        'performanceType': ?performanceType,
        'transport': ?transport,
        'availableDate': ?availableDate,
        if (availableDate != null && availableDuration != null) 'availableDuration': '$availableDuration',
      };

  @override
  bool operator ==(Object other) =>
      other is OduvarSearchFilters &&
      other.location == location &&
      other.service == service &&
      other.eventType == eventType &&
      other.instrument == instrument &&
      other.performanceType == performanceType &&
      other.transport == transport &&
      other.availableDate == availableDate &&
      other.availableDuration == availableDuration;

  @override
  int get hashCode => Object.hash(location, service, eventType, instrument, performanceType, transport,
      availableDate, availableDuration);
}

class OptionItem {
  final String key;
  final String label;
  const OptionItem(this.key, this.label);
}

/// Choices offered in the UI, loaded from the backend reference endpoints
/// (services, event types, instruments, performance types). Transport values are
/// a fixed contract of the backend enum.
class DiscoveryFilterOptions {
  final List<OptionItem> services; // key = category
  final List<OptionItem> eventTypes;
  final List<OptionItem> instruments; // key = slug
  final List<OptionItem> performanceTypes;

  const DiscoveryFilterOptions({
    this.services = const [],
    this.eventTypes = const [],
    this.instruments = const [],
    this.performanceTypes = const [],
  });

  static const List<OptionItem> transports = [
    OptionItem('INCLUDED', 'Included'),
    OptionItem('NOT_INCLUDED', 'Not Included'),
    OptionItem('ADDITIONAL_FEE', 'Additional Fee'),
    OptionItem('TO_BE_DISCUSSED', 'To Be Discussed'),
  ];

  bool get isEmpty =>
      services.isEmpty && eventTypes.isEmpty && instruments.isEmpty && performanceTypes.isEmpty;
}

String transportLabel(String key) {
  for (final t in DiscoveryFilterOptions.transports) {
    if (t.key == key) return t.label;
  }
  return key;
}

String performanceLabel(String key) => key.isEmpty ? key : key[0] + key.substring(1).toLowerCase();
