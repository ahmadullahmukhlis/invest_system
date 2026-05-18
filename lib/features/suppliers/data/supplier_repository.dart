import 'dart:async';

import '../../../core/data/local_db.dart';
import '../../../core/utils/id.dart';
import '../../../data/user_repository.dart';
import '../domain/supplier.dart';

class SupplierRepository {
  SupplierRepository({
    LocalDb? localDb,
    required UserRepository userRepository,
  })  : _localDb = localDb ?? LocalDb.instance,
        _userRepository = userRepository;

  final LocalDb _localDb;
  final UserRepository _userRepository;

  final _controller = StreamController<List<Supplier>>.broadcast();
  Stream<List<Supplier>> get stream => _controller.stream;

  StreamSubscription? _profileSub;
  List<Supplier> _items = const [];

  String get _currentUid =>
      _userRepository.current?.uid ?? UserRepository.localUserId;
  bool get _isGlobal =>
      _userRepository.currentRole == 'admin' ||
      _userRepository.currentRole == 'super_admin';

  Future<void> init() async {
    await _localDb.init();
    await _loadLocal();
    _profileSub = _userRepository.currentUserStream.listen((_) async {
      await _loadLocal();
    });
  }

  Future<void> dispose() async {
    await _profileSub?.cancel();
    await _controller.close();
  }

  Future<void> upsert(Supplier supplier) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final resolved = supplier.id.isEmpty
        ? supplier.copyWith(id: newId())
        : supplier;
    final existing = await _localDb.getById('suppliers', resolved.id);
    if (existing != null &&
        (existing['owner_uid'] as String? ?? '') != _currentUid) {
      return;
    }
    await _localDb.upsert(
      'suppliers',
      {
        'id': resolved.id,
        'owner_uid': _currentUid,
        'name': resolved.name,
        'phone': resolved.phone,
        'province': resolved.province,
        'district': resolved.district,
        'address': resolved.address,
        'deleted': 0,
        'updated_at': now,
        'dirty': 0,
      },
    );
    await _loadLocal();
  }

  Future<void> deleteById(String id) async {
    final existing = await _localDb.getById('suppliers', id);
    if (existing == null) return;
    if ((existing['owner_uid'] as String? ?? '') != _currentUid) return;
    await _localDb.delete('suppliers', id);
    await _loadLocal();
  }

  Future<bool> canEdit(String id) async {
    final existing = await _localDb.getById('suppliers', id);
    if (existing == null) return false;
    return (existing['owner_uid'] as String? ?? '') == _currentUid;
  }

  Future<void> _loadLocal() async {
    final rows = await _localDb.getAll(
      'suppliers',
      ownerUid: _currentUid,
      all: _isGlobal,
    );
    _items = rows
        .map(
          (row) => Supplier(
            id: row['id'] as String,
            name: row['name'] as String,
            phone: row['phone'] as String,
            province: row['province'] as String,
            district: row['district'] as String,
            address: row['address'] as String?,
          ),
        )
        .toList();
    _controller.add(_items);
  }

  Future<void> syncNow() async {}
  Future<void> pullRemoteNow() async {}
  Future<void> pushLocalNow() async {}
}
