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

  StreamSubscription? _profileSub;
  List<Unit> _items = const [];

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

  Future<void> dispose() async {
    await _profileSub?.cancel();
    await _controller.close();
  }

  Future<void> _seedDefaults() async {
    for (final name in const ['kg', 'ton', 'bag']) {
      await upsert(Unit(id: '', name: name, isActive: true));
    }
  }

  Future<void> upsert(Unit unit) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final resolved = unit.id.isEmpty ? unit.copyWith(id: newId()) : unit;
    await _localDb.upsert(
      'units',
      {
        'id': resolved.id,
        'owner_uid': '',
        'name': resolved.name,
        'is_active': resolved.isActive ? 1 : 0,
        'deleted': 0,
        'updated_at': now,
        'dirty': 0,
      },
    );
    await _loadLocal();
  }

  Future<void> toggleActive(String id) async {
    final existing = await _localDb.getById('units', id);
    if (existing == null) return;
    await _localDb.upsert(
      'units',
      {
        ...existing,
        'is_active': (existing['is_active'] as int? ?? 1) == 1 ? 0 : 1,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'dirty': 0,
      },
    );
    await _loadLocal();
  }

  Future<void> deleteById(String id) async {
    await _localDb.delete('units', id);
    await _loadLocal();
  }

  Future<void> _loadLocal() async {
    final rows = await _localDb.getAll('units', all: true);
    _items = rows
        .map(
          (row) => Unit(
            id: row['id'] as String,
            name: row['name'] as String,
            isActive: (row['is_active'] as int? ?? 1) == 1,
          ),
        )
        .toList();
    _controller.add(_items);
  }

  Future<void> syncNow() async {}
  Future<void> pullRemoteNow() async {}
  Future<void> pushLocalNow() async {}
}
