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

  List<Purchase> _items = const [];
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

  Future<void> upsert(Purchase purchase) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final resolved = purchase.id.isEmpty
        ? purchase.copyWith(id: newId())
        : purchase;
    if (resolved.id.isNotEmpty) {
      final existing = await _localDb.getById('purchases', resolved.id);
      if (existing != null &&
          (existing['owner_uid'] as String? ?? '') != _currentUid) {
        return;
      }
    }
    final normalized = resolved.copyWith(
      totalPrice: resolved.quantityValue * resolved.pricePerUnit,
    );
    final row = _toRow(
      normalized,
      ownerUid: _currentUid,
      updatedAt: now,
      dirty: true,
      deleted: 0,
    );
    await _localDb.upsert('purchases', row);
    await _loadLocal();
  }

  Future<void> deleteById(String id) async {
    final existing = await _localDb.getById('purchases', id);
    if (existing == null) return;
    if ((existing['owner_uid'] as String? ?? '') != _currentUid) return;
    final updated = Map<String, Object?>.from(existing);
    updated['deleted'] = 1;
    updated['dirty'] = 1;
    updated['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    await _localDb.upsert('purchases', updated);
    await _loadLocal();
  }

  Future<bool> canEdit(String id) async {
    final existing = await _localDb.getById('purchases', id);
    if (existing == null) return false;
    return (existing['owner_uid'] as String? ?? '') == _currentUid;
  }

  String get _currentUid => _userRepository.current?.uid ?? '';

  bool get _isGlobal =>
      _userRepository.currentRole == 'admin' ||
      _userRepository.currentRole == 'super_admin';

  Future<void> _loadLocal() async {
    final rows = await _localDb.getAll(
      'purchases',
      ownerUid: _currentUid,
      all: _isGlobal,
    );
    _items = rows.map(_fromRow).toList();
    _controller.add(_items);
  }

  Purchase _fromRow(Map<String, Object?> row) {
    return Purchase(
      id: row['id'] as String,
      supplierId: row['supplier_id'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(row['date'] as int),
      quantityValue: (row['quantity_value'] as num).toDouble(),
      unitId: row['unit_id'] as String,
      pricePerUnit: (row['price_per_unit'] as num).toDouble(),
      totalPrice: (row['total_price'] as num).toDouble(),
      note: row['note'] as String?,
    );
  }

  Map<String, Object?> _toRow(
    Purchase purchase, {
    required String ownerUid,
    required int updatedAt,
    required bool dirty,
    required int deleted,
  }) {
    return {
      'id': purchase.id,
      'owner_uid': ownerUid,
      'supplier_id': purchase.supplierId,
      'date': purchase.date.millisecondsSinceEpoch,
      'quantity_value': purchase.quantityValue,
      'unit_id': purchase.unitId,
      'price_per_unit': purchase.pricePerUnit,
      'total_price': purchase.totalPrice,
      'note': purchase.note,
      'deleted': deleted,
      'updated_at': updatedAt,
      'dirty': dirty ? 1 : 0,
    };
  }

  Future<void> syncNow() => _loadLocal();
  Future<void> pullRemoteNow() => _loadLocal();
  Future<void> pushLocalNow() => _loadLocal();
}
