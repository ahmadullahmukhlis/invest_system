import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/id.dart';
import '../domain/purchase.dart';

class PurchaseNotifier extends StateNotifier<List<Purchase>> {
  PurchaseNotifier() : super([]);

  void add(Purchase purchase) {
    final resolved =
        purchase.id.isEmpty ? purchase.copyWith(id: newId()) : purchase;
    state = [...state, resolved];
  }

  void update(Purchase purchase) {
    state = [
      for (final item in state)
        if (item.id == purchase.id) purchase else item,
    ];
  }

  void remove(String id) {
    state = state.where((item) => item.id != id).toList();
  }

  Purchase buildPurchase({
    required String supplierId,
    required DateTime date,
    required double quantityValue,
    required String unitId,
    required double pricePerUnit,
    String? note,
  }) {
    final totalPrice = quantityValue * pricePerUnit;
    return Purchase(
      id: newId(),
      supplierId: supplierId,
      date: date,
      quantityValue: quantityValue,
      unitId: unitId,
      pricePerUnit: pricePerUnit,
      totalPrice: totalPrice,
      note: note,
    );
  }
}

final purchaseProvider = StateNotifierProvider<PurchaseNotifier, List<Purchase>>(
  (ref) => PurchaseNotifier(),
);
