import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'permissions.dart';
import 'user_profile.dart';
import 'firebase_config.dart';

class UserRepository {
  UserRepository({
    FirebaseAuth? auth,
    FirebaseDatabase? database,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _database = database ?? databaseInstance();

  final FirebaseAuth _auth;
  final FirebaseDatabase _database;

  final _currentController = StreamController<UserProfile?>.broadcast();
  Stream<UserProfile?> get currentUserStream => _currentController.stream;

  final _allController = StreamController<List<UserProfile>>.broadcast();
  Stream<List<UserProfile>> get allUsersStream => _allController.stream;

  StreamSubscription<DatabaseEvent>? _currentSub;
  StreamSubscription<DatabaseEvent>? _allSub;

  UserProfile? _current;
  UserProfile? get current => _current;
  String get currentEmail => _auth.currentUser?.email ?? '';
  String get currentRole {
    if (_current != null) return _current!.role;
    return currentEmail.toLowerCase() == superAdminEmail ? 'super_admin' : 'viewer';
  }

  Future<void> init() async {
    await ensureCurrentUserProfile();
    await _startCurrentListener();
  }

  Future<void> dispose() async {
    await _currentSub?.cancel();
    await _allSub?.cancel();
    await _currentController.close();
    await _allController.close();
  }

  DatabaseReference _usersRef() => _database.ref('users');

  static const superAdminEmail = 'admin@admin.admin';

  Future<void> ensureCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final ref = _usersRef().child(user.uid);
    final snapshot = await ref.get();
    if (snapshot.exists) {
      final email = (user.email ?? '').toLowerCase();
      if (email == superAdminEmail) {
        await ref.update({
          'role': 'super_admin',
          'permissions': defaultPermissionsForRole('super_admin')
              .map((k, v) => MapEntry(k, v.toJson())),
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
      }
      return;
    }

    final email = user.email ?? '';
    final role = email.toLowerCase() == superAdminEmail
        ? 'super_admin'
        : 'viewer';
    final profile = UserProfile(
      uid: user.uid,
      name: user.displayName ?? '',
      email: email,
      role: role,
      permissions: defaultPermissionsForRole(role),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await ref.set(profile.toJson());
  }

  Future<void> updateCurrentProfile({
    required String name,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updateDisplayName(name);
    await _usersRef().child(user.uid).update({
      'name': name,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> updateUserRole(String uid, String role) async {
    final permissions = defaultPermissionsForRole(role);
    await _usersRef().child(uid).update({
      'role': role,
      'permissions': permissions.map((k, v) => MapEntry(k, v.toJson())),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> updateUserPermissions(
    String uid,
    Map<String, PermissionSet> permissions,
  ) async {
    await _usersRef().child(uid).update({
      'permissions': permissions.map((k, v) => MapEntry(k, v.toJson())),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _startCurrentListener() async {
    await _currentSub?.cancel();
    final user = _auth.currentUser;
    if (user == null) return;
    _currentSub = _usersRef().child(user.uid).onValue.listen((event) {
      final value = event.snapshot.value;
      if (value is Map) {
        final profile =
            UserProfile.fromJson(user.uid, value.cast<dynamic, dynamic>());
        if (profile.permissions.isEmpty) {
          final defaults = defaultPermissionsForRole(profile.role);
          _usersRef().child(user.uid).update({
            'permissions': defaults.map((k, v) => MapEntry(k, v.toJson())),
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          });
          _current = profile.copyWith(permissions: defaults);
        } else {
          _current = profile;
        }
        _currentController.add(_current);
      }
    });
  }

  Future<void> startAllUsersListener() async {
    await _allSub?.cancel();
    _allSub = _usersRef().onValue.listen((event) {
      final value = event.snapshot.value;
      if (value is! Map) {
        _allController.add(const []);
        return;
      }
      final users = <UserProfile>[];
      for (final entry in value.entries) {
        final key = entry.key;
        final data = entry.value;
        if (key is! String || data is! Map) continue;
        users.add(UserProfile.fromJson(key, data.cast<dynamic, dynamic>()));
      }
      _allController.add(users);
    });
  }
}
