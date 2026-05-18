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

  StreamSubscription? _profileSub;
  List<SupplierPayment> _items = const [];

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

  Future<void> upsert(SupplierPayment payment) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final resolved = payment.id.isEmpty
        ? payment.copyWith(id: newId())
        : payment;
    final existing = await _localDb.getById('supplier_payments', resolved.id);
    if (existing != null &&
        (existing['owner_uid'] as String? ?? '') != _currentUid) {
      return;
    }
    await _localDb.upsert(
      'supplier_payments',
      {
        'id': resolved.id,
        'owner_uid': _currentUid,
        'supplier_id': resolved.supplierId,
        'purchase_id': resolved.purchaseId,
        'date': resolved.date.millisecondsSinceEpoch,
        'amount': resolved.amount,
        'note': resolved.note,
        'deleted': 0,
        'updated_at': now,
        'dirty': 0,
      },
    );
    await _loadLocal();
  }

  Future<void> deleteById(String id) async {
    final existing = await _localDb.getById('supplier_payments', id);
    if (existing == null) return;
    if ((existing['owner_uid'] as String? ?? '') != _currentUid) return;
    await _localDb.delete('supplier_payments', id);
    await _loadLocal();
  }

  Future<bool> canEdit(String id) async {
    final existing = await _localDb.getById('supplier_payments', id);
    if (existing == null) return false;
    return (existing['owner_uid'] as String? ?? '') == _currentUid;
  }

  Future<void> _loadLocal() async {
    final rows = await _localDb.getAll(
      'supplier_payments',
      ownerUid: _currentUid,
      all: _isGlobal,
    );
    _items = rows
        .map(
          (row) => SupplierPayment(
            id: row['id'] as String,
            supplierId: row['supplier_id'] as String,
            purchaseId: row['purchase_id'] as String?,
            date: DateTime.fromMillisecondsSinceEpoch(row['date'] as int),
            amount: (row['amount'] as num).toDouble(),
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
