import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'customer_repository.dart';
import '../domain/customer.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  throw UnimplementedError();
});

final customersStreamProvider = StreamProvider<List<Customer>>((ref) {
  final repo = ref.watch(customerRepositoryProvider);
  return repo.stream;
});

final customersProvider = Provider<List<Customer>>((ref) {
  final async = ref.watch(customersStreamProvider);
  return async.value ?? const [];
});
