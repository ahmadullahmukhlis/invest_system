import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/id.dart';
import '../domain/supplier_payment.dart';

class SupplierPaymentNotifier extends StateNotifier<List<SupplierPayment>> {
  SupplierPaymentNotifier() : super([]);

  void add(SupplierPayment payment) {
    final resolved =
        payment.id.isEmpty ? payment.copyWith(id: newId()) : payment;
    state = [...state, resolved];
  }

  void update(SupplierPayment payment) {
    state = [
      for (final item in state)
        if (item.id == payment.id) payment else item,
    ];
  }

  void remove(String id) {
    state = state.where((item) => item.id != id).toList();
  }

  SupplierPayment buildPayment({
    required String supplierId,
    required DateTime date,
    required double amount,
    String? purchaseId,
    String? note,
  }) {
    return SupplierPayment(
      id: newId(),
      supplierId: supplierId,
      purchaseId: purchaseId,
      date: date,
      amount: amount,
      note: note,
    );
  }
}

final supplierPaymentProvider =
    StateNotifierProvider<SupplierPaymentNotifier, List<SupplierPayment>>(
  (ref) => SupplierPaymentNotifier(),
);
