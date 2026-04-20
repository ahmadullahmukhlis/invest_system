import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supplier_repository.dart';
import '../domain/supplier.dart';

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  throw UnimplementedError();
});

final suppliersStreamProvider = StreamProvider<List<Supplier>>((ref) {
  final repo = ref.watch(supplierRepositoryProvider);
  return repo.stream;
});

final suppliersProvider = Provider<List<Supplier>>((ref) {
  final async = ref.watch(suppliersStreamProvider);
  return async.value ?? const [];
});
