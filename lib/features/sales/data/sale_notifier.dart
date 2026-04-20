import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/id.dart';
import '../domain/sale.dart';

class SaleNotifier extends StateNotifier<List<Sale>> {
  SaleNotifier() : super([]);

  void add(Sale sale) {
    final resolved = sale.id.isEmpty ? sale.copyWith(id: newId()) : sale;
    state = [...state, resolved];
  }

  void update(Sale sale) {
    state = [
      for (final item in state)
        if (item.id == sale.id) sale else item,
    ];
  }

  void remove(String id) {
    state = state.where((item) => item.id != id).toList();
  }

  Sale buildSale({
    required String customerId,
    required DateTime date,
    required double quantityValue,
    required String unitId,
    required double pricePerUnit,
    String? note,
  }) {
    final totalPrice = quantityValue * pricePerUnit;
    return Sale(
      id: newId(),
      customerId: customerId,
      date: date,
      quantityValue: quantityValue,
      unitId: unitId,
      pricePerUnit: pricePerUnit,
      totalPrice: totalPrice,
      note: note,
    );
  }
}

final saleProvider = StateNotifierProvider<SaleNotifier, List<Sale>>(
  (ref) => SaleNotifier(),
);
