import 'dart:async';

import '../../../core/data/local_db.dart';
import '../../../core/utils/id.dart';
import '../../../data/user_repository.dart';
import '../domain/payment.dart';

class PaymentRepository {
  PaymentRepository({
    LocalDb? localDb,
    required UserRepository userRepository,
  })  : _localDb = localDb ?? LocalDb.instance,
        _userRepository = userRepository;

  final LocalDb _localDb;
  final UserRepository _userRepository;

  final _controller = StreamController<List<Payment>>.broadcast();
  Stream<List<Payment>> get stream => _controller.stream;

  StreamSubscription? _profileSub;
  List<Payment> _items = const [];

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

  Future<void> upsert(Payment payment) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final resolved = payment.id.isEmpty
        ? payment.copyWith(id: newId())
        : payment;
    final existing = await _localDb.getById('payments', resolved.id);
    if (existing != null &&
        (existing['owner_uid'] as String? ?? '') != _currentUid) {
      return;
    }
    await _localDb.upsert(
      'payments',
      {
        'id': resolved.id,
        'owner_uid': _currentUid,
        'customer_id': resolved.customerId,
        'sale_id': resolved.saleId,
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
    final existing = await _localDb.getById('payments', id);
    if (existing == null) return;
    if ((existing['owner_uid'] as String? ?? '') != _currentUid) return;
    await _localDb.delete('payments', id);
    await _loadLocal();
  }

  Future<bool> canEdit(String id) async {
    final existing = await _localDb.getById('payments', id);
    if (existing == null) return false;
    return (existing['owner_uid'] as String? ?? '') == _currentUid;
  }

  Future<void> _loadLocal() async {
    final rows = await _localDb.getAll(
      'payments',
      ownerUid: _currentUid,
      all: _isGlobal,
    );
    _items = rows
        .map(
          (row) => Payment(
            id: row['id'] as String,
            customerId: row['customer_id'] as String,
            saleId: row['sale_id'] as String?,
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
