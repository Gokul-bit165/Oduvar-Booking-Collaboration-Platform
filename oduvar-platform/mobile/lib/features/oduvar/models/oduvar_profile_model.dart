// Phase 2: Oduvar Profile data models

class OduvarPhotoModel {
  final String id;
  final String imageUrl;
  final int displayOrder;

  const OduvarPhotoModel({
    required this.id,
    required this.imageUrl,
    required this.displayOrder,
  });

  factory OduvarPhotoModel.fromJson(Map<String, dynamic> json) => OduvarPhotoModel(
        id: json['id'] as String,
        imageUrl: json['imageUrl'] as String,
        displayOrder: json['displayOrder'] as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'imageUrl': imageUrl,
        'displayOrder': displayOrder,
      };
}

class SkillModel {
  final String id;
  final String name;
  final String slug;

  const SkillModel({required this.id, required this.name, required this.slug});

  factory SkillModel.fromJson(Map<String, dynamic> json) => SkillModel(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
      );
}

class InstrumentModel {
  final String id;
  final String name;
  final String slug;

  const InstrumentModel({required this.id, required this.name, required this.slug});

  factory InstrumentModel.fromJson(Map<String, dynamic> json) => InstrumentModel(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
      );
}

class ProfileOwnerModel {
  final String id;
  final String name;
  final String? profilePhoto;
  final String? phone; // only on private profile

  const ProfileOwnerModel({
    required this.id,
    required this.name,
    this.profilePhoto,
    this.phone,
  });

  factory ProfileOwnerModel.fromJson(Map<String, dynamic> json) => ProfileOwnerModel(
        id: json['id'] as String,
        name: json['name'] as String,
        profilePhoto: json['profilePhoto'] as String?,
        phone: json['phone'] as String?,
      );
}

class OduvarProfileModel {
  final String id;
  final bool isPublished;
  final String? bio;
  final String? location;
  final List<String> performanceTypes;
  final List<String> songCategories;
  final String transport;
  final bool collaborationEnabled;
  final ProfileOwnerModel owner;
  final List<OduvarPhotoModel> photos;
  final List<SkillModel> skills;
  final List<InstrumentModel> instruments;
  final DateTime? updatedAt;

  const OduvarProfileModel({
    required this.id,
    required this.isPublished,
    this.bio,
    this.location,
    required this.performanceTypes,
    required this.songCategories,
    required this.transport,
    required this.collaborationEnabled,
    required this.owner,
    required this.photos,
    required this.skills,
    required this.instruments,
    this.updatedAt,
  });

  factory OduvarProfileModel.fromJson(Map<String, dynamic> json) {
    return OduvarProfileModel(
      id: json['id'] as String,
      isPublished: json['isPublished'] as bool? ?? false,
      bio: json['bio'] as String?,
      location: json['location'] as String?,
      performanceTypes: List<String>.from(json['performanceTypes'] as List? ?? []),
      songCategories: List<String>.from(json['songCategories'] as List? ?? []),
      transport: json['transport'] as String? ?? 'TO_BE_DISCUSSED',
      collaborationEnabled: json['collaborationEnabled'] as bool? ?? true,
      owner: ProfileOwnerModel.fromJson(json['owner'] as Map<String, dynamic>),
      photos: (json['photos'] as List? ?? [])
          .map((p) => OduvarPhotoModel.fromJson(p as Map<String, dynamic>))
          .toList(),
      skills: (json['skills'] as List? ?? [])
          .map((s) => SkillModel.fromJson(s as Map<String, dynamic>))
          .toList(),
      instruments: (json['instruments'] as List? ?? [])
          .map((i) => InstrumentModel.fromJson(i as Map<String, dynamic>))
          .toList(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  /// Calculate profile completion percentage (0–100)
  int get completionPercentage {
    int score = 0;
    const total = 9;
    if (owner.name.isNotEmpty) score++;
    if (owner.profilePhoto != null) score++;
    if (bio != null && bio!.isNotEmpty) score++;
    if (location != null && location!.isNotEmpty) score++;
    if (skills.isNotEmpty) score++;
    if (performanceTypes.isNotEmpty) score++;
    if (songCategories.isNotEmpty) score++;
    if (instruments.isNotEmpty) score++;
    // transport is always set (default), so always counts
    score++;
    return ((score / total) * 100).round();
  }

  OduvarProfileModel copyWith({
    String? bio,
    String? location,
    List<String>? performanceTypes,
    List<String>? songCategories,
    String? transport,
    bool? collaborationEnabled,
    bool? isPublished,
    List<OduvarPhotoModel>? photos,
    List<SkillModel>? skills,
    List<InstrumentModel>? instruments,
  }) {
    return OduvarProfileModel(
      id: id,
      isPublished: isPublished ?? this.isPublished,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      performanceTypes: performanceTypes ?? this.performanceTypes,
      songCategories: songCategories ?? this.songCategories,
      transport: transport ?? this.transport,
      collaborationEnabled: collaborationEnabled ?? this.collaborationEnabled,
      owner: owner,
      photos: photos ?? this.photos,
      skills: skills ?? this.skills,
      instruments: instruments ?? this.instruments,
      updatedAt: updatedAt,
    );
  }
}

class ReferenceDataModel {
  final List<SkillModel> skills;
  final List<InstrumentModel> instruments;
  final List<String> performanceTypes;
  final List<Map<String, String>> songCategories;

  const ReferenceDataModel({
    required this.skills,
    required this.instruments,
    required this.performanceTypes,
    required this.songCategories,
  });
}
