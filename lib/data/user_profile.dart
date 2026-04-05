class UserProfile {
  UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.updatedAt,
  });

  final String uid;
  final String name;
  final String email;
  final String role;
  final int updatedAt;

  UserProfile copyWith({
    String? uid,
    String? name,
    String? email,
    String? role,
    int? updatedAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'updatedAt': updatedAt,
    };
  }

  static UserProfile fromJson(String uid, Map<dynamic, dynamic> json) {
    return UserProfile(
      uid: uid,
      name: (json['name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      role: (json['role'] as String?) ?? 'staff',
      updatedAt: (json['updatedAt'] as int?) ?? 0,
    );
  }
}
