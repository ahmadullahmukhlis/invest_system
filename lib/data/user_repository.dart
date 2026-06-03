import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../core/data/database_path_stub.dart'
    if (dart.library.io) '../core/data/database_path_io.dart';
import 'permissions.dart';
import 'user_profile.dart';

class UserRepository {
  UserRepository({bool cloudEnabled = false, UserProfile? localProfile})
    : _seedProfile = localProfile;

  final UserProfile? _seedProfile;
  Database? _db;

  final _currentController = StreamController<UserProfile?>.broadcast();
  Stream<UserProfile?> get currentUserStream => _currentController.stream;

  final _allController = StreamController<List<UserProfile>>.broadcast();
  Stream<List<UserProfile>> get allUsersStream => _allController.stream;

  UserProfile? _current;
  UserProfile? get current => _current;
  String get currentUid => _current?.uid ?? '';
  String get currentEmail => _current?.email ?? '';
  String get currentRole => _current?.role ?? 'viewer';
  bool get isCloudEnabled => false;
  bool get canSyncData => false;

  static const superAdminEmail = 'admin@admin.com';
  static const initialAdminPassword = 'admin';

  Future<void> init() async {
    final path = await localDatabasePath('invest_system_users.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await _createTables(db);
      },
    );
    await _createTables(_db!);
    await _seedInitialAdmin();
    await _emitAllUsers();
    _currentController.add(_current);
  }

  Future<void> dispose() async {
    await _currentController.close();
    await _allController.close();
    await _db?.close();
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_users (
        uid TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        role TEXT NOT NULL,
        permissions TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        is_active INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _seedInitialAdmin() async {
    final countRows = await _db!.rawQuery(
      'SELECT COUNT(*) AS count FROM local_users',
    );
    final count = (countRows.first['count'] as int?) ?? 0;
    if (count > 0) return;

    final updatedAt = DateTime.now().millisecondsSinceEpoch;
    final profile =
        _seedProfile ??
        UserProfile(
          uid: 'local-admin',
          name: 'Local Admin',
          email: superAdminEmail,
          role: 'super_admin',
          permissions: defaultPermissionsForRole('super_admin'),
          updatedAt: updatedAt,
          isActive: true,
        );
    await _db!.insert('local_users', {
      ..._profileToRow(profile),
      'password': _encodePassword(initialAdminPassword),
    });
  }

  Future<bool> signIn({required String email, required String password}) async {
    final normalizedEmail = email.trim().toLowerCase();
    final rows = await _db!.query(
      'local_users',
      where: 'LOWER(email) = ? AND password = ? AND is_active = 1',
      whereArgs: [normalizedEmail, _encodePassword(password)],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    _current = _profileFromRow(rows.first);
    _currentController.add(_current);
    await _emitAllUsers();
    return true;
  }

  Future<void> signOut() async {
    _current = null;
    _currentController.add(null);
  }

  Future<void> ensureCurrentUserProfile() async {}

  Future<void> updateCurrentProfile({required String name}) async {
    final current = _current;
    if (current == null) return;
    await _updateUser(
      current.uid,
      current.copyWith(
        name: name,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> updateUserRole(String uid, String role) async {
    final existing = await _getUser(uid);
    if (existing == null) return;
    await _updateUser(
      uid,
      existing.copyWith(
        role: role,
        permissions: defaultPermissionsForRole(role),
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> updateUserPermissions(
    String uid,
    Map<String, PermissionSet> permissions,
  ) async {
    final existing = await _getUser(uid);
    if (existing == null) return;
    await _updateUser(
      uid,
      existing.copyWith(
        permissions: permissions,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> updateUserActive(String uid, bool isActive) async {
    final existing = await _getUser(uid);
    if (existing == null) return;
    await _updateUser(
      uid,
      existing.copyWith(
        isActive: isActive,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    if (_current?.uid == uid && !isActive) {
      await signOut();
    }
  }

  Future<void> createUser({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    final updatedAt = DateTime.now().millisecondsSinceEpoch;
    final profile = UserProfile(
      uid: 'local-$updatedAt',
      name: name,
      email: email.trim(),
      role: role,
      permissions: defaultPermissionsForRole(role),
      updatedAt: updatedAt,
      isActive: true,
    );
    await _db!.insert('local_users', {
      ..._profileToRow(profile),
      'password': _encodePassword(password),
    });
    await _emitAllUsers();
  }

  Future<void> startAllUsersListener() async {
    await _emitAllUsers();
  }

  Future<UserProfile?> _getUser(String uid) async {
    final rows = await _db!.query(
      'local_users',
      where: 'uid = ?',
      whereArgs: [uid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _profileFromRow(rows.first);
  }

  Future<void> _updateUser(String uid, UserProfile profile) async {
    await _db!.update(
      'local_users',
      _profileToRow(profile),
      where: 'uid = ?',
      whereArgs: [uid],
    );
    if (_current?.uid == uid) {
      _current = profile;
      _currentController.add(_current);
    }
    await _emitAllUsers();
  }

  Future<void> _emitAllUsers() async {
    final rows = await _db!.query('local_users', orderBy: 'updated_at DESC');
    _allController.add(rows.map(_profileFromRow).toList(growable: false));
  }

  Map<String, Object?> _profileToRow(UserProfile profile) {
    return {
      'uid': profile.uid,
      'name': profile.name,
      'email': profile.email,
      'role': profile.role,
      'permissions': jsonEncode(
        profile.permissions.map((key, value) => MapEntry(key, value.toJson())),
      ),
      'updated_at': profile.updatedAt,
      'is_active': profile.isActive ? 1 : 0,
    };
  }

  UserProfile _profileFromRow(Map<String, Object?> row) {
    final permissionsRaw = row['permissions'] as String? ?? '{}';
    final decoded = jsonDecode(permissionsRaw);
    final permissions = <String, PermissionSet>{};
    if (decoded is Map) {
      for (final entry in decoded.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is String && value is Map) {
          permissions[key] = PermissionSet.fromJson(value);
        }
      }
    }
    final role = row['role'] as String? ?? 'viewer';
    return UserProfile(
      uid: row['uid'] as String,
      name: row['name'] as String? ?? '',
      email: row['email'] as String? ?? '',
      role: role,
      permissions: normalizePermissions(role, permissions),
      updatedAt: row['updated_at'] as int? ?? 0,
      isActive: ((row['is_active'] as int?) ?? 1) == 1,
    );
  }

  String _encodePassword(String password) {
    return base64Url.encode(utf8.encode(password));
  }
}
