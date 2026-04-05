import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';

import 'local_db.dart';
import 'vendor.dart';
import 'user_repository.dart';

class VendorRepository {
  VendorRepository({
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

  final _controller = StreamController<List<Vendor>>.broadcast();
  Stream<List<Vendor>> get stream => _controller.stream;

  List<Vendor> _vendors = const [];
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

  Future<void> addVendor({
    required String name,
    required String phone,
    required String email,
    required String address,
    required String company,
    required String notes,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final vendor = Vendor(
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
    await _localDb.upsertVendor(vendor);
    await _loadLocal();

    if (_online) {
      await _pushVendor(vendor);
    }
  }

  Future<void> updateVendor(Vendor vendor) async {
    final updated = vendor.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      dirty: true,
    );
    await _localDb.upsertVendor(updated);
    await _loadLocal();

    if (_online) {
      await _pushVendor(updated);
    }
  }

  Future<void> _handleConnectivity(List<ConnectivityResult> result) async {
    final online = result.isNotEmpty &&
        !result.every((entry) => entry == ConnectivityResult.none);
    if (online == _online) return;
    _online = online;

    if (_online) {
      await _startRemoteSync();
      await _pushDirtyVendors();
    } else {
      await _stopRemoteSync();
    }

    _controller.add(_vendors);
  }

  String get _currentUid => _auth.currentUser?.uid ?? '';

  bool get _isGlobal =>
      _userRepository.currentRole == 'admin' ||
      _userRepository.currentRole == 'super_admin';

  DatabaseReference _ref() {
    return _isGlobal
        ? _database.ref('vendors')
        : _database.ref('vendors/$_currentUid');
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
          final remote = Vendor.fromJson(
            key,
            ownerUid,
            data.cast<dynamic, dynamic>(),
          );
          final local =
              await _localDb.getVendorById(remote.id, ownerUid: ownerUid);
          if (local == null || remote.updatedAt > local.updatedAt) {
            await _localDb.upsertVendor(remote.copyWith(dirty: false));
            changed = true;
          }
        }
      }
    } else {
      for (final entry in value.entries) {
        final key = entry.key;
        final data = entry.value;
        if (key is! String || data is! Map) continue;

        final remote = Vendor.fromJson(
          key,
          _currentUid,
          data.cast<dynamic, dynamic>(),
        );
        final local =
            await _localDb.getVendorById(remote.id, ownerUid: _currentUid);
        if (local == null || remote.updatedAt > local.updatedAt) {
          await _localDb.upsertVendor(remote.copyWith(dirty: false));
          changed = true;
        }
      }
    }

    if (changed) {
      await _loadLocal();
    }
  }

  Future<void> _pushDirtyVendors() async {
    final dirtyVendors = await _localDb.getDirtyVendors(
      ownerUid: _currentUid,
      all: _isGlobal,
    );
    for (final vendor in dirtyVendors) {
      await _pushVendor(vendor);
    }
  }

  Future<void> _pushVendor(Vendor vendor) async {
    final ownerUid = vendor.ownerUid.isEmpty ? _currentUid : vendor.ownerUid;
    await _database.ref('vendors/$ownerUid').child(vendor.id).set(
          vendor.toJson(),
        );
    await _localDb.markVendorClean(vendor.id);
    await _loadLocal();
  }

  Future<void> _loadLocal() async {
    if (!_isGlobal && _currentUid.isNotEmpty) {
      await _localDb.claimUnownedVendors(_currentUid);
    }
    _vendors = await _localDb.getAllVendors(
      ownerUid: _currentUid,
      all: _isGlobal,
    );
    _controller.add(_vendors);
  }
}
