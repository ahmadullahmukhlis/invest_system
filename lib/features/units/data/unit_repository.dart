import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../../core/data/local_db.dart';
import '../../../core/utils/id.dart';
import '../../../data/firebase_config.dart';
import '../../../data/user_repository.dart';
import '../domain/unit.dart';

class UnitRepository {
  UnitRepository({
    LocalDb? localDb,
    FirebaseAuth? auth,
    FirebaseDatabase? database,
    Connectivity? connectivity,
    required UserRepository userRepository,
  })  : _localDb = localDb ?? LocalDb.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _database = database ?? databaseInstance(),
        _connectivity = connectivity ?? Connectivity(),
        _userRepository = userRepository;

  final LocalDb _localDb;
  final FirebaseAuth _auth;
  final FirebaseDatabase _database;
  final Connectivity _connectivity;
  final UserRepository _userRepository;

  final _controller = StreamController<List<Unit>>.broadcast();
  Stream<List<Unit>> get stream => _controller.stream;

  List<Unit> _items = const [];
  bool _online = false;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<DatabaseEvent>? _remoteSub;
  StreamSubscription? _profileSub;

  Future<void> init() async {
    await _localDb.init();
    await _loadLocal();
    if (_items.isEmpty) {
      await _seedDefaults();
    }

    final initial = await _connectivity.checkConnectivity();
    await _handleConnectivity(initial, force: true);

    _connectivitySub = _connectivity.onConnectivityChanged.listen(
      (result) => _handleConnectivity(result),
    );
    _profileSub = _userRepository.currentUserStream.listen((_) async {
      await _stopRemoteSync();
      await _loadLocal();
      final current = await _connectivity.checkConnectivity();
      await _handleConnectivity(current);
    });
  }

  Future<void> _seedDefaults() async {
    final defaults = const ['kg', 'ton', 'bag'];
    for (final name in defaults) {
      await upsert(Unit(id: '', name: name, isActive: true));
    }
  }

  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    await _remoteSub?.cancel();
    await _profileSub?.cancel();
    await _controller.close();
  }

  Future<void> upsert(Unit unit) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final resolved = unit.id.isEmpty ? unit.copyWith(id: newId()) : unit;
    final row = _toRow(
      resolved,
      ownerUid: '',
      updatedAt: now,
      dirty: true,
      deleted: 0,
    );
    await _localDb.upsert('units', row);
    await _loadLocal();

    if (_online) {
      await _pushRow(row);
    }
  }

  Future<void> toggleActive(String id) async {
    final existing = await _localDb.getById('units', id);
    if (existing == null) return;
    final updated = Map<String, Object?>.from(existing);
    final currentActive = (existing['is_active'] as int? ?? 1) == 1;
    updated['is_active'] = currentActive ? 0 : 1;
    updated['dirty'] = 1;
    updated['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    await _localDb.upsert('units', updated);
    await _loadLocal();
    if (_online) {
      await _pushRow(updated);
    }
  }

  Future<void> deleteById(String id) async {
    final existing = await _localDb.getById('units', id);
    if (existing == null) return;
    final updated = Map<String, Object?>.from(existing);
    updated['deleted'] = 1;
    updated['dirty'] = 1;
    updated['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    await _localDb.upsert('units', updated);
    await _loadLocal();
    if (_online) {
      await _pushRow(updated);
    }
  }

  String get _currentUid => _auth.currentUser?.uid ?? '';

  DatabaseReference _ref() {
    return _database.ref('units');
  }

  Future<void> _handleConnectivity(
    List<ConnectivityResult> result, {
    bool force = false,
  }) async {
    final online = result.isNotEmpty &&
        !result.every((entry) => entry == ConnectivityResult.none);
    if (!force && online == _online) return;
    _online = online;

    if (_online) {
      await _startRemoteSync();
      await _pushDirty();
    } else {
      await _stopRemoteSync();
    }

    _controller.add(_items);
  }

  Future<void> _loadLocal() async {
    final rows = await _localDb.getAll(
      'units',
      all: true,
    );
    _items = rows.map(_fromRow).toList();
    _controller.add(_items);
  }

  Future<void> _startRemoteSync() async {
    await _remoteSub?.cancel();
    _remoteSub = _ref().onValue.listen((event) async {
      await _applyRemoteSnapshot(event.snapshot.value);
    });
    final snapshot = await _ref().get();
    await _applyRemoteSnapshot(snapshot.value);
  }

  Future<void> _stopRemoteSync() async {
    await _remoteSub?.cancel();
    _remoteSub = null;
  }

  Future<void> _applyRemoteSnapshot(Object? value) async {
    if (value is! Map) return;
    var changed = false;

    for (final entry in value.entries) {
      final key = entry.key;
      final data = entry.value;
      if (key is! String || data is! Map) continue;
      final remote = _fromJson(
        key,
        '',
        data.cast<dynamic, dynamic>(),
      );
      final local = await _localDb.getById(
        'units',
        remote.id,
      );
      final localUpdated = (local?['updated_at'] as int?) ?? 0;
      if (remote.deleted == 1) {
        if (local != null) {
          await _localDb.delete('units', remote.id);
          changed = true;
        }
        continue;
      }
      if (local == null || remote.updatedAt > localUpdated) {
        await _localDb.upsert(
          'units',
          _toRow(
            remote.data,
            ownerUid: '',
            updatedAt: remote.updatedAt,
            dirty: false,
            deleted: 0,
          ),
        );
        changed = true;
      }
    }

    if (changed) {
      await _loadLocal();
    }
  }

  Future<void> _pushDirty() async {
    final rows = await _localDb.getDirty(
      'units',
      all: true,
    );
    for (final row in rows) {
      await _pushRow(row);
    }
  }

  Future<void> _pushRow(Map<String, Object?> row) async {
    final id = row['id'] as String? ?? '';
    if (id.isEmpty) return;
    final isDeleted = (row['deleted'] as int? ?? 0) == 1;
    final payload = _toJson(row);

    await _ref().child(id).set(payload);

    if (isDeleted) {
      await _localDb.delete('units', id);
    } else {
      await _localDb.markClean('units', id);
    }
  }

  Unit _fromRow(Map<String, Object?> row) {
    return Unit(
      id: row['id'] as String,
      name: row['name'] as String,
      isActive: (row['is_active'] as int? ?? 1) == 1,
    );
  }

  Map<String, Object?> _toRow(
    Unit unit, {
    required String ownerUid,
    required int updatedAt,
    required bool dirty,
    required int deleted,
  }) {
    return {
      'id': unit.id,
      'owner_uid': ownerUid,
      'name': unit.name,
      'is_active': unit.isActive ? 1 : 0,
      'deleted': deleted,
      'updated_at': updatedAt,
      'dirty': dirty ? 1 : 0,
    };
  }

  _RemoteRecord<Unit> _fromJson(
    String id,
    String ownerUid,
    Map<dynamic, dynamic> json,
  ) {
    return _RemoteRecord(
      id: id,
      ownerUid: ownerUid,
      updatedAt: (json['updated_at'] as int?) ?? 0,
      deleted: (json['deleted'] as int?) ?? 0,
      data: Unit(
        id: id,
        name: (json['name'] as String?) ?? '',
        isActive: (json['is_active'] as int? ?? 1) == 1,
      ),
    );
  }

  Map<String, Object?> _toJson(Map<String, Object?> row) {
    return {
      'name': row['name'],
      'is_active': row['is_active'],
      'updated_at': row['updated_at'],
      'deleted': row['deleted'],
    };
  }

  Future<void> syncNow() async {
    final current = await _connectivity.checkConnectivity();
    await _handleConnectivity(current, force: true);
  }

  Future<void> pullRemoteNow() async {
    if (_online) {
      await _startRemoteSync();
    } else {
      final current = await _connectivity.checkConnectivity();
      await _handleConnectivity(current, force: true);
    }
  }

  Future<void> pushLocalNow() async {
    if (_online) {
      await _pushDirty();
    } else {
      final current = await _connectivity.checkConnectivity();
      await _handleConnectivity(current, force: true);
    }
  }
}

class _RemoteRecord<T> {
  const _RemoteRecord({
    required this.id,
    required this.ownerUid,
    required this.updatedAt,
    required this.deleted,
    required this.data,
  });

  final String id;
  final String ownerUid;
  final int updatedAt;
  final int deleted;
  final T data;
}
