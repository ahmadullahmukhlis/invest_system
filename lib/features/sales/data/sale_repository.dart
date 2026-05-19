import 'dart:async';

import '../../../core/data/local_db.dart';
import '../../../core/utils/id.dart';
import '../../../data/user_repository.dart';
import '../domain/sale.dart';

class SaleRepository {
  SaleRepository({
    LocalDb? localDb,
    required UserRepository userRepository,
  })  : _localDb = localDb ?? LocalDb.instance,
        _userRepository = userRepository;

  final LocalDb _localDb;
  final UserRepository _userRepository;

  final _controller = StreamController<List<Sale>>.broadcast();
  Stream<List<Sale>> get stream => _controller.stream;

  List<Sale> _items = const [];
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

  Future<void> upsert(Sale sale) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final resolved = sale.id.isEmpty ? sale.copyWith(id: newId()) : sale;
    if (resolved.id.isNotEmpty) {
      final existing = await _localDb.getById('sales', resolved.id);
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
    await _localDb.upsert('sales', row);
    await _loadLocal();
  }

  Future<void> deleteById(String id) async {
    final existing = await _localDb.getById('sales', id);
    if (existing == null) return;
    if ((existing['owner_uid'] as String? ?? '') != _currentUid) return;
    final updated = Map<String, Object?>.from(existing);
    updated['deleted'] = 1;
    updated['dirty'] = 1;
    updated['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    await _localDb.upsert('sales', updated);
    await _loadLocal();
  }

  Future<bool> canEdit(String id) async {
    final existing = await _localDb.getById('sales', id);
    if (existing == null) return false;
    return (existing['owner_uid'] as String? ?? '') == _currentUid;
  }

  String get _currentUid => _userRepository.current?.uid ?? '';

  bool get _isGlobal =>
      _userRepository.currentRole == 'admin' ||
      _userRepository.currentRole == 'super_admin';

  Future<void> _loadLocal() async {
    final rows = await _localDb.getAll(
      'sales',
      ownerUid: _currentUid,
      all: _isGlobal,
    );
    _items = rows.map(_fromRow).toList();
    _controller.add(_items);
  }

  Sale _fromRow(Map<String, Object?> row) {
    return Sale(
      id: row['id'] as String,
      customerId: row['customer_id'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(row['date'] as int),
      quantityValue: (row['quantity_value'] as num).toDouble(),
      unitId: row['unit_id'] as String,
      pricePerUnit: (row['price_per_unit'] as num).toDouble(),
      totalPrice: (row['total_price'] as num).toDouble(),
      note: row['note'] as String?,
    );
  }

  Map<String, Object?> _toRow(
    Sale sale, {
    required String ownerUid,
    required int updatedAt,
    required bool dirty,
    required int deleted,
  }) {
    return {
      'id': sale.id,
      'owner_uid': ownerUid,
      'customer_id': sale.customerId,
      'date': sale.date.millisecondsSinceEpoch,
      'quantity_value': sale.quantityValue,
      'unit_id': sale.unitId,
      'price_per_unit': sale.pricePerUnit,
      'total_price': sale.totalPrice,
      'note': sale.note,
      'deleted': deleted,
      'updated_at': updatedAt,
      'dirty': dirty ? 1 : 0,
    };
  }

  Future<void> syncNow() => _loadLocal();
  Future<void> pullRemoteNow() => _loadLocal();
  Future<void> pushLocalNow() => _loadLocal();
}
