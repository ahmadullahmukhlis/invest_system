import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../core/data/local_db.dart';
import 'permissions.dart';
import 'user_profile.dart';

class UserRepository {
  UserRepository({LocalDb? localDb}) : _localDb = localDb ?? LocalDb.instance;

  final LocalDb _localDb;

  final _currentController = StreamController<UserProfile?>.broadcast();
  Stream<UserProfile?> get currentUserStream => _currentController.stream;

  final _allController = StreamController<List<UserProfile>>.broadcast();
  Stream<List<UserProfile>> get allUsersStream => _allController.stream;

  UserProfile? _current;
  UserProfile? get current => _current;

  String get currentEmail => _current?.email ?? '';
  String get currentRole => _current?.role ?? 'viewer';

  static const superAdminEmail = 'admin@admin.com';

  Future<void> init() async {
    await _localDb.init();
    await _restoreSession();
    await _emitAllUsers();
  }

  Future<void> dispose() async {
    await _currentController.close();
    await _allController.close();
  }

  Future<bool> hasUsers() async {
    final rows = await _db.query('app_users', columns: ['id'], limit: 1);
    return rows.isNotEmpty;
  }

  Future<void> registerUser({
    required String email,
    required String password,
    required String name,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final exists = await _findUserByEmail(normalizedEmail);
    if (exists != null) {
      throw StateError('An account with this email already exists.');
    }

    final hasExistingUsers = await hasUsers();
    final role = hasExistingUsers ? 'staff' : 'super_admin';
    final profile = UserProfile(
      uid: _newUserId(),
      name: name.trim(),
      email: normalizedEmail,
      role: role,
      permissions: normalizePermissions(role, defaultPermissionsForRole(role)),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      isActive: true,
    );

    await _upsertUser(profile, password: password);
    await _setCurrentUser(profile.uid);
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final row = await _findUserByEmail(normalizedEmail);
    if (row == null) {
      throw StateError('No account found for that email.');
    }

    if ((row['is_active'] as int? ?? 0) != 1) {
      throw StateError('This account is inactive.');
    }

    final expectedHash = row['password_hash'] as String? ?? '';
    final providedHash = _hashPassword(password);
    if (expectedHash != providedHash) {
      throw StateError('Incorrect password.');
    }

    await _setCurrentUser(row['id'] as String);
  }

  Future<void> signOut() async {
    await _db.insert(
      'app_session',
      {'id': 1, 'current_uid': null},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _current = null;
    _currentController.add(null);
  }

  Future<void> ensureCurrentUserProfile() async {}

  Future<void> updateCurrentProfile({
    required String name,
  }) async {
    final user = _current;
    if (user == null) return;
    final updated = user.copyWith(
      name: name.trim(),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _upsertUser(updated);
    _current = updated;
    _currentController.add(updated);
    await _emitAllUsers();
  }

  Future<void> updateUserRole(String uid, String role) async {
    final user = await _findUserById(uid);
    if (user == null) return;
    final profile = _profileFromRow(user);
    final updated = profile.copyWith(
      role: role,
      permissions: normalizePermissions(role, defaultPermissionsForRole(role)),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _upsertUser(updated);
    await _refreshIfCurrent(uid);
    await _emitAllUsers();
  }

  Future<void> updateUserPermissions(
    String uid,
    Map<String, PermissionSet> permissions,
  ) async {
    final user = await _findUserById(uid);
    if (user == null) return;
    final profile = _profileFromRow(user);
    final updated = profile.copyWith(
      permissions: normalizePermissions(profile.role, permissions),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _upsertUser(updated);
    await _refreshIfCurrent(uid);
    await _emitAllUsers();
  }

  Future<void> updateUserActive(String uid, bool isActive) async {
    final user = await _findUserById(uid);
    if (user == null) return;
    final profile = _profileFromRow(user);
    final updated = profile.copyWith(
      isActive: isActive,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _upsertUser(updated);
    if (!isActive && _current?.uid == uid) {
      await signOut();
    } else {
      await _refreshIfCurrent(uid);
    }
    await _emitAllUsers();
  }

  Future<void> createUser({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final exists = await _findUserByEmail(normalizedEmail);
    if (exists != null) {
      throw StateError('An account with this email already exists.');
    }
    final profile = UserProfile(
      uid: _newUserId(),
      name: name.trim(),
      email: normalizedEmail,
      role: role,
      permissions: normalizePermissions(role, defaultPermissionsForRole(role)),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      isActive: true,
    );
    await _upsertUser(profile, password: password);
    await _emitAllUsers();
  }

  Future<void> startAllUsersListener() async {
    await _emitAllUsers();
  }

  Future<void> _restoreSession() async {
    final rows = await _db.query(
      'app_session',
      columns: ['current_uid'],
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (rows.isEmpty) {
      _current = null;
      _currentController.add(null);
      return;
    }

    final currentUid = rows.first['current_uid'] as String?;
    if (currentUid == null || currentUid.isEmpty) {
      _current = null;
      _currentController.add(null);
      return;
    }

    final row = await _findUserById(currentUid);
    if (row == null || (row['is_active'] as int? ?? 0) != 1) {
      _current = null;
      _currentController.add(null);
      return;
    }

    _current = _profileFromRow(row);
    _currentController.add(_current);
  }

  Future<void> _setCurrentUser(String uid) async {
    await _db.insert(
      'app_session',
      {'id': 1, 'current_uid': uid},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    final row = await _findUserById(uid);
    _current = row == null ? null : _profileFromRow(row);
    _currentController.add(_current);
    await _emitAllUsers();
  }

  Future<void> _refreshIfCurrent(String uid) async {
    if (_current?.uid != uid) return;
    final row = await _findUserById(uid);
    _current = row == null ? null : _profileFromRow(row);
    _currentController.add(_current);
  }

  Future<void> _upsertUser(UserProfile profile, {String? password}) async {
    final existing = await _findUserById(profile.uid);
    final passwordHash = password != null
        ? _hashPassword(password)
        : (existing?['password_hash'] as String? ?? '');
    await _db.insert(
      'app_users',
      {
        'id': profile.uid,
        'name': profile.name,
        'email': profile.email,
        'password_hash': passwordHash,
        'role': profile.role,
        'permissions_json': jsonEncode(
          profile.permissions.map((k, v) => MapEntry(k, v.toJson())),
        ),
        'updated_at': profile.updatedAt,
        'is_active': profile.isActive ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, Object?>?> _findUserByEmail(String email) async {
    final rows = await _db.query(
      'app_users',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>?> _findUserById(String uid) async {
    final rows = await _db.query(
      'app_users',
      where: 'id = ?',
      whereArgs: [uid],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> _emitAllUsers() async {
    final rows = await _db.query('app_users', orderBy: 'updated_at DESC');
    _allController.add(rows.map(_profileFromRow).toList());
  }

  UserProfile _profileFromRow(Map<String, Object?> row) {
    final rawPermissions = row['permissions_json'] as String? ?? '{}';
    final decoded = jsonDecode(rawPermissions);
    final permissions = <String, PermissionSet>{};
    if (decoded is Map) {
      for (final rawEntry in decoded.entries) {
        final entry = MapEntry(rawEntry.key.toString(), rawEntry.value);
        final value = entry.value;
        permissions[entry.key] = value is Map
            ? PermissionSet.fromJson(value.cast<dynamic, dynamic>())
            : PermissionSet(
                view: false,
                create: false,
                edit: false,
                remove: false,
              );
      }
    }

    return UserProfile(
      uid: row['id'] as String? ?? '',
      name: row['name'] as String? ?? '',
      email: row['email'] as String? ?? '',
      role: row['role'] as String? ?? 'viewer',
      permissions: normalizePermissions(
        row['role'] as String? ?? 'viewer',
        permissions,
      ),
      updatedAt: row['updated_at'] as int? ?? 0,
      isActive: (row['is_active'] as int? ?? 0) == 1,
    );
  }

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  String _newUserId() => DateTime.now().microsecondsSinceEpoch.toString();

  Database get _db => _localDb.database;
}
