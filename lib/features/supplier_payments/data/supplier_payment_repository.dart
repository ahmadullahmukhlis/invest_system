import 'dart:async';

import '../../../core/data/local_db.dart';
import '../../../core/utils/id.dart';
import '../../../data/user_repository.dart';
import '../domain/supplier_payment.dart';

class SupplierPaymentRepository {
  SupplierPaymentRepository({
    LocalDb? localDb,
    required UserRepository userRepository,
  })  : _localDb = localDb ?? LocalDb.instance,
        _userRepository = userRepository;

  final LocalDb _localDb;
  final UserRepository _userRepository;

  final _controller = StreamController<List<SupplierPayment>>.broadcast();
  Stream<List<SupplierPayment>> get stream => _controller.stream;

  List<SupplierPayment> _items = const [];
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

  Future<void> upsert(SupplierPayment payment) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final resolved = payment.id.isEmpty
        ? payment.copyWith(id: newId())
        : payment;
    if (resolved.id.isNotEmpty) {
      final existing = await _localDb.getById(
        'supplier_payments',
        resolved.id,
      );
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
    await _localDb.upsert('supplier_payments', row);
    await _loadLocal();
  }

  Future<void> deleteById(String id) async {
    final existing = await _localDb.getById('supplier_payments', id);
    if (existing == null) return;
    if ((existing['owner_uid'] as String? ?? '') != _currentUid) return;
    final updated = Map<String, Object?>.from(existing);
    updated['deleted'] = 1;
    updated['dirty'] = 1;
    updated['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    await _localDb.upsert('supplier_payments', updated);
    await _loadLocal();
  }

  Future<bool> canEdit(String id) async {
    final existing = await _localDb.getById('supplier_payments', id);
    if (existing == null) return false;
    return (existing['owner_uid'] as String? ?? '') == _currentUid;
  }

  String get _currentUid => _userRepository.current?.uid ?? '';

  bool get _isGlobal =>
      _userRepository.currentRole == 'admin' ||
      _userRepository.currentRole == 'super_admin';

  Future<void> _loadLocal() async {
    final rows = await _localDb.getAll(
      'supplier_payments',
      ownerUid: _currentUid,
      all: _isGlobal,
    );
    _items = rows.map(_fromRow).toList();
    _controller.add(_items);
  }

  SupplierPayment _fromRow(Map<String, Object?> row) {
    return SupplierPayment(
      id: row['id'] as String,
      supplierId: row['supplier_id'] as String,
      purchaseId: row['purchase_id'] as String?,
      date: DateTime.fromMillisecondsSinceEpoch(row['date'] as int),
      amount: (row['amount'] as num).toDouble(),
      note: row['note'] as String?,
    );
  }

  Map<String, Object?> _toRow(
    SupplierPayment payment, {
    required String ownerUid,
    required int updatedAt,
    required bool dirty,
    required int deleted,
  }) {
    return {
      'id': payment.id,
      'owner_uid': ownerUid,
      'supplier_id': payment.supplierId,
      'purchase_id': payment.purchaseId,
      'date': payment.date.millisecondsSinceEpoch,
      'amount': payment.amount,
      'note': payment.note,
      'deleted': deleted,
      'updated_at': updatedAt,
      'dirty': dirty ? 1 : 0,
    };
  }

  Future<void> syncNow() => _loadLocal();
  Future<void> pullRemoteNow() => _loadLocal();
  Future<void> pushLocalNow() => _loadLocal();
}
