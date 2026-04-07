import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/widgets/app_shell.dart';
import 'core/data/sync_providers.dart';
import 'core/data/sync_service.dart';
import 'data/user_repository.dart';
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
  await Firebase.initializeApp();
  runApp(const AppBootstrap());
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  UserRepository? _userRepository;
  CustomerRepository? _customerRepository;
  SupplierRepository? _supplierRepository;
  UnitRepository? _unitRepository;
  SaleRepository? _saleRepository;
  PaymentRepository? _paymentRepository;
  PurchaseRepository? _purchaseRepository;
  SupplierPaymentRepository? _supplierPaymentRepository;
  Future<void>? _initFuture;

  Future<void> _initAll() async {
    final userRepository = UserRepository();
    final customerRepository =
        CustomerRepository(userRepository: userRepository);
    final supplierRepository =
        SupplierRepository(userRepository: userRepository);
    final unitRepository = UnitRepository(userRepository: userRepository);
    final saleRepository = SaleRepository(userRepository: userRepository);
    final paymentRepository = PaymentRepository(userRepository: userRepository);
    final purchaseRepository = PurchaseRepository(userRepository: userRepository);
    final supplierPaymentRepository =
        SupplierPaymentRepository(userRepository: userRepository);

    _userRepository = userRepository;
    _customerRepository = customerRepository;
    _supplierRepository = supplierRepository;
    _unitRepository = unitRepository;
    _saleRepository = saleRepository;
    _paymentRepository = paymentRepository;
    _purchaseRepository = purchaseRepository;
    _supplierPaymentRepository = supplierPaymentRepository;

    await _userRepository!.init();
    await _customerRepository!.init();
    await _supplierRepository!.init();
    await _unitRepository!.init();
    await _saleRepository!.init();
    await _paymentRepository!.init();
    await _purchaseRepository!.init();
    await _supplierPaymentRepository!.init();
  }

  Future<void> _disposeAll() async {
    await _customerRepository?.dispose();
    await _supplierRepository?.dispose();
    await _unitRepository?.dispose();
    await _saleRepository?.dispose();
    await _paymentRepository?.dispose();
    await _purchaseRepository?.dispose();
    await _supplierPaymentRepository?.dispose();
    await _userRepository?.dispose();
    _customerRepository = null;
    _supplierRepository = null;
    _unitRepository = null;
    _saleRepository = null;
    _paymentRepository = null;
    _purchaseRepository = null;
    _supplierPaymentRepository = null;
    _userRepository = null;
  }

  @override
  void dispose() {
    unawaited(_disposeAll());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          _initFuture = null;
          unawaited(_disposeAll());
          return const InvestSystemApp(home: AuthScreen());
        }

        _initFuture ??= _initAll();
        return FutureBuilder<void>(
          future: _initFuture,
          builder: (context, initSnapshot) {
            if (initSnapshot.connectionState != ConnectionState.done) {
              return const MaterialApp(
                debugShowCheckedModeBanner: false,
                home: Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            if (initSnapshot.hasError) {
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                home: Scaffold(
                  body: Center(
                    child: Text('Init error: ${initSnapshot.error}'),
                  ),
                ),
              );
            }

            return ProviderScope(
              overrides: [
                customerRepositoryProvider
                    .overrideWithValue(_customerRepository!),
                supplierRepositoryProvider
                    .overrideWithValue(_supplierRepository!),
                unitRepositoryProvider.overrideWithValue(_unitRepository!),
                saleRepositoryProvider.overrideWithValue(_saleRepository!),
                paymentRepositoryProvider
                    .overrideWithValue(_paymentRepository!),
                purchaseRepositoryProvider
                    .overrideWithValue(_purchaseRepository!),
                supplierPaymentRepositoryProvider
                    .overrideWithValue(_supplierPaymentRepository!),
                syncServiceProvider.overrideWithValue(
                  SyncService(
                    customers: _customerRepository!,
                    suppliers: _supplierRepository!,
                    units: _unitRepository!,
                    sales: _saleRepository!,
                    payments: _paymentRepository!,
                    purchases: _purchaseRepository!,
                    supplierPayments: _supplierPaymentRepository!,
                  ),
                ),
              ],
              child: const InvestSystemApp(home: AppShell()),
            );
          },
        );
      },
    );
  }
}
