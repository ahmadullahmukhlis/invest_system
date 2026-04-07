import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/id.dart';
import '../domain/payment.dart';

class PaymentNotifier extends StateNotifier<List<Payment>> {
  PaymentNotifier() : super([]);

  void add(Payment payment) {
    final resolved =
        payment.id.isEmpty ? payment.copyWith(id: newId()) : payment;
    state = [...state, resolved];
  }

  void update(Payment payment) {
    state = [
      for (final item in state)
        if (item.id == payment.id) payment else item,
    ];
  }

  void remove(String id) {
    state = state.where((item) => item.id != id).toList();
  }

  Payment buildPayment({
    required String customerId,
    required DateTime date,
    required double amount,
    String? saleId,
    String? note,
  }) {
    return Payment(
      id: newId(),
      customerId: customerId,
      saleId: saleId,
      date: date,
      amount: amount,
      note: note,
    );
  }
}

final paymentProvider = StateNotifierProvider<PaymentNotifier, List<Payment>>(
  (ref) => PaymentNotifier(),
);
