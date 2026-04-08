import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../../core/data/local_db.dart';
import '../../../core/utils/id.dart';
import '../../../core/utils/network_utils.dart';
import '../../../data/firebase_config.dart';
import '../../../data/user_repository.dart';
import '../domain/customer.dart';

class CustomerRepository {
  CustomerRepository({
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

  final _controller = StreamController<List<Customer>>.broadcast();
  Stream<List<Customer>> get stream => _controller.stream;

  List<Customer> _items = const [];
  bool _online = false;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<DatabaseEvent>? _remoteSub;
  StreamSubscription? _profileSub;

  Future<void> init() async {
    await _localDb.init();
    await _loadLocal();

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

  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    await _remoteSub?.cancel();
    await _profileSub?.cancel();
    await _controller.close();
  }

  Future<void> upsert(Customer customer) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final resolved = customer.id.isEmpty
        ? customer.copyWith(id: newId())
        : customer;
    if (resolved.id.isNotEmpty) {
      final existing = await _localDb.getById('customers', resolved.id);
      if (existing != null &&
          (existing['owner_uid'] as String? ?? '') != _currentUid) {
        return;
      }
    }
    final row = _toRow(
      resolved,
      ownerUid: _currentUid,
      updatedAt: now,
      dirty: true,
      deleted: 0,
    );
    await _localDb.upsert('customers', row);
    await _loadLocal();

    if (_online) {
      await _pushRow(row);
    }
  }

  Future<void> deleteById(String id) async {
    final existing = await _localDb.getById(
      'customers',
      id,
    );
    if (existing == null) return;
    if ((existing['owner_uid'] as String? ?? '') != _currentUid) {
      return;
    }
    final updated = Map<String, Object?>.from(existing);
    updated['deleted'] = 1;
    updated['dirty'] = 1;
    updated['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    await _localDb.upsert('customers', updated);
    await _loadLocal();

    if (_online) {
      await _pushRow(updated);
    }
  }

  Future<bool> canEdit(String id) async {
    final existing = await _localDb.getById('customers', id);
    if (existing == null) return false;
    return (existing['owner_uid'] as String? ?? '') == _currentUid;
  }

  String get _currentUid => _auth.currentUser?.uid ?? '';

  bool get _isGlobal =>
      _userRepository.currentRole == 'admin' ||
      _userRepository.currentRole == 'super_admin';

  DatabaseReference _ref() {
    return _isGlobal
        ? _database.ref('customers')
        : _database.ref('customers/$_currentUid');
  }

  Future<void> _handleConnectivity(
    List<ConnectivityResult> result, {
    bool force = false,
  }) async {
    final online = await hasInternetConnection(result);
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
      'customers',
      ownerUid: _currentUid,
      all: _isGlobal,
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

    if (_isGlobal) {
      for (final userEntry in value.entries) {
        final ownerUid = userEntry.key;
        final userData = userEntry.value;
        if (ownerUid is! String || userData is! Map) continue;
        for (final entry in userData.entries) {
          final key = entry.key;
          final data = entry.value;
          if (key is! String || data is! Map) continue;
          final remote = _fromJson(key, ownerUid, data.cast<dynamic, dynamic>());
          final local = await _localDb.getById(
            'customers',
            remote.id,
            ownerUid: ownerUid,
          );
          final localUpdated = (local?['updated_at'] as int?) ?? 0;
          if (remote.deleted == 1) {
            if (local != null) {
              await _localDb.delete('customers', remote.id);
              changed = true;
            }
            continue;
          }
          if (local == null || remote.updatedAt > localUpdated) {
            await _localDb.upsert(
              'customers',
              _toRow(
                remote.data,
                ownerUid: ownerUid,
                updatedAt: remote.updatedAt,
                dirty: false,
                deleted: 0,
              ),
            );
            changed = true;
          }
        }
      }
    } else {
      for (final entry in value.entries) {
        final key = entry.key;
        final data = entry.value;
        if (key is! String || data is! Map) continue;
        final remote = _fromJson(
          key,
          _currentUid,
          data.cast<dynamic, dynamic>(),
        );
        final local = await _localDb.getById(
          'customers',
          remote.id,
          ownerUid: _currentUid,
        );
        final localUpdated = (local?['updated_at'] as int?) ?? 0;
        if (remote.deleted == 1) {
          if (local != null) {
            await _localDb.delete('customers', remote.id);
            changed = true;
          }
          continue;
        }
        if (local == null || remote.updatedAt > localUpdated) {
          await _localDb.upsert(
            'customers',
            _toRow(
              remote.data,
              ownerUid: _currentUid,
              updatedAt: remote.updatedAt,
              dirty: false,
              deleted: 0,
            ),
          );
          changed = true;
        }
      }
    }

    if (changed) {
      await _loadLocal();
    }
  }

  Future<void> _pushDirty() async {
    final rows = await _localDb.getDirty(
      'customers',
      ownerUid: _currentUid,
      all: _isGlobal,
    );
    for (final row in rows) {
      await _pushRow(row);
    }
  }

  Future<void> _pushRow(Map<String, Object?> row) async {
    final ownerUid = row['owner_uid'] as String? ?? '';
    final id = row['id'] as String? ?? '';
    if (id.isEmpty) return;
    final isDeleted = (row['deleted'] as int? ?? 0) == 1;
    final payload = _toJson(row);

    if (_isGlobal) {
      await _database.ref('customers/$ownerUid/$id').set(payload);
    } else {
      await _ref().child(id).set(payload);
    }

    if (isDeleted) {
      await _localDb.delete('customers', id);
    } else {
      await _localDb.markClean('customers', id);
    }
  }

  Customer _fromRow(Map<String, Object?> row) {
    return Customer(
      id: row['id'] as String,
      name: row['name'] as String,
      phone: row['phone'] as String,
      province: row['province'] as String,
      district: row['district'] as String,
      address: row['address'] as String?,
    );
  }

  Map<String, Object?> _toRow(
    Customer customer, {
    required String ownerUid,
    required int updatedAt,
    required bool dirty,
    required int deleted,
  }) {
    return {
      'id': customer.id,
      'owner_uid': ownerUid,
      'name': customer.name,
      'phone': customer.phone,
      'email': '',
      'company': '',
      'notes': '',
      'province': customer.province,
      'district': customer.district,
      'address': customer.address ?? '',
      'deleted': deleted,
      'updated_at': updatedAt,
      'dirty': dirty ? 1 : 0,
    };
  }

  _RemoteRecord<Customer> _fromJson(
    String id,
    String ownerUid,
    Map<dynamic, dynamic> json,
  ) {
    return _RemoteRecord(
      id: id,
      ownerUid: ownerUid,
      updatedAt: (json['updated_at'] as int?) ?? 0,
      deleted: (json['deleted'] as int?) ?? 0,
      data: Customer(
        id: id,
        name: (json['name'] as String?) ?? '',
        phone: (json['phone'] as String?) ?? '',
        province: (json['province'] as String?) ?? '',
        district: (json['district'] as String?) ?? '',
        address: json['address'] as String?,
      ),
    );
  }

  Map<String, Object?> _toJson(Map<String, Object?> row) {
    return {
      'name': row['name'],
      'phone': row['phone'],
      'province': row['province'],
      'district': row['district'],
      'address': row['address'],
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
