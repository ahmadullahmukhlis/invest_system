import 'dart:async';

import 'permissions.dart';
import 'user_profile.dart';

class UserRepository {
  UserRepository();

  static const String localUserId = 'local-device';

  final _currentController = StreamController<UserProfile?>.broadcast();
  Stream<UserProfile?> get currentUserStream => _currentController.stream;

  final _allController = StreamController<List<UserProfile>>.broadcast();
  Stream<List<UserProfile>> get allUsersStream => _allController.stream;

  late UserProfile _current = _defaultProfile();
  UserProfile? get current => _current;
  String get currentEmail => _current.email;
  String get currentRole => _current.role;

  Future<void> init() async {
    _emit();
  }

  Future<void> dispose() async {
    await _currentController.close();
    await _allController.close();
  }

  Future<void> startAllUsersListener() async {
    _emit();
  }

  Future<void> updateCurrentProfile({
    required String name,
  }) async {
    _current = _current.copyWith(
      name: name,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    _emit();
  }

  Future<void> updateUserRole(String uid, String role) async {
    if (uid != _current.uid) return;
    _current = _current.copyWith(
      role: role,
      permissions: normalizePermissions(role, _current.permissions),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    _emit();
  }

  Future<void> updateUserPermissions(
    String uid,
    Map<String, PermissionSet> permissions,
  ) async {
    if (uid != _current.uid) return;
    _current = _current.copyWith(
      permissions: permissions,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    _emit();
  }

  Future<void> updateUserActive(String uid, bool isActive) async {
    if (uid != _current.uid) return;
    _current = _current.copyWith(
      isActive: isActive,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    _emit();
  }

  Future<void> createUser({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    throw UnsupportedError(
      'Offline mode supports a single local Windows user profile only.',
    );
  }

  void _emit() {
    _currentController.add(_current);
    _allController.add([_current]);
  }

  UserProfile _defaultProfile() {
    const role = 'super_admin';
    return UserProfile(
      uid: localUserId,
      name: 'Local Administrator',
      email: 'offline@local',
      role: role,
      permissions: defaultPermissionsForRole(role),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      isActive: true,
    );
  }
}
