import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'data/customer_repository.dart';
import 'data/product_repository.dart';
import 'ui/app_shell.dart';
import 'ui/auth_screen.dart';

const _databaseUrl =
    'https://realt-time-database-default-rtdb.asia-southeast1.firebasedatabase.app/';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const InvestSystemApp());
}

class InvestSystemApp extends StatelessWidget {
  const InvestSystemApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF2A3A6A),
        secondary: Color(0xFFB86B4B),
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFF7F4EF),
      textTheme: GoogleFonts.spaceGroteskTextTheme(),
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'Invest System',
      theme: theme,
      home: const AppRoot(),
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  late final CustomerRepository _customerRepository;
  late final ProductRepository _productRepository;
  Future<void>? _initFuture;

  @override
  void initState() {
    super.initState();
    final database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: _databaseUrl,
    );
    _customerRepository = CustomerRepository(database: database);
    _productRepository = ProductRepository(database: database);
  }

  Future<void> _initAll() async {
    await _customerRepository.init();
    await _productRepository.init();
  }

  @override
  void dispose() {
    _customerRepository.dispose();
    _productRepository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          return const AuthScreen();
        }

        _initFuture ??= _initAll();
        return FutureBuilder<void>(
          future: _initFuture,
          builder: (context, initSnapshot) {
            if (initSnapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (initSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Text('Init error: ${initSnapshot.error}'),
                ),
              );
            }

            return AppShell(
              customerRepository: _customerRepository,
              productRepository: _productRepository,
            );
          },
        );
      },
    );
  }
}
