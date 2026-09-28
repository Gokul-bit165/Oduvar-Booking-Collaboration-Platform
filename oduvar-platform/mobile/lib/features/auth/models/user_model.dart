enum UserRole {
  client,
  oduvar,
  admin;

  static UserRole fromString(String val) {
    switch (val.toUpperCase()) {
      case 'ODUVAR':
        return UserRole.oduvar;
      case 'ADMIN':
        return UserRole.admin;
      case 'CLIENT':
      default:
        return UserRole.client;
    }
  }

  String toServerString() {
    switch (this) {
      case UserRole.oduvar:
        return 'ODUVAR';
      case UserRole.admin:
        return 'ADMIN';
      case UserRole.client:
        return 'CLIENT';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.oduvar:
        return 'Oduvar (Sacred Hymn Singer)';
      case UserRole.admin:
        return 'Platform Administrator';
      case UserRole.client:
        return 'Devotee / Client';
    }
  }
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final String? profilePhoto;
  final DateTime? createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.profilePhoto,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      role: UserRole.fromString(json['role'] as String? ?? 'CLIENT'),
      profilePhoto: json['profilePhoto'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role.toServerString(),
      'profilePhoto': profilePhoto,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
