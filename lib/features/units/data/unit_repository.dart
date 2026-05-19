import 'dart:async';

import '../../../core/data/local_db.dart';
import '../../../core/utils/id.dart';
import '../../../data/user_repository.dart';
import '../domain/unit.dart';

class UnitRepository {
  UnitRepository({
    LocalDb? localDb,
    required UserRepository userRepository,
  })  : _localDb = localDb ?? LocalDb.instance,
        _userRepository = userRepository;

  final LocalDb _localDb;
  final UserRepository _userRepository;

  final _controller = StreamController<List<Unit>>.broadcast();
  Stream<List<Unit>> get stream => _controller.stream;

  List<Unit> _items = const [];
  StreamSubscription? _profileSub;

  Future<void> init() async {
    await _localDb.init();
    await _loadLocal();
    if (_items.isEmpty) {
      await _seedDefaults();
    }
    _profileSub = _userRepository.currentUserStream.listen((_) async {
      await _loadLocal();
    });
  }

  Future<void> _seedDefaults() async {
    const defaults = ['kg', 'ton', 'bag'];
    for (final name in defaults) {
      await upsert(Unit(id: '', name: name, isActive: true));
    }
  }

  Future<void> dispose() async {
    await _profileSub?.cancel();
    await _controller.close();
  }

  Future<void> upsert(Unit unit) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final resolved = unit.id.isEmpty ? unit.copyWith(id: newId()) : unit;
    final row = _toRow(
      resolved,
      ownerUid: '',
      updatedAt: now,
      dirty: true,
      deleted: 0,
    );
    await _localDb.upsert('units', row);
    await _loadLocal();
  }

  Future<void> toggleActive(String id) async {
    final existing = await _localDb.getById('units', id);
    if (existing == null) return;
    final updated = Map<String, Object?>.from(existing);
    final currentActive = (existing['is_active'] as int? ?? 1) == 1;
    updated['is_active'] = currentActive ? 0 : 1;
    updated['dirty'] = 1;
    updated['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    await _localDb.upsert('units', updated);
    await _loadLocal();
  }

  Future<void> deleteById(String id) async {
    final existing = await _localDb.getById('units', id);
    if (existing == null) return;
    final updated = Map<String, Object?>.from(existing);
    updated['deleted'] = 1;
    updated['dirty'] = 1;
    updated['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    await _localDb.upsert('units', updated);
    await _loadLocal();
  }

  Future<void> _loadLocal() async {
    final rows = await _localDb.getAll('units', all: true);
    _items = rows.map(_fromRow).toList();
    _controller.add(_items);
  }

  Unit _fromRow(Map<String, Object?> row) {
    return Unit(
      id: row['id'] as String,
      name: row['name'] as String,
      isActive: (row['is_active'] as int? ?? 1) == 1,
    );
  }

  Map<String, Object?> _toRow(
    Unit unit, {
    required String ownerUid,
    required int updatedAt,
    required bool dirty,
    required int deleted,
  }) {
    return {
      'id': unit.id,
      'owner_uid': ownerUid,
      'name': unit.name,
      'is_active': unit.isActive ? 1 : 0,
      'deleted': deleted,
      'updated_at': updatedAt,
      'dirty': dirty ? 1 : 0,
    };
  }

  Future<void> syncNow() => _loadLocal();
  Future<void> pullRemoteNow() => _loadLocal();
  Future<void> pushLocalNow() => _loadLocal();
}
