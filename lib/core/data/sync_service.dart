import '../../features/customers/data/customer_repository.dart';
import '../../features/payments/data/payment_repository.dart';
import '../../features/purchases/data/purchase_repository.dart';
import '../../features/sales/data/sale_repository.dart';
import '../../features/supplier_payments/data/supplier_payment_repository.dart';
import '../../features/suppliers/data/supplier_repository.dart';
import '../../features/units/data/unit_repository.dart';
import '../../data/user_repository.dart';

class SyncService {
  SyncService({
    required this.userRepository,
    required this.customers,
    required this.suppliers,
    required this.units,
    required this.sales,
    required this.payments,
    required this.purchases,
    required this.supplierPayments,
  });

  final UserRepository userRepository;
  final CustomerRepository customers;
  final SupplierRepository suppliers;
  final UnitRepository units;
  final SaleRepository sales;
  final PaymentRepository payments;
  final PurchaseRepository purchases;
  final SupplierPaymentRepository supplierPayments;

  bool get _canSyncSharedData =>
      userRepository.currentRole == 'admin' ||
      userRepository.currentRole == 'super_admin';

  Future<void> syncAll() async {
    await Future.wait(_ownerScopedSyncTasks(sync: true));
  }

  Future<void> pullAll() async {
    await Future.wait(_ownerScopedSyncTasks(pull: true));
  }

  Future<void> pushAll() async {
    await Future.wait(_ownerScopedSyncTasks(push: true));
  }

  List<Future<void>> _ownerScopedSyncTasks({
    bool sync = false,
    bool pull = false,
    bool push = false,
  }) {
    Future<void> run(
      Future<void> Function() syncFn,
      Future<void> Function() pullFn,
      Future<void> Function() pushFn,
    ) {
      if (pull) return pullFn();
      if (push) return pushFn();
      return syncFn();
    }

    final tasks = <Future<void>>[
      run(customers.syncNow, customers.pullRemoteNow, customers.pushLocalNow),
      run(suppliers.syncNow, suppliers.pullRemoteNow, suppliers.pushLocalNow),
      run(sales.syncNow, sales.pullRemoteNow, sales.pushLocalNow),
      run(payments.syncNow, payments.pullRemoteNow, payments.pushLocalNow),
      run(purchases.syncNow, purchases.pullRemoteNow, purchases.pushLocalNow),
      run(
        supplierPayments.syncNow,
        supplierPayments.pullRemoteNow,
        supplierPayments.pushLocalNow,
      ),
    ];

    if (_canSyncSharedData) {
      tasks.add(run(units.syncNow, units.pullRemoteNow, units.pushLocalNow));
    }

    return tasks;
  }
}
