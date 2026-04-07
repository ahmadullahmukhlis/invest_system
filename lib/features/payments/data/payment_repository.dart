import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../../core/data/local_db.dart';
import '../../../core/utils/id.dart';
import '../../../data/firebase_config.dart';
import '../../../data/user_repository.dart';
import '../domain/payment.dart';

class PaymentRepository {
  PaymentRepository({
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

  final _controller = StreamController<List<Payment>>.broadcast();
  Stream<List<Payment>> get stream => _controller.stream;

  List<Payment> _items = const [];
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

  Future<void> upsert(Payment payment) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final resolved = payment.id.isEmpty
        ? payment.copyWith(id: newId())
        : payment;
    final row = _toRow(
      resolved,
      ownerUid: _currentUid,
      updatedAt: now,
      dirty: true,
      deleted: 0,
    );
    await _localDb.upsert('payments', row);
    await _loadLocal();

    if (_online) {
      await _pushRow(row);
    }
  }

  Future<void> deleteById(String id) async {
    final existing =
        await _localDb.getById('payments', id, ownerUid: _currentUid);
    if (existing == null) return;
    final updated = Map<String, Object?>.from(existing);
    updated['deleted'] = 1;
    updated['dirty'] = 1;
    updated['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    await _localDb.upsert('payments', updated);
    await _loadLocal();

    if (_online) {
      await _pushRow(updated);
    }
  }

  String get _currentUid => _auth.currentUser?.uid ?? '';

  bool get _isGlobal =>
      _userRepository.currentRole == 'admin' ||
      _userRepository.currentRole == 'super_admin';

  DatabaseReference _ref() {
    return _isGlobal
        ? _database.ref('payments')
        : _database.ref('payments/$_currentUid');
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
      'payments',
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
            'payments',
            remote.id,
            ownerUid: ownerUid,
          );
          final localUpdated = (local?['updated_at'] as int?) ?? 0;
          if (remote.deleted == 1) {
            if (local != null) {
              await _localDb.delete('payments', remote.id);
              changed = true;
            }
            continue;
          }
          if (local == null || remote.updatedAt > localUpdated) {
            await _localDb.upsert(
              'payments',
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
          'payments',
          remote.id,
          ownerUid: _currentUid,
        );
        final localUpdated = (local?['updated_at'] as int?) ?? 0;
        if (remote.deleted == 1) {
          if (local != null) {
            await _localDb.delete('payments', remote.id);
            changed = true;
          }
          continue;
        }
        if (local == null || remote.updatedAt > localUpdated) {
          await _localDb.upsert(
            'payments',
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
      'payments',
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
      await _database.ref('payments/$ownerUid/$id').set(payload);
    } else {
      await _ref().child(id).set(payload);
    }

    if (isDeleted) {
      await _localDb.delete('payments', id);
    } else {
      await _localDb.markClean('payments', id);
    }
  }

  Payment _fromRow(Map<String, Object?> row) {
    return Payment(
      id: row['id'] as String,
      customerId: row['customer_id'] as String,
      saleId: row['sale_id'] as String?,
      date: DateTime.fromMillisecondsSinceEpoch(row['date'] as int),
      amount: (row['amount'] as num).toDouble(),
      note: row['note'] as String?,
    );
  }

  Map<String, Object?> _toRow(
    Payment payment, {
    required String ownerUid,
    required int updatedAt,
    required bool dirty,
    required int deleted,
  }) {
    return {
      'id': payment.id,
      'owner_uid': ownerUid,
      'customer_id': payment.customerId,
      'sale_id': payment.saleId,
      'date': payment.date.millisecondsSinceEpoch,
      'amount': payment.amount,
      'note': payment.note,
      'deleted': deleted,
      'updated_at': updatedAt,
      'dirty': dirty ? 1 : 0,
    };
  }

  _RemoteRecord<Payment> _fromJson(
    String id,
    String ownerUid,
    Map<dynamic, dynamic> json,
  ) {
    return _RemoteRecord(
      id: id,
      ownerUid: ownerUid,
      updatedAt: (json['updated_at'] as int?) ?? 0,
      deleted: (json['deleted'] as int?) ?? 0,
      data: Payment(
        id: id,
        customerId: (json['customer_id'] as String?) ?? '',
        saleId: json['sale_id'] as String?,
        date: DateTime.fromMillisecondsSinceEpoch(
          (json['date'] as int?) ?? 0,
        ),
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        note: json['note'] as String?,
      ),
    );
  }

  Map<String, Object?> _toJson(Map<String, Object?> row) {
    return {
      'customer_id': row['customer_id'],
      'sale_id': row['sale_id'],
      'date': row['date'],
      'amount': row['amount'],
      'note': row['note'],
      'updated_at': row['updated_at'],
      'deleted': row['deleted'],
    };
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
