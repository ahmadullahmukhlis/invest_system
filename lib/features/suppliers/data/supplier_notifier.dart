import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/id.dart';
import '../domain/supplier.dart';

class SupplierNotifier extends StateNotifier<List<Supplier>> {
  SupplierNotifier() : super(_seed());

  static List<Supplier> _seed() {
    return [
      Supplier(
        id: newId(),
        name: 'Nazar Trading',
        phone: '0700-555-666',
        province: 'Kandahar',
        district: 'District 2',
        address: 'Industrial Park',
      ),
      Supplier(
        id: newId(),
        name: 'Sadaf Supplies',
        phone: '0700-777-888',
        province: 'Balkh',
        district: 'District 5',
        address: 'South Gate',
      ),
    ];
  }

  void add(Supplier supplier) {
    final resolved =
        supplier.id.isEmpty ? supplier.copyWith(id: newId()) : supplier;
    state = [...state, resolved];
  }

  void update(Supplier supplier) {
    state = [
      for (final item in state)
        if (item.id == supplier.id) supplier else item,
    ];
  }

  void remove(String id) {
    state = state.where((item) => item.id != id).toList();
  }
}

final supplierProvider = StateNotifierProvider<SupplierNotifier, List<Supplier>>(
  (ref) => SupplierNotifier(),
);
