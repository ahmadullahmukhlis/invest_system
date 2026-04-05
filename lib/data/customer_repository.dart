import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';

import 'customer.dart';
import 'local_db.dart';

class CustomerRepository {
  CustomerRepository({
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

  final _controller = StreamController<List<Customer>>.broadcast();
  Stream<List<Customer>> get stream => _controller.stream;

  List<Customer> _customers = const [];
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

  Future<void> addCustomer({
    required String name,
    required String phone,
    required String email,
    required String address,
    required String company,
    required String notes,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final customer = Customer(
      id: _uuid.v4(),
      name: name,
      phone: phone,
      email: email,
      address: address,
      company: company,
      notes: notes,
      updatedAt: now,
      dirty: true,
    );
    await _localDb.upsertCustomer(customer);
    await _loadLocal();

    if (_online) {
      await _pushCustomer(customer);
    }
  }

  Future<void> updateCustomer(Customer customer) async {
    final updated = customer.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      dirty: true,
    );
    await _localDb.upsertCustomer(updated);
    await _loadLocal();

    if (_online) {
      await _pushCustomer(updated);
    }
  }

  Future<void> _handleConnectivity(List<ConnectivityResult> result) async {
    final online = result.isNotEmpty &&
        !result.every((entry) => entry == ConnectivityResult.none);
    if (online == _online) return;
    _online = online;

    if (_online) {
      await _startRemoteSync();
      await _pushDirtyCustomers();
    } else {
      await _stopRemoteSync();
    }

    _controller.add(_customers);
  }

  DatabaseReference _ref() {
    final uid = _auth.currentUser!.uid;
    return _database.ref('customers/$uid');
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

      final remote = Customer.fromJson(key, data.cast<dynamic, dynamic>());
      final local = await _localDb.getCustomerById(remote.id);
      if (local == null || remote.updatedAt > local.updatedAt) {
        await _localDb.upsertCustomer(remote.copyWith(dirty: false));
        changed = true;
      }
    }

    if (changed) {
      await _loadLocal();
    }
  }

  Future<void> _pushDirtyCustomers() async {
    final dirtyCustomers = await _localDb.getDirtyCustomers();
    for (final customer in dirtyCustomers) {
      await _pushCustomer(customer);
    }
  }

  Future<void> _pushCustomer(Customer customer) async {
    await _ref().child(customer.id).set(customer.toJson());
    await _localDb.markCustomerClean(customer.id);
    await _loadLocal();
  }

  Future<void> _loadLocal() async {
    _customers = await _localDb.getAllCustomers();
    _controller.add(_customers);
  }
}
