import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'unit_repository.dart';
import '../domain/unit.dart';

final unitRepositoryProvider = Provider<UnitRepository>((ref) {
  throw UnimplementedError();
});

final unitsStreamProvider = StreamProvider<List<Unit>>((ref) {
  final repo = ref.watch(unitRepositoryProvider);
  return repo.stream;
});

final unitsProvider = Provider<List<Unit>>((ref) {
  final async = ref.watch(unitsStreamProvider);
  return async.value ?? const [];
});
