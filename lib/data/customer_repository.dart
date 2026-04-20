import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';

import 'customer.dart';
import 'local_db.dart';
import '../core/utils/network_utils.dart';
import 'user_repository.dart';

class CustomerRepository {
  CustomerRepository({
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

  final _controller = StreamController<List<Customer>>.broadcast();
  Stream<List<Customer>> get stream => _controller.stream;

  List<Customer> _customers = const [];
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
      ownerUid: _currentUid,
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
    final online = await hasInternetConnection(result);
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

  String get _currentUid => _auth.currentUser?.uid ?? '';

  bool get _isGlobal =>
      _userRepository.currentRole == 'admin' ||
      _userRepository.currentRole == 'super_admin';

  DatabaseReference _ref() {
    return _isGlobal
        ? _database.ref('customers')
        : _database.ref('customers/$_currentUid');
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
          final remote = Customer.fromJson(
            key,
            ownerUid,
            data.cast<dynamic, dynamic>(),
          );
          final local =
              await _localDb.getCustomerById(remote.id, ownerUid: ownerUid);
          if (local == null || remote.updatedAt > local.updatedAt) {
            await _localDb.upsertCustomer(remote.copyWith(dirty: false));
            changed = true;
          }
        }
      }
    } else {
      for (final entry in value.entries) {
        final key = entry.key;
        final data = entry.value;
        if (key is! String || data is! Map) continue;

        final remote = Customer.fromJson(
          key,
          _currentUid,
          data.cast<dynamic, dynamic>(),
        );
        final local =
            await _localDb.getCustomerById(remote.id, ownerUid: _currentUid);
        if (local == null || remote.updatedAt > local.updatedAt) {
          await _localDb.upsertCustomer(remote.copyWith(dirty: false));
          changed = true;
        }
      }
    }

    if (changed) {
      await _loadLocal();
    }
  }

  Future<void> _pushDirtyCustomers() async {
    final dirtyCustomers = await _localDb.getDirtyCustomers(
      ownerUid: _currentUid,
      all: _isGlobal,
    );
    for (final customer in dirtyCustomers) {
      await _pushCustomer(customer);
    }
  }

  Future<void> _pushCustomer(Customer customer) async {
    final ownerUid = customer.ownerUid.isEmpty ? _currentUid : customer.ownerUid;
    await _database.ref('customers/$ownerUid').child(customer.id).set(
          customer.toJson(),
        );
    await _localDb.markCustomerClean(customer.id);
    await _loadLocal();
  }

  Future<void> _loadLocal() async {
    if (!_isGlobal && _currentUid.isNotEmpty) {
      await _localDb.claimUnownedCustomers(_currentUid);
    }
    _customers = await _localDb.getAllCustomers(
      ownerUid: _currentUid,
      all: _isGlobal,
    );
    _controller.add(_customers);
  }
}
