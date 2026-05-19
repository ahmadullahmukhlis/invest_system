import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/data/local_db.dart';
import 'core/widgets/app_shell.dart';
import 'core/data/sync_providers.dart';
import 'core/data/sync_service.dart';
import 'data/user_profile.dart';
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
  _configureGlobalErrorHandling();
  _configureSqliteFactory();

  final dbInitResult = await _initLocalDatabase();
  if (!dbInitResult.ok) {
    runApp(
      _StartupErrorApp(
        title: 'Database initialization failed',
        message: dbInitResult.message!,
      ),
    );
    return;
  }
  runApp(const AppBootstrap());
}

class _StartupInitResult {
  const _StartupInitResult({required this.ok, this.message});

  final bool ok;
  final String? message;
}

void _configureGlobalErrorHandling() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    developer.log(
      details.exceptionAsString(),
      name: 'FlutterError',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    developer.log(
      'Uncaught platform error: $error',
      name: 'PlatformDispatcher',
      error: error,
      stackTrace: stackTrace,
    );
    return true;
  };
}

void _configureSqliteFactory() {
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
    return;
  }

  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}

Future<_StartupInitResult> _initLocalDatabase() async {
  try {
    await LocalDb.instance.init();
    return const _StartupInitResult(ok: true);
  } catch (error, stackTrace) {
    developer.log(
      'Local database initialization failed: $error',
      name: 'Startup',
      error: error,
      stackTrace: stackTrace,
    );
    return _StartupInitResult(
      ok: false,
      message:
          'The application could not open its local SQLite database.\n\n'
          'Path: ${LocalDb.instance.databasePath ?? 'unresolved'}\n\n'
          'Error: $error\n\n'
          'The app stores its database in your writable Documents folder so it '
          'works in release builds, installed builds, and Program Files '
          'installs.',
    );
  }
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SelectableText(message),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
    await userRepository.init();
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

    _userRepository = userRepository;
    _customerRepository = customerRepository;
    _supplierRepository = supplierRepository;
    _unitRepository = unitRepository;
    _saleRepository = saleRepository;
    _paymentRepository = paymentRepository;
    _purchaseRepository = purchaseRepository;
    _supplierPaymentRepository = supplierPaymentRepository;

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
    final initFuture = _initFuture ??= _initAll();
    return FutureBuilder<void>(
      future: initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Text('Init error: ${snapshot.error}'),
              ),
            ),
          );
        }

        return ProviderScope(
          overrides: [
            userRepositoryProvider.overrideWithValue(_userRepository!),
            customerRepositoryProvider.overrideWithValue(
              _customerRepository!,
            ),
            supplierRepositoryProvider.overrideWithValue(
              _supplierRepository!,
            ),
            unitRepositoryProvider.overrideWithValue(_unitRepository!),
            saleRepositoryProvider.overrideWithValue(_saleRepository!),
            paymentRepositoryProvider.overrideWithValue(
              _paymentRepository!,
            ),
            purchaseRepositoryProvider.overrideWithValue(
              _purchaseRepository!,
            ),
            supplierPaymentRepositoryProvider.overrideWithValue(
              _supplierPaymentRepository!,
            ),
            syncServiceProvider.overrideWithValue(
              SyncService(
                userRepository: _userRepository!,
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
          child: StreamBuilder<UserProfile?>(
            stream: _userRepository!.currentUserStream,
            initialData: _userRepository!.current,
            builder: (context, userSnapshot) {
              final user = userSnapshot.data;
              return InvestSystemApp(
                home: user == null ? const AuthScreen() : const AppShell(),
              );
            },
          ),
        );
      },
    );
  }
}
