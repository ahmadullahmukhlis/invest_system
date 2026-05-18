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

  StreamSubscription? _profileSub;
  List<Sale> _items = const [];

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

  Future<void> upsert(Sale sale) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final resolved = sale.id.isEmpty ? sale.copyWith(id: newId()) : sale;
    final existing = await _localDb.getById('sales', resolved.id);
    if (existing != null &&
        (existing['owner_uid'] as String? ?? '') != _currentUid) {
      return;
    }
    final normalized = resolved.copyWith(
      totalPrice: resolved.quantityValue * resolved.pricePerUnit,
    );
    await _localDb.upsert(
      'sales',
      {
        'id': normalized.id,
        'owner_uid': _currentUid,
        'customer_id': normalized.customerId,
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
    final existing = await _localDb.getById('sales', id);
    if (existing == null) return;
    if ((existing['owner_uid'] as String? ?? '') != _currentUid) return;
    await _localDb.delete('sales', id);
    await _loadLocal();
  }

  Future<bool> canEdit(String id) async {
    final existing = await _localDb.getById('sales', id);
    if (existing == null) return false;
    return (existing['owner_uid'] as String? ?? '') == _currentUid;
  }

  Future<void> _loadLocal() async {
    final rows = await _localDb.getAll(
      'sales',
      ownerUid: _currentUid,
      all: _isGlobal,
    );
    _items = rows
        .map(
          (row) => Sale(
            id: row['id'] as String,
            customerId: row['customer_id'] as String,
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
