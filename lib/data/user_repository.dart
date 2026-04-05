import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'user_profile.dart';

class UserRepository {
  UserRepository({
    FirebaseAuth? auth,
    FirebaseDatabase? database,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _database = database ?? FirebaseDatabase.instance;

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

  Future<void> ensureCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final ref = _usersRef().child(user.uid);
    final snapshot = await ref.get();
    if (snapshot.exists) return;

    final profile = UserProfile(
      uid: user.uid,
      name: user.displayName ?? '',
      email: user.email ?? '',
      role: 'staff',
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
    await _usersRef().child(uid).update({
      'role': role,
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
        _current = UserProfile.fromJson(user.uid, value.cast<dynamic, dynamic>());
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
