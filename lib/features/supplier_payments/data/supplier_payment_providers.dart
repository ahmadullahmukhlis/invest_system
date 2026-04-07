import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supplier_payment_repository.dart';
import '../domain/supplier_payment.dart';

final supplierPaymentRepositoryProvider =
    Provider<SupplierPaymentRepository>((ref) {
  throw UnimplementedError();
});

final supplierPaymentsStreamProvider =
    StreamProvider<List<SupplierPayment>>((ref) {
  final repo = ref.watch(supplierPaymentRepositoryProvider);
  return repo.stream;
});

final supplierPaymentsProvider = Provider<List<SupplierPayment>>((ref) {
  final async = ref.watch(supplierPaymentsStreamProvider);
  return async.value ?? const [];
});
