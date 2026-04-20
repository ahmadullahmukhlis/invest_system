import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sale_repository.dart';
import '../domain/sale.dart';

final saleRepositoryProvider = Provider<SaleRepository>((ref) {
  throw UnimplementedError();
});

final salesStreamProvider = StreamProvider<List<Sale>>((ref) {
  final repo = ref.watch(saleRepositoryProvider);
  return repo.stream;
});

final salesProvider = Provider<List<Sale>>((ref) {
  final async = ref.watch(salesStreamProvider);
  return async.value ?? const [];
});
