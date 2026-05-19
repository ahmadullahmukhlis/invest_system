import 'dart:async';

import '../../../core/data/local_db.dart';
import '../../../core/utils/id.dart';
import '../../../data/user_repository.dart';
import '../domain/customer.dart';

class CustomerRepository {
  CustomerRepository({
    LocalDb? localDb,
    required UserRepository userRepository,
  })  : _localDb = localDb ?? LocalDb.instance,
        _userRepository = userRepository;

  final LocalDb _localDb;
  final UserRepository _userRepository;

  final _controller = StreamController<List<Customer>>.broadcast();
  Stream<List<Customer>> get stream => _controller.stream;

  List<Customer> _items = const [];
  StreamSubscription? _profileSub;

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
  }

  Future<void> deleteById(String id) async {
    final existing = await _localDb.getById('customers', id);
    if (existing == null) return;
    if ((existing['owner_uid'] as String? ?? '') != _currentUid) return;
    final updated = Map<String, Object?>.from(existing);
    updated['deleted'] = 1;
    updated['dirty'] = 1;
    updated['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    await _localDb.upsert('customers', updated);
    await _loadLocal();
  }

  Future<bool> canEdit(String id) async {
    final existing = await _localDb.getById('customers', id);
    if (existing == null) return false;
    return (existing['owner_uid'] as String? ?? '') == _currentUid;
  }

  String get _currentUid => _userRepository.current?.uid ?? '';

  bool get _isGlobal =>
      _userRepository.currentRole == 'admin' ||
      _userRepository.currentRole == 'super_admin';

  Future<void> _loadLocal() async {
    final rows = await _localDb.getAll(
      'customers',
      ownerUid: _currentUid,
      all: _isGlobal,
    );
    _items = rows.map(_fromRow).toList();
    _controller.add(_items);
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

  Future<void> syncNow() => _loadLocal();
  Future<void> pullRemoteNow() => _loadLocal();
  Future<void> pushLocalNow() => _loadLocal();
}
