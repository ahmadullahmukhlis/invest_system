import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';

import 'local_db.dart';
import 'product.dart';
import '../core/utils/network_utils.dart';
import 'user_repository.dart';

class ProductRepository {
  ProductRepository({
    LocalDb? localDb,
    FirebaseAuth? auth,
    FirebaseDatabase? database,
    Connectivity? connectivity,
    required UserRepository userRepository,
  })  : _localDb = localDb ?? LocalDb.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _database = database ?? FirebaseDatabase.instance,
        _connectivity = connectivity ?? Connectivity(),
        _userRepository = userRepository;

  final LocalDb _localDb;
  final FirebaseAuth _auth;
  final FirebaseDatabase _database;
  final Connectivity _connectivity;
  final UserRepository _userRepository;
  final _uuid = const Uuid();

  final _controller = StreamController<List<Product>>.broadcast();
  Stream<List<Product>> get stream => _controller.stream;

  List<Product> _products = const [];
  bool _online = false;
  bool get isOnline => _online;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<DatabaseEvent>? _remoteSub;
  StreamSubscription? _profileSub;

  Future<void> init() async {
    await _localDb.init();
    await _loadLocal();

    final initial = await _connectivity.checkConnectivity();
    await _handleConnectivity(initial);

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

  Future<void> addProduct({
    required String name,
    required String sku,
    required String category,
    required String unit,
    required double price,
    required double cost,
    required double stock,
    required String notes,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final product = Product(
      id: _uuid.v4(),
      ownerUid: _currentUid,
      name: name,
      sku: sku,
      category: category,
      unit: unit,
      price: price,
      cost: cost,
      stock: stock,
      notes: notes,
      updatedAt: now,
      dirty: true,
    );
    await _localDb.upsertProduct(product);
    await _loadLocal();

    if (_online) {
      await _pushProduct(product);
    }
  }

  Future<void> updateProduct(Product product) async {
    final updated = product.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      dirty: true,
    );
    await _localDb.upsertProduct(updated);
    await _loadLocal();

    if (_online) {
      await _pushProduct(updated);
    }
  }

  Future<void> _handleConnectivity(List<ConnectivityResult> result) async {
    final online = await hasInternetConnection(result);
    if (online == _online) return;
    _online = online;

    if (_online) {
      await _startRemoteSync();
      await _pushDirtyProducts();
    } else {
      await _stopRemoteSync();
    }

    _controller.add(_products);
  }

  String get _currentUid => _auth.currentUser?.uid ?? '';

  bool get _isGlobal =>
      _userRepository.currentRole == 'admin' ||
      _userRepository.currentRole == 'super_admin';

  DatabaseReference _ref() {
    return _isGlobal
        ? _database.ref('products')
        : _database.ref('products/$_currentUid');
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

    if (_isGlobal) {
      for (final userEntry in value.entries) {
        final ownerUid = userEntry.key;
        final userData = userEntry.value;
        if (ownerUid is! String || userData is! Map) continue;
        for (final entry in userData.entries) {
          final key = entry.key;
          final data = entry.value;
          if (key is! String || data is! Map) continue;
          final remote = Product.fromJson(
            key,
            ownerUid,
            data.cast<dynamic, dynamic>(),
          );
          final local =
              await _localDb.getProductById(remote.id, ownerUid: ownerUid);
          if (local == null || remote.updatedAt > local.updatedAt) {
            await _localDb.upsertProduct(remote.copyWith(dirty: false));
            changed = true;
          }
        }
      }
    } else {
      for (final entry in value.entries) {
        final key = entry.key;
        final data = entry.value;
        if (key is! String || data is! Map) continue;

        final remote = Product.fromJson(
          key,
          _currentUid,
          data.cast<dynamic, dynamic>(),
        );
        final local =
            await _localDb.getProductById(remote.id, ownerUid: _currentUid);
        if (local == null || remote.updatedAt > local.updatedAt) {
          await _localDb.upsertProduct(remote.copyWith(dirty: false));
          changed = true;
        }
      }
    }

    if (changed) {
      await _loadLocal();
    }
  }

  Future<void> _pushDirtyProducts() async {
    final dirtyProducts = await _localDb.getDirtyProducts(
      ownerUid: _currentUid,
      all: _isGlobal,
    );
    for (final product in dirtyProducts) {
      await _pushProduct(product);
    }
  }

  Future<void> _pushProduct(Product product) async {
    final ownerUid = product.ownerUid.isEmpty ? _currentUid : product.ownerUid;
    await _database.ref('products/$ownerUid').child(product.id).set(
          product.toJson(),
        );
    await _localDb.markProductClean(product.id);
    await _loadLocal();
  }

  Future<void> _loadLocal() async {
    if (!_isGlobal && _currentUid.isNotEmpty) {
      await _localDb.claimUnownedProducts(_currentUid);
    }
    _products = await _localDb.getAllProducts(
      ownerUid: _currentUid,
      all: _isGlobal,
    );
    _controller.add(_products);
  }
}
