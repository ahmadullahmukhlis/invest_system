import 'permissions.dart';

class UserProfile {
  UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.permissions,
    required this.updatedAt,
  });

  final String uid;
  final String name;
  final String email;
  final String role;
  final Map<String, PermissionSet> permissions;
  final int updatedAt;

  UserProfile copyWith({
    String? uid,
    String? name,
    String? email,
    String? role,
    Map<String, PermissionSet>? permissions,
    int? updatedAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'permissions': permissions.map((key, value) => MapEntry(key, value.toJson())),
      'updatedAt': updatedAt,
    };
  }

  static UserProfile fromJson(String uid, Map<dynamic, dynamic> json) {
    final permsRaw = json['permissions'];
    final perms = <String, PermissionSet>{};
    if (permsRaw is Map) {
      for (final entry in permsRaw.entries) {
        final key = entry.key;
        final data = entry.value;
        if (key is! String) continue;
        if (data is Map) {
          perms[key] = PermissionSet.fromJson(data.cast<dynamic, dynamic>());
        }
      }
    }

    return UserProfile(
      uid: uid,
      name: (json['name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      role: (json['role'] as String?) ?? 'staff',
      permissions: perms,
      updatedAt: (json['updatedAt'] as int?) ?? 0,
    );
  }
}
