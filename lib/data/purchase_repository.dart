import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';

import 'local_db.dart';
import 'purchase.dart';

class PurchaseRepository {
  PurchaseRepository({
    LocalDb? localDb,
    FirebaseAuth? auth,
    FirebaseDatabase? database,
    Connectivity? connectivity,
  })  : _localDb = localDb ?? LocalDb.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _database = database ?? FirebaseDatabase.instance,
        _connectivity = connectivity ?? Connectivity();

  final LocalDb _localDb;
  final FirebaseAuth _auth;
  final FirebaseDatabase _database;
  final Connectivity _connectivity;
  final _uuid = const Uuid();

  final _controller = StreamController<List<Purchase>>.broadcast();
  Stream<List<Purchase>> get stream => _controller.stream;

  List<Purchase> _purchases = const [];
  bool _online = false;
  bool get isOnline => _online;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<DatabaseEvent>? _remoteSub;

  Future<void> init() async {
    await _localDb.init();
    await _loadLocal();

    final initial = await _connectivity.checkConnectivity();
    await _handleConnectivity(initial);

    _connectivitySub = _connectivity.onConnectivityChanged.listen(
      (result) => _handleConnectivity(result),
    );
  }

  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    await _remoteSub?.cancel();
    await _controller.close();
  }

  Future<void> addPurchase({
    required String vendorName,
    required String reference,
    required double total,
    required String status,
    required String notes,
    required int purchasedAt,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final purchase = Purchase(
      id: _uuid.v4(),
      vendorName: vendorName,
      reference: reference,
      total: total,
      status: status,
      notes: notes,
      purchasedAt: purchasedAt,
      updatedAt: now,
      dirty: true,
    );
    await _localDb.upsertPurchase(purchase);
    await _loadLocal();

    if (_online) {
      await _pushPurchase(purchase);
    }
  }

  Future<void> updatePurchase(Purchase purchase) async {
    final updated = purchase.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      dirty: true,
    );
    await _localDb.upsertPurchase(updated);
    await _loadLocal();

    if (_online) {
      await _pushPurchase(updated);
    }
  }

  Future<void> _handleConnectivity(List<ConnectivityResult> result) async {
    final online = result.isNotEmpty &&
        !result.every((entry) => entry == ConnectivityResult.none);
    if (online == _online) return;
    _online = online;

    if (_online) {
      await _startRemoteSync();
      await _pushDirtyPurchases();
    } else {
      await _stopRemoteSync();
    }

    _controller.add(_purchases);
  }

  DatabaseReference _ref() {
    final uid = _auth.currentUser!.uid;
    return _database.ref('purchases/$uid');
  }

  Future<void> _startRemoteSync() async {
    await _remoteSub?.cancel();
    _remoteSub = _ref().onValue.listen((event) async {
      await _applyRemoteSnapshot(event.snapshot.value);
    });
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

      final remote = Purchase.fromJson(key, data.cast<dynamic, dynamic>());
      final local = await _localDb.getPurchaseById(remote.id);
      if (local == null || remote.updatedAt > local.updatedAt) {
        await _localDb.upsertPurchase(remote.copyWith(dirty: false));
        changed = true;
      }
    }

    if (changed) {
      await _loadLocal();
    }
  }

  Future<void> _pushDirtyPurchases() async {
    final dirtyPurchases = await _localDb.getDirtyPurchases();
    for (final purchase in dirtyPurchases) {
      await _pushPurchase(purchase);
    }
  }

  Future<void> _pushPurchase(Purchase purchase) async {
    await _ref().child(purchase.id).set(purchase.toJson());
    await _localDb.markPurchaseClean(purchase.id);
    await _loadLocal();
  }

  Future<void> _loadLocal() async {
    _purchases = await _localDb.getAllPurchases();
    _controller.add(_purchases);
  }
}
