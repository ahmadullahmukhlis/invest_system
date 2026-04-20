import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/id.dart';
import '../domain/customer.dart';

class CustomerNotifier extends StateNotifier<List<Customer>> {
  CustomerNotifier() : super(_seed());

  static List<Customer> _seed() {
    return [
      Customer(
        id: newId(),
        name: 'Ahmad Noor',
        phone: '0700-111-222',
        province: 'Kabul',
        district: 'District 1',
        address: 'Bazaar Road',
      ),
      Customer(
        id: newId(),
        name: 'Fatima Rahimi',
        phone: '0700-333-444',
        province: 'Herat',
        district: 'District 3',
        address: 'North Market',
      ),
    ];
  }

  void add(Customer customer) {
    final resolved = customer.id.isEmpty
        ? customer.copyWith(id: newId())
        : customer;
    state = [...state, resolved];
  }

  void update(Customer customer) {
    state = [
      for (final item in state)
        if (item.id == customer.id) customer else item,
    ];
  }

  void remove(String id) {
    state = state.where((item) => item.id != id).toList();
  }
}

final customerProvider = StateNotifierProvider<CustomerNotifier, List<Customer>>(
  (ref) => CustomerNotifier(),
);
