import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/dates.dart';
import '../../customers/data/customer_providers.dart';
import '../../payments/data/payment_providers.dart';
import '../../purchases/data/purchase_providers.dart';
import '../../sales/data/sale_providers.dart';
import '../../supplier_payments/data/supplier_payment_providers.dart';

final totalSalesProvider = Provider<double>((ref) {
  final sales = ref.watch(salesProvider);
  return sales.fold(0.0, (sum, item) => sum + item.totalPrice);
});

final totalSalesTodayProvider = Provider<double>((ref) {
  final sales = ref.watch(salesProvider);
  final today = DateTime.now();
  return sales
      .where((sale) => isSameDay(sale.date, today))
      .fold(0.0, (sum, item) => sum + item.totalPrice);
});

final totalPurchasesProvider = Provider<double>((ref) {
  final purchases = ref.watch(purchasesProvider);
  return purchases.fold(0.0, (sum, item) => sum + item.totalPrice);
});

final totalPurchasesTodayProvider = Provider<double>((ref) {
  final purchases = ref.watch(purchasesProvider);
  final today = DateTime.now();
  return purchases
      .where((purchase) => isSameDay(purchase.date, today))
      .fold(0.0, (sum, item) => sum + item.totalPrice);
});

final totalPaymentsReceivedProvider = Provider<double>((ref) {
  final payments = ref.watch(paymentsProvider);
  return payments.fold(0.0, (sum, item) => sum + item.amount);
});

final totalPaymentsReceivedTodayProvider = Provider<double>((ref) {
  final payments = ref.watch(paymentsProvider);
  final today = DateTime.now();
  return payments
      .where((payment) => isSameDay(payment.date, today))
      .fold(0.0, (sum, item) => sum + item.amount);
});

final totalPaymentsPaidProvider = Provider<double>((ref) {
  final payments = ref.watch(supplierPaymentsProvider);
  return payments.fold(0.0, (sum, item) => sum + item.amount);
});

final totalPaymentsPaidTodayProvider = Provider<double>((ref) {
  final payments = ref.watch(supplierPaymentsProvider);
  final today = DateTime.now();
  return payments
      .where((payment) => isSameDay(payment.date, today))
      .fold(0.0, (sum, item) => sum + item.amount);
});

final totalCustomerBalanceProvider = Provider<double>((ref) {
  final sales = ref.watch(salesProvider);
  final payments = ref.watch(paymentsProvider);
  final totalSales = sales.fold(0.0, (sum, item) => sum + item.totalPrice);
  final totalPayments = payments.fold(0.0, (sum, item) => sum + item.amount);
  return totalSales - totalPayments;
});

final totalSupplierBalanceProvider = Provider<double>((ref) {
  final purchases = ref.watch(purchasesProvider);
  final payments = ref.watch(supplierPaymentsProvider);
  final totalPurchases =
      purchases.fold(0.0, (sum, item) => sum + item.totalPrice);
  final totalPayments = payments.fold(0.0, (sum, item) => sum + item.amount);
  return totalPurchases - totalPayments;
});

final topCustomersProvider = Provider<List<Map<String, Object>>>((ref) {
  final customers = ref.watch(customersProvider);
  final sales = ref.watch(salesProvider);
  final totals = <String, double>{};
  for (final sale in sales) {
    totals[sale.customerId] = (totals[sale.customerId] ?? 0) + sale.totalPrice;
  }
  final ranked = customers
      .map((customer) => {
            'customer': customer,
            'total': totals[customer.id] ?? 0.0,
          })
      .toList()
    ..sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
  return ranked.take(5).toList();
});
