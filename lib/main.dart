import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/widgets/app_shell.dart';
import 'core/data/sync_providers.dart';
import 'core/data/sync_service.dart';
import 'data/user_repository.dart';
import 'data/user_providers.dart';
import 'features/customers/data/customer_providers.dart';
import 'features/customers/data/customer_repository.dart';
import 'features/payments/data/payment_providers.dart';
import 'features/payments/data/payment_repository.dart';
import 'features/purchases/data/purchase_providers.dart';
import 'features/purchases/data/purchase_repository.dart';
import 'features/sales/data/sale_providers.dart';
import 'features/sales/data/sale_repository.dart';
import 'features/supplier_payments/data/supplier_payment_providers.dart';
import 'features/supplier_payments/data/supplier_payment_repository.dart';
import 'features/suppliers/data/supplier_providers.dart';
import 'features/suppliers/data/supplier_repository.dart';
import 'features/units/data/unit_providers.dart';
import 'features/units/data/unit_repository.dart';
import 'ui/auth_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const AppBootstrap());
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _BootstrapDependencies {
  const _BootstrapDependencies({
    required this.userRepository,
    required this.customerRepository,
    required this.supplierRepository,
    required this.unitRepository,
    required this.saleRepository,
    required this.paymentRepository,
    required this.purchaseRepository,
    required this.supplierPaymentRepository,
  });

  final UserRepository userRepository;
  final CustomerRepository customerRepository;
  final SupplierRepository supplierRepository;
  final UnitRepository unitRepository;
  final SaleRepository saleRepository;
  final PaymentRepository paymentRepository;
  final PurchaseRepository purchaseRepository;
  final SupplierPaymentRepository supplierPaymentRepository;

  Future<void> dispose() async {
    await customerRepository.dispose();
    await supplierRepository.dispose();
    await unitRepository.dispose();
    await saleRepository.dispose();
    await paymentRepository.dispose();
    await purchaseRepository.dispose();
    await supplierPaymentRepository.dispose();
    await userRepository.dispose();
  }
}

class _AppBootstrapState extends State<AppBootstrap> {
  Future<_BootstrapDependencies>? _initFuture;
  _BootstrapDependencies? _activeDependencies;

  Future<_BootstrapDependencies> _initAll() async {
    final userRepository = UserRepository(cloudEnabled: false);
    final customerRepository = CustomerRepository(
      userRepository: userRepository,
    );
    final supplierRepository = SupplierRepository(
      userRepository: userRepository,
    );
    final unitRepository = UnitRepository(userRepository: userRepository);
    final saleRepository = SaleRepository(userRepository: userRepository);
    final paymentRepository = PaymentRepository(userRepository: userRepository);
    final purchaseRepository = PurchaseRepository(
      userRepository: userRepository,
    );
    final supplierPaymentRepository = SupplierPaymentRepository(
      userRepository: userRepository,
    );

    await userRepository.init();
    await customerRepository.init();
    await supplierRepository.init();
    await unitRepository.init();
    await saleRepository.init();
    await paymentRepository.init();
    await purchaseRepository.init();
    await supplierPaymentRepository.init();

    return _BootstrapDependencies(
      userRepository: userRepository,
      customerRepository: customerRepository,
      supplierRepository: supplierRepository,
      unitRepository: unitRepository,
      saleRepository: saleRepository,
      paymentRepository: paymentRepository,
      purchaseRepository: purchaseRepository,
      supplierPaymentRepository: supplierPaymentRepository,
    );
  }

  Future<void> _disposeAll() async {
    final dependencies = _activeDependencies;
    _activeDependencies = null;
    if (dependencies != null) {
      await dependencies.dispose();
    }
  }

  @override
  void dispose() {
    unawaited(_disposeAll());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _initFuture ??= _initAll();
    return _buildInitializedApp(_initFuture!);
  }

  Widget _buildInitializedApp(Future<_BootstrapDependencies> future) {
    return FutureBuilder<_BootstrapDependencies>(
      future: future,
      builder: (context, initSnapshot) {
        if (initSnapshot.connectionState != ConnectionState.done) {
          return _buildLoadingApp();
        }
        if (initSnapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(child: Text('Init error: ${initSnapshot.error}')),
            ),
          );
        }
        final dependencies = initSnapshot.data;
        if (dependencies == null) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Text('Init error: Missing application dependencies.'),
              ),
            ),
          );
        }
        _activeDependencies = dependencies;

        return StreamBuilder(
          stream: dependencies.userRepository.currentUserStream,
          initialData: dependencies.userRepository.current,
          builder: (context, userSnapshot) {
            final currentUser = userSnapshot.data;
            return ProviderScope(
              overrides: [
                userRepositoryProvider.overrideWithValue(
                  dependencies.userRepository,
                ),
                customerRepositoryProvider.overrideWithValue(
                  dependencies.customerRepository,
                ),
                supplierRepositoryProvider.overrideWithValue(
                  dependencies.supplierRepository,
                ),
                unitRepositoryProvider.overrideWithValue(
                  dependencies.unitRepository,
                ),
                saleRepositoryProvider.overrideWithValue(
                  dependencies.saleRepository,
                ),
                paymentRepositoryProvider.overrideWithValue(
                  dependencies.paymentRepository,
                ),
                purchaseRepositoryProvider.overrideWithValue(
                  dependencies.purchaseRepository,
                ),
                supplierPaymentRepositoryProvider.overrideWithValue(
                  dependencies.supplierPaymentRepository,
                ),
                syncServiceProvider.overrideWithValue(
                  SyncService(
                    userRepository: dependencies.userRepository,
                    customers: dependencies.customerRepository,
                    suppliers: dependencies.supplierRepository,
                    units: dependencies.unitRepository,
                    sales: dependencies.saleRepository,
                    payments: dependencies.paymentRepository,
                    purchases: dependencies.purchaseRepository,
                    supplierPayments: dependencies.supplierPaymentRepository,
                  ),
                ),
              ],
              child: InvestSystemApp(
                home: currentUser == null
                    ? AuthScreen(userRepository: dependencies.userRepository)
                    : const AppShell(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingApp() {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}
