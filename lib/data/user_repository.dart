import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';

import '../core/data/realtime_sync_client.dart';
import '../core/utils/network_utils.dart';
import 'permissions.dart';
import 'user_profile.dart';
import 'firebase_config.dart';

class UserRepository {
  UserRepository({
    FirebaseAuth? auth,
    FirebaseDatabase? database,
    this.cloudEnabled = true,
    UserProfile? localProfile,
  })  : _auth = cloudEnabled ? (auth ?? FirebaseAuth.instance) : null,
        _database = cloudEnabled ? (database ?? databaseInstanceOrNull()) : null,
        _localProfiles = [
          localProfile ?? _defaultLocalProfile(),
        ];

  final FirebaseAuth? _auth;
  final FirebaseDatabase? _database;
  final bool cloudEnabled;
  final List<UserProfile> _localProfiles;
  final RealtimeSyncClient _restSync = RealtimeSyncClient.instance;

  final _currentController = StreamController<UserProfile?>.broadcast();
  Stream<UserProfile?> get currentUserStream => _currentController.stream;

  final _allController = StreamController<List<UserProfile>>.broadcast();
  Stream<List<UserProfile>> get allUsersStream => _allController.stream;

  StreamSubscription<DatabaseEvent>? _currentSub;
  StreamSubscription<DatabaseEvent>? _allSub;

  UserProfile? _current;
  UserProfile? get current => _current;
  String get currentUid => cloudEnabled
      ? (_auth?.currentUser?.uid ?? '')
      : (_current?.uid ?? _localProfiles.first.uid);
  String get currentEmail => cloudEnabled
      ? (_auth?.currentUser?.email ?? '')
      : (_current?.email ?? _localProfiles.first.email);
  String get currentRole {
    if (_current != null) return _current!.role;
    return currentEmail.toLowerCase() == superAdminEmail ? 'super_admin' : 'viewer';
  }
  bool get isCloudEnabled => cloudEnabled;
  bool get canSyncData => cloudEnabled;

  Future<void> init() async {
    if (!cloudEnabled) {
      _current = _localProfiles.first;
      _currentController.add(_current);
      _allController.add(List<UserProfile>.unmodifiable(_localProfiles));
      return;
    }
    await ensureCurrentUserProfile();
    await _startCurrentListener();
  }

  Future<void> dispose() async {
    await _currentSub?.cancel();
    await _allSub?.cancel();
    await _currentController.close();
    await _allController.close();
  }

  DatabaseReference _usersRef() => _database!.ref('users');

  static const superAdminEmail = 'admin@admin.com';
  static UserProfile _defaultLocalProfile() {
    final updatedAt = DateTime.now().millisecondsSinceEpoch;
    return UserProfile(
      uid: 'windows-local-admin',
      name: 'Windows Desktop',
      email: 'desktop@local',
      role: 'super_admin',
      permissions: defaultPermissionsForRole('super_admin'),
      updatedAt: updatedAt,
      isActive: true,
    );
  }

  Future<void> ensureCurrentUserProfile() async {
    if (!cloudEnabled) return;
    final user = _auth?.currentUser;
    if (user == null) return;
    final online = await hasInternet();
    if (!online) return;
    final existing = await _getUserJson(user.uid);
    if (existing == null && _database == null && !_restSync.isConfigured) {
      return;
    }
    if (existing != null) {
      final email = (user.email ?? '').toLowerCase();
      if (email == superAdminEmail) {
        await _updateUserJson(user.uid, {
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
      isActive: true,
    );
    await _setUserJson(user.uid, profile.toJson());
  }

  Future<void> updateCurrentProfile({
    required String name,
  }) async {
    if (!cloudEnabled) {
      _current = (_current ?? _localProfiles.first).copyWith(
        name: name,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      _localProfiles
        ..clear()
        ..add(_current!);
      _currentController.add(_current);
      _allController.add(List<UserProfile>.unmodifiable(_localProfiles));
      return;
    }
    final user = _auth?.currentUser;
    if (user == null) return;
    await user.updateDisplayName(name);
    await _updateUserJson(user.uid, {
      'name': name,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
    await _refreshCurrentProfile();
  }

  Future<void> updateUserRole(String uid, String role) async {
    if (!cloudEnabled) {
      _updateLocalUser(
        uid,
        (user) => user.copyWith(
          role: role,
          permissions: defaultPermissionsForRole(role),
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      return;
    }
    final permissions = defaultPermissionsForRole(role);
    await _updateUserJson(uid, {
      'role': role,
      'permissions': permissions.map((k, v) => MapEntry(k, v.toJson())),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
    await _refreshAllUsers();
    await _refreshCurrentProfile();
  }

  Future<void> updateUserPermissions(
    String uid,
    Map<String, PermissionSet> permissions,
  ) async {
    if (!cloudEnabled) {
      _updateLocalUser(
        uid,
        (user) => user.copyWith(
          permissions: permissions,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      return;
    }
    await _updateUserJson(uid, {
      'permissions': permissions.map((k, v) => MapEntry(k, v.toJson())),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
    await _refreshAllUsers();
    await _refreshCurrentProfile();
  }

  Future<void> updateUserActive(String uid, bool isActive) async {
    if (!cloudEnabled) {
      _updateLocalUser(
        uid,
        (user) => user.copyWith(
          isActive: isActive,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      return;
    }
    await _updateUserJson(uid, {
      'isActive': isActive,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
    await _refreshAllUsers();
    await _refreshCurrentProfile();
  }

  Future<void> createUser({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    if (!cloudEnabled) {
      final updatedAt = DateTime.now().millisecondsSinceEpoch;
      final profile = UserProfile(
        uid: 'local-${updatedAt}',
        name: name,
        email: email,
        role: role,
        permissions: defaultPermissionsForRole(role),
        updatedAt: updatedAt,
        isActive: true,
      );
      _localProfiles.add(profile);
      _allController.add(List<UserProfile>.unmodifiable(_localProfiles));
      return;
    }
    final primaryApp = Firebase.app();
    final adminApp = await Firebase.initializeApp(
      name: 'admin-${DateTime.now().millisecondsSinceEpoch}',
      options: primaryApp.options,
    );
    final adminAuth = FirebaseAuth.instanceFor(app: adminApp);
    try {
      final credential = await adminAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.updateDisplayName(name);
      final uid = credential.user?.uid;
      if (uid == null) return;
      final permissions = defaultPermissionsForRole(role);
      final profile = UserProfile(
        uid: uid,
        name: name,
        email: email,
        role: role,
        permissions: permissions,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        isActive: true,
      );
      await _setUserJson(uid, profile.toJson());
      await _refreshAllUsers();
    } finally {
      await adminAuth.signOut();
      await adminApp.delete();
    }
  }

  Future<void> _startCurrentListener() async {
    await _currentSub?.cancel();
    final user = _auth?.currentUser;
    if (user == null) return;
    if (_database == null) {
      await _refreshCurrentProfile();
      return;
    }
    _currentSub = _usersRef().child(user.uid).onValue.listen((event) {
      final value = event.snapshot.value;
      if (value is Map) {
        final profile =
            UserProfile.fromJson(user.uid, value.cast<dynamic, dynamic>());
        if (!profile.isActive) {
          _auth?.signOut();
          return;
        }
        final normalized =
            normalizePermissions(profile.role, profile.permissions);
        final needsUpdate = normalized.length != profile.permissions.length ||
            normalized.entries.any((entry) {
              final current = profile.permissions[entry.key];
              if (current == null) return true;
              return current.view != entry.value.view ||
                  current.create != entry.value.create ||
                  current.edit != entry.value.edit ||
                  current.remove != entry.value.remove;
            });
        if (needsUpdate) {
          _usersRef().child(user.uid).update({
            'permissions': normalized.map((k, v) => MapEntry(k, v.toJson())),
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          });
        }
        _current = profile.copyWith(permissions: normalized);
        _currentController.add(_current);
      }
    });
  }

  Future<void> startAllUsersListener() async {
    await _allSub?.cancel();
    if (!cloudEnabled) {
      _allController.add(List<UserProfile>.unmodifiable(_localProfiles));
      return;
    }
    if (_database == null) {
      await _refreshAllUsers();
      return;
    }
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
        final profile =
            UserProfile.fromJson(key, data.cast<dynamic, dynamic>());
        final normalized =
            normalizePermissions(profile.role, profile.permissions);
        users.add(profile.copyWith(permissions: normalized));
      }
      _allController.add(users);
    });
  }

  Future<void> signOut() async {
    if (!cloudEnabled) return;
    await _auth?.signOut();
  }

  void _updateLocalUser(
    String uid,
    UserProfile Function(UserProfile user) transform,
  ) {
    final index = _localProfiles.indexWhere((user) => user.uid == uid);
    if (index == -1) return;
    final updated = transform(_localProfiles[index]);
    _localProfiles[index] = updated;
    if (_current?.uid == uid) {
      _current = updated;
      _currentController.add(_current);
    }
    _allController.add(List<UserProfile>.unmodifiable(_localProfiles));
  }

  Future<Map<dynamic, dynamic>?> _getUserJson(String uid) async {
    if (_database != null) {
      try {
        final snapshot = await _usersRef()
            .child(uid)
            .get()
            .timeout(const Duration(seconds: 5));
        final value = snapshot.value;
        return value is Map ? value.cast<dynamic, dynamic>() : null;
      } catch (_) {
        return null;
      }
    }
    try {
      final value = await _restSync.getJson('users/$uid');
      return value is Map ? value.cast<dynamic, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<dynamic, dynamic>?> _getAllUsersJson() async {
    if (_database != null) {
      try {
        final snapshot = await _usersRef().get().timeout(const Duration(seconds: 5));
        final value = snapshot.value;
        return value is Map ? value.cast<dynamic, dynamic>() : null;
      } catch (_) {
        return null;
      }
    }
    try {
      final value = await _restSync.getJson('users');
      return value is Map ? value.cast<dynamic, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _setUserJson(String uid, Map<String, Object?> data) async {
    if (_database != null) {
      await _usersRef().child(uid).set(data);
      return;
    }
    await _restSync.setJson('users/$uid', data);
  }

  Future<void> _updateUserJson(String uid, Map<String, Object?> updates) async {
    if (_database != null) {
      await _usersRef().child(uid).update(updates);
      return;
    }
    final current = await _getUserJson(uid) ?? <dynamic, dynamic>{};
    final merged = <String, Object?>{};
    for (final entry in current.entries) {
      if (entry.key is String) {
        merged[entry.key as String] = entry.value;
      }
    }
    merged.addAll(updates);
    await _restSync.setJson('users/$uid', merged);
  }

  Future<void> _refreshCurrentProfile() async {
    final user = _auth?.currentUser;
    if (user == null) return;
    final value = await _getUserJson(user.uid);
    if (value == null) return;
    final profile = UserProfile.fromJson(user.uid, value);
    if (!profile.isActive) {
      await _auth?.signOut();
      return;
    }
    final normalized = normalizePermissions(profile.role, profile.permissions);
    final needsUpdate = normalized.length != profile.permissions.length ||
        normalized.entries.any((entry) {
          final current = profile.permissions[entry.key];
          if (current == null) return true;
          return current.view != entry.value.view ||
              current.create != entry.value.create ||
              current.edit != entry.value.edit ||
              current.remove != entry.value.remove;
        });
    if (needsUpdate) {
      await _updateUserJson(user.uid, {
        'permissions': normalized.map((k, v) => MapEntry(k, v.toJson())),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    }
    _current = profile.copyWith(permissions: normalized);
    _currentController.add(_current);
  }

  Future<void> _refreshAllUsers() async {
    final value = await _getAllUsersJson();
    if (value == null) {
      _allController.add(const []);
      return;
    }
    final users = <UserProfile>[];
    for (final entry in value.entries) {
      final key = entry.key;
      final data = entry.value;
      if (key is! String || data is! Map) continue;
      final profile = UserProfile.fromJson(key, data.cast<dynamic, dynamic>());
      final normalized = normalizePermissions(profile.role, profile.permissions);
      users.add(profile.copyWith(permissions: normalized));
    }
    _allController.add(users);
  }
}
