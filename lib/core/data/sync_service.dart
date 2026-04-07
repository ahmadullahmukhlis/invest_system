import '../../features/customers/data/customer_repository.dart';
import '../../features/payments/data/payment_repository.dart';
import '../../features/purchases/data/purchase_repository.dart';
import '../../features/sales/data/sale_repository.dart';
import '../../features/supplier_payments/data/supplier_payment_repository.dart';
import '../../features/suppliers/data/supplier_repository.dart';
import '../../features/units/data/unit_repository.dart';

class SyncService {
  SyncService({
    required this.customers,
    required this.suppliers,
    required this.units,
    required this.sales,
    required this.payments,
    required this.purchases,
    required this.supplierPayments,
  });

  final CustomerRepository customers;
  final SupplierRepository suppliers;
  final UnitRepository units;
  final SaleRepository sales;
  final PaymentRepository payments;
  final PurchaseRepository purchases;
  final SupplierPaymentRepository supplierPayments;

  Future<void> syncAll() async {
    await Future.wait([
      customers.syncNow(),
      suppliers.syncNow(),
      units.syncNow(),
      sales.syncNow(),
      payments.syncNow(),
      purchases.syncNow(),
      supplierPayments.syncNow(),
    ]);
  }

  Future<void> pullAll() async {
    await Future.wait([
      customers.pullRemoteNow(),
      suppliers.pullRemoteNow(),
      units.pullRemoteNow(),
      sales.pullRemoteNow(),
      payments.pullRemoteNow(),
      purchases.pullRemoteNow(),
      supplierPayments.pullRemoteNow(),
    ]);
  }

  Future<void> pushAll() async {
    await Future.wait([
      customers.pushLocalNow(),
      suppliers.pushLocalNow(),
      units.pushLocalNow(),
      sales.pushLocalNow(),
      payments.pushLocalNow(),
      purchases.pushLocalNow(),
      supplierPayments.pushLocalNow(),
    ]);
  }
}
