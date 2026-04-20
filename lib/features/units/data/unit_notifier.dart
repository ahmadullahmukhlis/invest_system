import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/id.dart';
import '../domain/unit.dart';

class UnitNotifier extends StateNotifier<List<Unit>> {
  UnitNotifier() : super(_seed());

  static List<Unit> _seed() {
    return [
      Unit(id: newId(), name: 'kg', isActive: true),
      Unit(id: newId(), name: 'ton', isActive: true),
      Unit(id: newId(), name: 'bag', isActive: false),
    ];
  }

  void add(Unit unit) {
    final resolved = unit.id.isEmpty ? unit.copyWith(id: newId()) : unit;
    state = [...state, resolved];
  }

  void update(Unit unit) {
    state = [
      for (final item in state)
        if (item.id == unit.id) unit else item,
    ];
  }

  void remove(String id) {
    state = state.where((item) => item.id != id).toList();
  }

  void toggleActive(String id) {
    state = [
      for (final item in state)
        if (item.id == id) item.copyWith(isActive: !item.isActive) else item,
    ];
  }
}

final unitProvider = StateNotifierProvider<UnitNotifier, List<Unit>>(
  (ref) => UnitNotifier(),
);
