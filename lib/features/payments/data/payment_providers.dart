import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'payment_repository.dart';
import '../domain/payment.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  throw UnimplementedError();
});

final paymentsStreamProvider = StreamProvider<List<Payment>>((ref) {
  final repo = ref.watch(paymentRepositoryProvider);
  return repo.stream;
});

final paymentsProvider = Provider<List<Payment>>((ref) {
  final async = ref.watch(paymentsStreamProvider);
  return async.value ?? const [];
});
