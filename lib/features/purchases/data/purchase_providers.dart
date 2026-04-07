import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'purchase_repository.dart';
import '../domain/purchase.dart';

final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) {
  throw UnimplementedError();
});

final purchasesStreamProvider = StreamProvider<List<Purchase>>((ref) {
  final repo = ref.watch(purchaseRepositoryProvider);
  return repo.stream;
});

final purchasesProvider = Provider<List<Purchase>>((ref) {
  final async = ref.watch(purchasesStreamProvider);
  return async.value ?? const [];
});
