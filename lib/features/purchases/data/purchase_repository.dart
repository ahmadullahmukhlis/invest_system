import 'dart:async';

import '../../../core/data/local_db.dart';
import '../../../core/utils/id.dart';
import '../../../data/user_repository.dart';
import '../domain/purchase.dart';

class PurchaseRepository {
  PurchaseRepository({
    LocalDb? localDb,
    required UserRepository userRepository,
  })  : _localDb = localDb ?? LocalDb.instance,
        _userRepository = userRepository;

  final LocalDb _localDb;
  final UserRepository _userRepository;

  final _controller = StreamController<List<Purchase>>.broadcast();
  Stream<List<Purchase>> get stream => _controller.stream;

  StreamSubscription? _profileSub;
  List<Purchase> _items = const [];

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

  Future<void> upsert(Purchase purchase) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final resolved = purchase.id.isEmpty
        ? purchase.copyWith(id: newId())
        : purchase;
    final existing = await _localDb.getById('purchases', resolved.id);
    if (existing != null &&
        (existing['owner_uid'] as String? ?? '') != _currentUid) {
      return;
    }
    final normalized = resolved.copyWith(
      totalPrice: resolved.quantityValue * resolved.pricePerUnit,
    );
    await _localDb.upsert(
      'purchases',
      {
        'id': normalized.id,
        'owner_uid': _currentUid,
        'supplier_id': normalized.supplierId,
        'date': normalized.date.millisecondsSinceEpoch,
        'quantity_value': normalized.quantityValue,
        'unit_id': normalized.unitId,
        'price_per_unit': normalized.pricePerUnit,
        'total_price': normalized.totalPrice,
        'note': normalized.note,
        'deleted': 0,
        'updated_at': now,
        'dirty': 0,
      },
    );
    await _loadLocal();
  }

  Future<void> deleteById(String id) async {
    final existing = await _localDb.getById('purchases', id);
    if (existing == null) return;
    if ((existing['owner_uid'] as String? ?? '') != _currentUid) return;
    await _localDb.delete('purchases', id);
    await _loadLocal();
  }

  Future<bool> canEdit(String id) async {
    final existing = await _localDb.getById('purchases', id);
    if (existing == null) return false;
    return (existing['owner_uid'] as String? ?? '') == _currentUid;
  }

  Future<void> _loadLocal() async {
    final rows = await _localDb.getAll(
      'purchases',
      ownerUid: _currentUid,
      all: _isGlobal,
    );
    _items = rows
        .map(
          (row) => Purchase(
            id: row['id'] as String,
            supplierId: row['supplier_id'] as String,
            date: DateTime.fromMillisecondsSinceEpoch(row['date'] as int),
            quantityValue: (row['quantity_value'] as num).toDouble(),
            unitId: row['unit_id'] as String,
            pricePerUnit: (row['price_per_unit'] as num).toDouble(),
            totalPrice: (row['total_price'] as num).toDouble(),
            note: row['note'] as String?,
          ),
        )
        .toList();
    _controller.add(_items);
  }

  Future<void> syncNow() async {}
  Future<void> pullRemoteNow() async {}
  Future<void> pushLocalNow() async {}
}
