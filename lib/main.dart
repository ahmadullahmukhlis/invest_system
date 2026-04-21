import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/widgets/app_shell.dart';
import 'core/widgets/firebase_setup_screen.dart';
import 'core/data/sync_providers.dart';
import 'core/data/sync_service.dart';
import 'data/permissions.dart';
import 'data/user_repository.dart';
import 'data/user_profile.dart';
import 'data/user_providers.dart';
import 'firebase_options.dart';
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
  final initResult = await _initFirebase();
  if (!initResult.ok) {
    runApp(
      InvestSystemApp(home: FirebaseSetupScreen(message: initResult.message)),
    );
    return;
  }
  runApp(const AppBootstrap());
}

class _FirebaseInitResult {
  const _FirebaseInitResult({required this.ok, this.message});

  final bool ok;
  final String? message;
}

Future<_FirebaseInitResult> _initFirebase() async {
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
      return const _FirebaseInitResult(ok: true);
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        await Firebase.initializeApp();
        return const _FirebaseInitResult(ok: true);
      case TargetPlatform.macOS:
        await Firebase.initializeApp(options: DefaultFirebaseOptions.macos);
        return const _FirebaseInitResult(ok: true);
      case TargetPlatform.windows:
        await Firebase.initializeApp(options: DefaultFirebaseOptions.windows);
        return const _FirebaseInitResult(ok: true);
      case TargetPlatform.linux:
        return const _FirebaseInitResult(
          ok: false,
          message:
              'Firebase is not supported on Linux. Run on Windows or macOS, or '
              'remove Firebase usage for Linux builds.',
        );
      case TargetPlatform.fuchsia:
        return const _FirebaseInitResult(
          ok: false,
          message: 'Firebase is not supported on Fuchsia.',
        );
    }
  } catch (error) {
    return _FirebaseInitResult(
      ok: false,
      message:
          'Firebase initialization failed: $error\n\n'
          'Ensure FlutterFire is configured for this desktop platform.',
    );
  }
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key, this.useLocalDesktopMode = false});

  final bool useLocalDesktopMode;

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
  String? _initializedUid;

  Future<_BootstrapDependencies> _initAll() async {
    final userRepository = UserRepository(
      cloudEnabled: !widget.useLocalDesktopMode,
      localProfile: _buildLocalDesktopProfile(),
    );
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

  UserProfile? _buildLocalDesktopProfile() {
    if (!widget.useLocalDesktopMode) return null;
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return null;

    final email = (authUser.email ?? '').trim();
    final role = email.toLowerCase() == UserRepository.superAdminEmail
        ? 'super_admin'
        : 'viewer';
    final displayName = (authUser.displayName ?? '').trim();
    return UserProfile(
      uid: authUser.uid,
      name: displayName.isNotEmpty
          ? displayName
          : (email.isNotEmpty ? email : 'Desktop User'),
      email: email.isNotEmpty ? email : 'desktop@local',
      role: role,
      permissions: defaultPermissionsForRole(role),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      isActive: true,
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
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingApp();
        }

        final user = snapshot.data;
        if (user == null) {
          if (_initializedUid != null) {
            _initializedUid = null;
            _initFuture = null;
            unawaited(_disposeAll());
          }
          return InvestSystemApp(
            home: AuthScreen(
              syncProfileToDatabase: !widget.useLocalDesktopMode,
            ),
          );
        }

        if (_initializedUid != user.uid) {
          _initializedUid = user.uid;
          _initFuture = _reinitialize();
        }

        _initFuture ??= _initAll();
        return _buildInitializedApp(_initFuture!);
      },
    );
  }

  Future<_BootstrapDependencies> _reinitialize() async {
    await _disposeAll();
    final dependencies = await _initAll();
    _activeDependencies = dependencies;
    return dependencies;
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
              body: Center(
                child: Text('Init error: ${initSnapshot.error}'),
              ),
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
            unitRepositoryProvider.overrideWithValue(dependencies.unitRepository),
            saleRepositoryProvider.overrideWithValue(dependencies.saleRepository),
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
          child: const InvestSystemApp(home: AppShell()),
        );
      },
    );
  }

  Widget _buildLoadingApp() {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
